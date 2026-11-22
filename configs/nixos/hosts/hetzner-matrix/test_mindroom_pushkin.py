# -*- coding: utf-8 -*-
# Copyright 2026 MindRoom contributors
#
# SPDX-License-Identifier: AGPL-3.0-only
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
"""Table-driven unit tests for MindroomApnsPushkin inside Sygnal v0.17.0."""

import asyncio
import copy
import unittest
from typing import Any, Callable, Dict, List, Optional, Tuple
from unittest.mock import MagicMock, patch

from aioapns import NotificationRequest
from aioapns.common import NotificationResult
from aioapns.connection import APNsBaseConnectionPool, APNsProductionClientProtocol
from twisted.internet.defer import ensureDeferred
from twisted.internet.testing import MemoryReactorClock

import mindroom_pushkin
from mindroom_pushkin import (
    ENCRYPTED_EVENT_TYPE,
    MAX_CLOCK_SKEW_MS,
    MAX_RING_LIFETIME_MS,
    RING_HINT_KEY,
    RING_PAYLOAD_KEY,
    RING_SOUND,
    RTC_NOTIFICATION_TYPE,
    MindroomApnsPushkin,
)
from sygnal.apnspushkin import ApnsPushkin
from sygnal.notifications import Notification, NotificationContext
from sygnal.sygnal import CONFIG_DEFAULTS, Sygnal, merge_left_with_defaults

APP_ID = "chat.mindroom.app"
STOCK_APP_ID = "chat.mindroom.app.stock"
FAKE_KEYFILE = "/sygnal/test-apns-key.p8"
BASE_NOW_MS = 1_795_300_000_000


def _dev(
    app_id: str = APP_ID,
    tweaks: Optional[Dict[str, Any]] = None,
    default_payload: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    d: Dict[str, Any] = {"app_id": app_id, "pushkey": "deadbeef0123", "pushkey_ts": 42}
    if tweaks is not None:
        d["tweaks"] = tweaks
    if default_payload is not None:
        d["data"] = {"default_payload": default_payload}
    return d


def _raw(
    *,
    event_type: Optional[str] = RTC_NOTIFICATION_TYPE,
    content: Optional[Dict[str, Any]] = None,
    sender: Optional[str] = "@alice:example.com",
    sender_display_name: Optional[str] = "Alice",
    room_name: Optional[str] = None,
    prio: str = "high",
    tweaks: Optional[Dict[str, Any]] = None,
    default_payload: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    raw: Dict[str, Any] = {
        "room_id": "!room:example.com",
        "event_id": "$event1",
        "prio": prio,
        "counts": {"unread": 1},
        "devices": [_dev(tweaks=tweaks, default_payload=default_payload)],
    }
    if event_type is not None:
        raw["type"] = event_type
    if content is not None:
        raw["content"] = content
    if sender is not None:
        raw["sender"] = sender
    if sender_display_name is not None:
        raw["sender_display_name"] = sender_display_name
    if room_name is not None:
        raw["room_name"] = room_name
    return raw


def _ring(sender_ts: int, lifetime: int = 30_000, intent: Optional[str] = "audio") -> Dict[str, Any]:
    fields: Dict[str, Any] = {
        "notification_type": "ring",
        "sender_ts": sender_ts,
        "lifetime": lifetime,
    }
    if intent is not None:
        fields["m.call.intent"] = intent
    return fields


def _enc(hint: Any) -> Dict[str, Any]:
    return {"algorithm": "m.megolm.v1.aes-sha2", "ciphertext": "opaque", RING_HINT_KEY: hint}


class _FakeH2Conn:
    def __init__(self, headers_log: List[List[Tuple[str, str]]]) -> None:
        self.headers_log = headers_log
        self.data_log: List[bytes] = []

    def send_headers(self, *, stream_id: int, headers: List[Tuple[str, str]]) -> None:
        self.headers_log.append(list(headers))

    def send_data(self, *, stream_id: int, data: bytes, end_stream: bool) -> None:
        self.data_log.append(data)

    def data_to_send(self) -> bytes:
        return b""


class _DelayedFakePool(APNsBaseConnectionPool):
    def __init__(
        self,
        *,
        on_connect: Callable[[], None],
        headers_log: List[List[Tuple[str, str]]],
        channel_wait: Optional[Callable[[], None]] = None,
    ) -> None:
        super().__init__(topic=APP_ID, max_connections=1, max_connection_attempts=1)
        self.protocol_class = APNsProductionClientProtocol
        self._on_connect = on_connect
        self._headers_log = headers_log
        self._channel_wait = channel_wait
        self.last_protocol: Any = None

    async def create_connection(self) -> Any:
        await asyncio.sleep(0)
        self._on_connect()
        protocol = self.protocol_class(self.apns_topic, self.loop, self.discard_connection)
        protocol.conn = _FakeH2Conn(self._headers_log)
        protocol.transport = MagicMock()
        orig_flush = protocol.flush

        def _flush_then_ok() -> None:
            orig_flush()

            def _complete() -> None:
                for nid, fut in list(protocol.requests.items()):
                    if not fut.done():
                        fut.set_result(NotificationResult(nid, "200"))

            protocol.loop.call_soon(_complete)

        protocol.flush = _flush_then_ok
        if self._channel_wait is not None:
            protocol.free_channels.bound = 1
            await protocol.free_channels.acquire()
            on_wait = self._channel_wait

            async def _release_later() -> None:
                await asyncio.sleep(0)
                on_wait()
                protocol.free_channels.release()

            asyncio.create_task(_release_later())
        self.last_protocol = protocol
        return protocol


class MindroomApnsPushkinTestCase(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.now_ms = BASE_NOW_MS
        self.reactor = MemoryReactorClock()
        self.sent: Dict[str, List[NotificationRequest]] = {APP_ID: [], STOCK_APP_ID: []}
        self.send_handler: Callable[[NotificationRequest], NotificationResult] = (
            lambda req: NotificationResult(req.notification_id, "200")
        )

        def _make_apns(*args: Any, **kwargs: Any) -> MagicMock:
            topic = kwargs.get("topic", APP_ID)
            client = MagicMock()

            async def _send(req: NotificationRequest) -> NotificationResult:
                self.sent[topic].append(copy.deepcopy(req))
                return self.send_handler(req)

            client.send_notification.side_effect = _send
            return client

        patch("sygnal.apnspushkin.APNs", side_effect=_make_apns).start()
        patch("os.path.exists", lambda p: p == FAKE_KEYFILE).start()
        patch.object(mindroom_pushkin, "now_ms", side_effect=lambda: self.now_ms).start()
        self.addCleanup(patch.stopall)

        base_app = {
            "keyfile": FAKE_KEYFILE,
            "key_id": "KEYID12345",
            "team_id": "TEAMID1234",
            "platform": "production",
            "convert_device_token_to_hex": False,
        }
        cfg = merge_left_with_defaults(
            CONFIG_DEFAULTS,
            {
                "log": {"setup": {"version": 1, "disable_existing_loggers": False}},
                "apps": {
                    APP_ID: {**base_app, "type": "mindroom_pushkin.MindroomApnsPushkin", "topic": APP_ID},
                    STOCK_APP_ID: {**base_app, "type": "apns", "topic": STOCK_APP_ID},
                },
            },
        )
        self.sygnal = Sygnal(cfg, self.reactor)  # type: ignore[arg-type]
        self.pushkin = await self._await(self.sygnal._make_pushkin(APP_ID, cfg["apps"][APP_ID]))
        self.stock = await self._await(self.sygnal._make_pushkin(STOCK_APP_ID, cfg["apps"][STOCK_APP_ID]))
        self.assertIsInstance(self.pushkin, MindroomApnsPushkin)
        self.assertIs(type(self.stock), ApnsPushkin)

    async def _await(self, coro: Any, *, advance: Optional[List[int]] = None) -> Any:
        fut = ensureDeferred(coro).asFuture(asyncio.get_running_loop())
        for secs in advance or []:
            await asyncio.sleep(0)
            await asyncio.sleep(0)
            if fut.done():
                break
            self.now_ms += secs * 1000
            self.reactor.advance(secs)
        return await fut

    async def _dispatch(
        self,
        notif: Notification,
        *,
        pushkin: Optional[ApnsPushkin] = None,
        advance: Optional[List[int]] = None,
    ) -> List[str]:
        ctx = NotificationContext(
            request_id="req-1",
            opentracing_span=self.sygnal.tracer.start_span("test"),
            start_time=0.0,
        )
        return await self._await(
            (pushkin or self.pushkin).dispatch_notification(notif, notif.devices[0], ctx),
            advance=advance,
        )

    async def test_valid_rings(self) -> None:
        t = self.now_ms
        cases = [
            ("clear_audio", _raw(content=_ring(t - 2_000), tweaks={"sound": "ring"}, default_payload={"aps": {"sound": "default", "mutable-content": 1}}), "VOICE_CALL_FROM_USER", "Alice", t + 28_000, 28),
            ("hint_audio_named_room", _raw(event_type=ENCRYPTED_EVENT_TYPE, room_name="Small Group", content=_enc(_ring(t - 1_500)), tweaks={"sound": "ring"}), "VOICE_CALL_FROM_USER", "Alice", t + 28_500, 28),
            ("clear_video", _raw(sender_display_name="Test Caller", content=_ring(t - 1_000, intent="video"), tweaks={"sound": "ring"}), "VIDEO_CALL_FROM_USER", "Test Caller", t + 29_000, 29),
            ("hint_video", _raw(event_type=ENCRYPTED_EVENT_TYPE, sender_display_name="Test Caller", content=_enc(_ring(t - 1_000, intent="video")), tweaks={"sound": "ring"}), "VIDEO_CALL_FROM_USER", "Test Caller", t + 29_000, 29),
            ("omitted_intent_sender_fallback", _raw(sender="@bob:example.com", sender_display_name="", content=_ring(t, intent=None), tweaks={"sound": "ring"}), "VOICE_CALL_FROM_USER", "@bob:example.com", t + 30_000, 30),
            ("missing_sender_fallback", _raw(sender=None, sender_display_name=None, content=_ring(t, intent=None), tweaks={"sound": "ring"}), "VOICE_CALL_FROM_USER", " ", t + 30_000, 30),
            ("long_name_truncated", _raw(sender_display_name="A" * 2000, content=_ring(t), tweaks={"sound": "ring"}), "VOICE_CALL_FROM_USER", "A" * self.pushkin.MAX_FIELD_LENGTH, t + 30_000, 30),
            ("low_prio_override_and_life_cap", _raw(prio="low", content=_ring(t, lifetime=600_000), tweaks={"sound": "ring"}), "VOICE_CALL_FROM_USER", "Alice", t + MAX_RING_LIFETIME_MS, 120),
            ("clock_skew_boundary", _raw(content=_ring(t + MAX_CLOCK_SKEW_MS), tweaks={"sound": "ring"}), "VOICE_CALL_FROM_USER", "Alice", t + MAX_CLOCK_SKEW_MS + 30_000, 50),
        ]
        for label, raw, loc_key, name, exp, ttl in cases:
            with self.subTest(case=label):
                self.sent[APP_ID].clear()
                self.assertEqual(await self._dispatch(Notification(raw)), [])
                self.assertEqual(len(self.sent[APP_ID]), 1)
                req = self.sent[APP_ID][0]
                self.assertEqual(req.priority, 10)
                self.assertEqual(req.time_to_live, ttl)
                self.assertEqual(req.message["aps"]["alert"], {"loc-key": loc_key, "loc-args": [name]})
                self.assertEqual(req.message["aps"]["sound"], RING_SOUND)
                self.assertEqual(req.message[RING_PAYLOAD_KEY], {"expires_at": exp})

    async def test_non_ring_differential_matches_stock_apns_pushkin(self) -> None:
        t = self.now_ms
        valid = _ring(t)
        rt = {"sound": "ring"}
        dp = {"aps": {"sound": "default"}}
        cases: List[Tuple[str, Dict[str, Any]]] = [
            ("msg_low_prio", _raw(event_type="m.room.message", content={"msgtype": "m.text", "body": "Hi"}, prio="low")),
            ("encrypted_no_hint", _raw(event_type=ENCRYPTED_EVENT_TYPE, content={"algorithm": "m.megolm.v1.aes-sha2"}, tweaks=rt, default_payload=dp)),
            ("group_notif_clear", _raw(content={**valid, "notification_type": "notification"}, tweaks=rt, default_payload=dp)),
            ("group_notif_hint", _raw(event_type=ENCRYPTED_EVENT_TYPE, content=_enc({**valid, "notification_type": "notification"}), tweaks=rt, default_payload=dp)),
            ("legacy_invite_audio", _raw(event_type="m.call.invite", content={**valid, "offer": {"sdp": "v=0\r\nm=audio 9\r\n"}}, tweaks=rt, default_payload=dp)),
            ("legacy_invite_video", _raw(event_type="m.call.invite", content={**valid, "offer": {"sdp": "v=0\r\nm=video 9\r\n"}}, tweaks=rt, default_payload=dp)),
            ("wrong_wire_msg_top", _raw(event_type="m.room.message", content={**valid, "msgtype": "m.text", "body": "hi"}, tweaks=rt, default_payload=dp)),
            ("wrong_wire_msg_hint", _raw(event_type="m.room.message", content={"msgtype": "m.text", "body": "hi", RING_HINT_KEY: valid}, tweaks=rt, default_payload=dp)),
            ("wrong_wire_rtc_nested", _raw(content={RING_HINT_KEY: valid}, tweaks=rt, default_payload=dp)),
            ("wrong_wire_enc_top", _raw(event_type=ENCRYPTED_EVENT_TYPE, content={**valid, "algorithm": "m.megolm.v1.aes-sha2"}, tweaks=rt, default_payload=dp)),
            ("wrong_wire_unknown", _raw(event_type="com.example.custom", content=valid, tweaks=rt, default_payload=dp)),
            ("no_tweak", _raw(content=valid, tweaks=None, default_payload=dp)),
            ("other_tweak", _raw(content=valid, tweaks={"sound": "default"}, default_payload=dp)),
            ("malformed_hint", _raw(event_type=ENCRYPTED_EVENT_TYPE, content=_enc("not-a-dict"), tweaks=rt)),
            ("missing_content", _raw(content=None, tweaks=rt)),
            ("badge_only", {"type": None, "sender": "", "counts": {"unread": 2}, "devices": [_dev(tweaks=rt)]}),
            ("caller_ring_field_full", _raw(event_type="m.room.message", content={"msgtype": "m.text", "body": "Hi"}, prio="low", default_payload={**dp, RING_PAYLOAD_KEY: {"expires_at": 1}})),
            ("caller_ring_field_event_id_only", {"room_id": "!room:example.com", "event_id": "$e2", "prio": "low", "counts": {"unread": 3}, "devices": [_dev(tweaks=rt, default_payload={"aps": {"mutable-content": 1}, RING_PAYLOAD_KEY: {"expires_at": 1}})]}),
        ]
        bad_ts = [
            ("missing_ts", {"notification_type": "ring", "lifetime": 30_000}),
            ("missing_life", {"notification_type": "ring", "sender_ts": t}),
            ("none_ts", {"notification_type": "ring", "sender_ts": None, "lifetime": 30_000}),
            ("str_ts", {"notification_type": "ring", "sender_ts": str(t), "lifetime": 30_000}),
            ("float_ts", {"notification_type": "ring", "sender_ts": float(t), "lifetime": 30_000}),
            ("bool_ts", {"notification_type": "ring", "sender_ts": True, "lifetime": 30_000}),
            ("bool_life", {"notification_type": "ring", "sender_ts": t, "lifetime": True}),
            ("zero_ts", {"notification_type": "ring", "sender_ts": 0, "lifetime": 30_000}),
            ("neg_ts", {"notification_type": "ring", "sender_ts": -1_000, "lifetime": 30_000}),
            ("zero_life", {"notification_type": "ring", "sender_ts": t, "lifetime": 0}),
            ("neg_life", {"notification_type": "ring", "sender_ts": t, "lifetime": -5_000}),
            ("far_future", {"notification_type": "ring", "sender_ts": t + MAX_CLOCK_SKEW_MS + 1, "lifetime": 30_000}),
        ]
        cases.extend((f"bad_ts_{k}", _raw(content=c, tweaks=rt, default_payload=dp)) for k, c in bad_ts)

        for label, raw in cases:
            with self.subTest(case=label):
                self.sent[APP_ID].clear()
                self.sent[STOCK_APP_ID].clear()
                raw_stock = copy.deepcopy(raw)
                raw_stock["devices"][0]["app_id"] = STOCK_APP_ID

                rej_m = await self._dispatch(Notification(copy.deepcopy(raw)))
                rej_s = await self._dispatch(Notification(raw_stock), pushkin=self.stock)
                self.assertEqual(rej_m, rej_s)
                self.assertEqual(len(self.sent[APP_ID]), 1)
                self.assertEqual(len(self.sent[STOCK_APP_ID]), 1)
                got, want = self.sent[APP_ID][0], self.sent[STOCK_APP_ID][0]
                self.assertEqual((got.message, got.priority, got.time_to_live), (want.message, want.priority, want.time_to_live))

    async def test_expiry_and_retries(self) -> None:
        # 1. Expired before first attempt (boundary and past)
        for age in (30_000, 60_000):
            with self.subTest(expired_age=age):
                self.sent[APP_ID].clear()
                notif = Notification(_raw(content=_ring(self.now_ms - age), tweaks={"sound": "ring"}))
                self.assertEqual(await self._dispatch(notif), [])
                self.assertEqual(self.sent[APP_ID], [])

        # 2. Retry scenarios: (label, age_ms, succeed_on_attempt, advance_secs, expected_ttls)
        retry_cases = [
            ("expired_before_retry1", 25_000, None, [10], [5]),
            ("expired_before_retry2", 5_000, None, [10, 20], [25, 15]),
            ("live_retry_recomputes_ttl", 5_000, 2, [10], [25, 15]),
        ]
        for label, age, succeed_on, adv, expected_ttls in retry_cases:
            with self.subTest(case=label):
                self.sent[APP_ID].clear()
                attempts = 0

                def _handler(req: NotificationRequest, ok_at: Optional[int] = succeed_on) -> NotificationResult:
                    nonlocal attempts
                    attempts += 1
                    if ok_at is not None and attempts >= ok_at:
                        return NotificationResult(req.notification_id, "200")
                    return NotificationResult(req.notification_id, "503", description="Busy")

                self.send_handler = _handler
                notif = Notification(_raw(content=_ring(self.now_ms - age), tweaks={"sound": "ring"}))
                self.assertEqual(await self._dispatch(notif, advance=adv), [])
                self.assertEqual([r.time_to_live for r in self.sent[APP_ID]], expected_ttls)

    async def test_delayed_connection_enforces_absolute_deadline_on_wire(self) -> None:
        async def _send_with_pool(
            raw: Dict[str, Any],
            *,
            connect_delay_ms: int,
            channel_wait_ms: int = 0,
        ) -> Tuple[List[str], List[List[Tuple[str, str]]], _DelayedFakePool]:
            headers_log: List[List[Tuple[str, str]]] = []
            pool = _DelayedFakePool(
                on_connect=lambda: setattr(self, "now_ms", self.now_ms + connect_delay_ms),
                headers_log=headers_log,
                channel_wait=(
                    (lambda: setattr(self, "now_ms", self.now_ms + channel_wait_ms))
                    if channel_wait_ms > 0
                    else None
                ),
            )
            fake_apns = MagicMock(pool=pool)
            fake_apns.send_notification.side_effect = pool.send_notification
            with patch("sygnal.apnspushkin.APNs", return_value=fake_apns):
                pushkin = MindroomApnsPushkin(
                    APP_ID,
                    self.sygnal,
                    {
                        "type": "mindroom_pushkin.MindroomApnsPushkin",
                        "keyfile": FAKE_KEYFILE,
                        "key_id": "KEYID12345",
                        "team_id": "TEAMID1234",
                        "topic": APP_ID,
                        "platform": "production",
                        "convert_device_token_to_hex": False,
                    },
                )
            rejected = await self._dispatch(Notification(raw), pushkin=pushkin)
            return rejected, headers_log, pool

        # A. Connection wait crosses deadline -> nothing written on the wire
        rej, hdrs, _ = await _send_with_pool(
            _raw(content=_ring(self.now_ms, lifetime=5_000), tweaks={"sound": "ring"}),
            connect_delay_ms=6_000,
        )
        self.assertEqual((rej, hdrs), ([], []))

        # B. Connection waits 5 s (still before deadline) -> apns-expiration never exceeds deadline
        self.now_ms = BASE_NOW_MS + 400
        deadline_ms = self.now_ms + 25_000
        rej, hdrs, _ = await _send_with_pool(
            _raw(content=_ring(self.now_ms, lifetime=25_000), tweaks={"sound": "ring"}),
            connect_delay_ms=5_000,
        )
        self.assertEqual(rej, [])
        self.assertEqual(len(hdrs), 1)
        exp_hdr = int(dict(hdrs[0])["apns-expiration"])
        self.assertEqual(exp_hdr, deadline_ms // 1000)
        self.assertLessEqual(exp_hdr * 1000, deadline_ms)

        # C. Stream channel wait crosses deadline -> channel released, nothing sent
        self.now_ms = BASE_NOW_MS
        rej, hdrs, pool = await _send_with_pool(
            _raw(content=_ring(self.now_ms, lifetime=5_000), tweaks={"sound": "ring"}),
            connect_delay_ms=1_000,
            channel_wait_ms=5_000,
        )
        self.assertEqual((rej, hdrs), ([], []))
        self.assertFalse(pool.last_protocol.free_channels.is_busy)

        # D. Non-ring through _MindroomDeadlineProtocol delegates to stock behavior (no apns-expiration)
        self.now_ms = BASE_NOW_MS
        rej, hdrs, _ = await _send_with_pool(
            _raw(event_type="m.room.message", content={"msgtype": "m.text", "body": "Hi"}),
            connect_delay_ms=2_000,
        )
        self.assertEqual(rej, [])
        self.assertEqual(len(hdrs), 1)
        self.assertNotIn("apns-expiration", dict(hdrs[0]))


if __name__ == "__main__":
    unittest.main()
