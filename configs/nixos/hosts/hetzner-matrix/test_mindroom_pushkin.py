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
"""Unit tests for MindroomApnsPushkin inside Sygnal v0.17.0."""

import asyncio
import copy
import unittest
from typing import Any, Callable, Dict, List, Optional
from unittest.mock import MagicMock, patch

from aioapns import NotificationRequest
from aioapns.common import NotificationResult
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
from sygnal.notifications import Notification, NotificationContext
from sygnal.sygnal import CONFIG_DEFAULTS, Sygnal, merge_left_with_defaults

APP_ID = "chat.mindroom.app"
FAKE_KEYFILE = "/sygnal/test-apns-key.p8"
BASE_NOW_MS = 1_795_300_000_000


def _make_device(
    tweaks: Optional[Dict[str, Any]] = None,
    default_payload: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    device: Dict[str, Any] = {
        "app_id": APP_ID,
        "pushkey": "deadbeef0123456789abcdef",
        "pushkey_ts": 42,
    }
    if tweaks is not None:
        device["tweaks"] = tweaks
    if default_payload is not None:
        device["data"] = {"default_payload": default_payload}
    return device


def _make_notification(
    *,
    event_type: Optional[str] = RTC_NOTIFICATION_TYPE,
    content: Optional[Dict[str, Any]] = None,
    sender: Optional[str] = "@alice:example.com",
    sender_display_name: Optional[str] = "Alice",
    room_id: Optional[str] = "!room:example.com",
    event_id: Optional[str] = "$event1",
    room_name: Optional[str] = None,
    prio: str = "high",
    tweaks: Optional[Dict[str, Any]] = None,
    default_payload: Optional[Dict[str, Any]] = None,
    unread: Optional[int] = 1,
) -> Notification:
    raw: Dict[str, Any] = {
        "room_id": room_id,
        "event_id": event_id,
        "prio": prio,
        "devices": [_make_device(tweaks=tweaks, default_payload=default_payload)],
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
    if unread is not None:
        raw["counts"] = {"unread": unread}
    return Notification(raw)


class MindroomApnsPushkinTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.now_ms = BASE_NOW_MS
        self.sent_requests: List[NotificationRequest] = []
        self.send_handler: Callable[[NotificationRequest], NotificationResult] = (
            lambda req: NotificationResult(req.notification_id, "200")
        )

        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        asyncio._set_running_loop(self.loop)

        self.reactor = MemoryReactorClock()
        self.apns_mock_class = patch("sygnal.apnspushkin.APNs").start()
        self.apns_mock = MagicMock()
        self.apns_mock.send_notification.side_effect = self._fake_apns_send
        self.apns_mock_class.return_value = self.apns_mock

        patch("os.path.exists", lambda path: path == FAKE_KEYFILE).start()
        patch.object(mindroom_pushkin, "now_ms", side_effect=lambda: self.now_ms).start()
        self.addCleanup(self._cleanup)

        config = merge_left_with_defaults(
            CONFIG_DEFAULTS,
            {
                "log": {
                    "setup": {
                        "version": 1,
                        "disable_existing_loggers": False,
                    }
                },
                "apps": {
                    APP_ID: {
                        "type": "mindroom_pushkin.MindroomApnsPushkin",
                        "keyfile": FAKE_KEYFILE,
                        "key_id": "KEYID12345",
                        "team_id": "TEAMID1234",
                        "topic": APP_ID,
                        "platform": "production",
                        "convert_device_token_to_hex": False,
                    }
                }
            },
        )
        self.sygnal = Sygnal(config, self.reactor)  # type: ignore[arg-type]
        self.pushkin = self._run_deferred(
            self.sygnal._make_pushkin(APP_ID, config["apps"][APP_ID])
        )
        self.assertIsInstance(self.pushkin, MindroomApnsPushkin)

    def _cleanup(self) -> None:
        patch.stopall()
        asyncio._set_running_loop(None)
        self.loop.close()

    async def _fake_apns_send(self, request: NotificationRequest) -> NotificationResult:
        # Snapshot the request payload at send time so later mutations cannot hide bugs.
        self.sent_requests.append(copy.deepcopy(request))
        return self.send_handler(request)

    def _drain_asyncio(self) -> None:
        asyncio._set_running_loop(None)
        try:
            self.loop.run_until_complete(asyncio.sleep(0))
            self.loop.run_until_complete(asyncio.sleep(0))
        finally:
            asyncio._set_running_loop(self.loop)

    def _run_deferred(
        self,
        coro: Any,
        *,
        advance_seconds: Optional[List[int]] = None,
    ) -> Any:
        result_box: List[Any] = []
        error_box: List[BaseException] = []
        d = ensureDeferred(coro)
        d.addCallbacks(
            lambda value: result_box.append(value),
            lambda failure: error_box.append(failure.value),
        )
        self._drain_asyncio()
        for secs in advance_seconds or []:
            if d.called:
                break
            self.now_ms += secs * 1000
            self.reactor.advance(secs)
            self._drain_asyncio()
        self.assertTrue(d.called, "Deferred did not finish")
        if error_box:
            raise error_box[0]
        return result_box[0]

    def _dispatch(
        self,
        notif: Notification,
        *,
        advance_seconds: Optional[List[int]] = None,
    ) -> List[str]:
        ctx = NotificationContext(
            request_id="req-1",
            opentracing_span=self.sygnal.tracer.start_span("test"),
            start_time=0.0,
        )
        return self._run_deferred(
            self.pushkin.dispatch_notification(notif, notif.devices[0], ctx),
            advance_seconds=advance_seconds,
        )

    def test_clear_audio_ring(self) -> None:
        sender_ts = self.now_ms - 2_000
        notif = _make_notification(
            event_type=RTC_NOTIFICATION_TYPE,
            content={
                "notification_type": "ring",
                "sender_ts": sender_ts,
                "lifetime": 30_000,
                "m.call.intent": "audio",
            },
            tweaks={"sound": "ring"},
            default_payload={"aps": {"sound": "default", "mutable-content": 1}},
        )
        rejected = self._dispatch(notif)
        self.assertEqual(rejected, [])
        self.assertEqual(len(self.sent_requests), 1)
        req = self.sent_requests[0]
        self.assertEqual(req.priority, 10)
        self.assertEqual(req.time_to_live, 28)
        self.assertEqual(
            req.message["aps"]["alert"],
            {"loc-key": "VOICE_CALL_FROM_USER", "loc-args": ["Alice"]},
        )
        self.assertEqual(req.message["aps"]["sound"], RING_SOUND)
        self.assertEqual(req.message["aps"]["mutable-content"], 1)
        self.assertEqual(
            req.message[RING_PAYLOAD_KEY],
            {"expires_at": sender_ts + 30_000},
        )
        self.assertEqual(req.message["room_id"], "!room:example.com")
        self.assertEqual(req.message["event_id"], "$event1")

    def test_hint_encrypted_ring_audio_in_named_room(self) -> None:
        sender_ts = self.now_ms - 1_500
        notif = _make_notification(
            event_type=ENCRYPTED_EVENT_TYPE,
            room_name="Small Group",
            content={
                "algorithm": "m.megolm.v1.aes-sha2",
                "ciphertext": "opaque-ciphertext",
                RING_HINT_KEY: {
                    "notification_type": "ring",
                    "sender_ts": sender_ts,
                    "lifetime": 30_000,
                    "m.call.intent": "audio",
                },
            },
            tweaks={"sound": "ring"},
        )
        rejected = self._dispatch(notif)
        self.assertEqual(rejected, [])
        self.assertEqual(len(self.sent_requests), 1)
        req = self.sent_requests[0]
        self.assertEqual(req.priority, 10)
        # 28_500 ms remaining -> ceil(28.5) == 29 s
        self.assertEqual(req.time_to_live, 29)
        self.assertEqual(
            req.message["aps"]["alert"],
            {"loc-key": "VOICE_CALL_FROM_USER", "loc-args": ["Alice"]},
        )
        self.assertEqual(req.message["aps"]["sound"], RING_SOUND)
        self.assertEqual(
            req.message[RING_PAYLOAD_KEY],
            {"expires_at": sender_ts + 30_000},
        )

    def test_video_ring_clear_and_encrypted(self) -> None:
        sender_ts = self.now_ms - 1_000
        cases = [
            (
                RTC_NOTIFICATION_TYPE,
                {
                    "notification_type": "ring",
                    "sender_ts": sender_ts,
                    "lifetime": 30_000,
                    "m.call.intent": "video",
                },
            ),
            (
                ENCRYPTED_EVENT_TYPE,
                {
                    "algorithm": "m.megolm.v1.aes-sha2",
                    "ciphertext": "opaque",
                    RING_HINT_KEY: {
                        "notification_type": "ring",
                        "sender_ts": sender_ts,
                        "lifetime": 30_000,
                        "m.call.intent": "video",
                    },
                },
            ),
        ]
        for event_type, content in cases:
            with self.subTest(event_type=event_type):
                self.sent_requests.clear()
                notif = _make_notification(
                    event_type=event_type,
                    content=content,
                    sender_display_name="Test Caller",
                    tweaks={"sound": "ring"},
                )
                self._dispatch(notif)
                self.assertEqual(len(self.sent_requests), 1)
                req = self.sent_requests[0]
                self.assertEqual(
                    req.message["aps"]["alert"],
                    {"loc-key": "VIDEO_CALL_FROM_USER", "loc-args": ["Test Caller"]},
                )
                self.assertEqual(req.message["aps"]["sound"], RING_SOUND)
                self.assertEqual(req.priority, 10)
                self.assertEqual(req.time_to_live, 29)

    def test_ring_default_intent_and_sender_name_fallbacks(self) -> None:
        cases = [
            ("", "@bob:example.com", "@bob:example.com"),
            (None, "@bob:example.com", "@bob:example.com"),
            (None, None, " "),
            ("A" * 2000, "@bob:example.com", "A" * self.pushkin.MAX_FIELD_LENGTH),
        ]
        for display_name, sender, expected in cases:
            with self.subTest(display_name=display_name, sender=sender):
                self.sent_requests.clear()
                notif = _make_notification(
                    event_type=RTC_NOTIFICATION_TYPE,
                    sender=sender,
                    sender_display_name=display_name,
                    content={
                        "notification_type": "ring",
                        "sender_ts": self.now_ms,
                        "lifetime": 30_000,
                    },
                    tweaks={"sound": "ring"},
                )
                self._dispatch(notif)
                self.assertEqual(len(self.sent_requests), 1)
                self.assertEqual(
                    self.sent_requests[0].message["aps"]["alert"],
                    {"loc-key": "VOICE_CALL_FROM_USER", "loc-args": [expected]},
                )

    def test_ring_forces_high_priority_and_caps_lifetime(self) -> None:
        notif = _make_notification(
            event_type=RTC_NOTIFICATION_TYPE,
            prio="low",
            content={
                "notification_type": "ring",
                "sender_ts": self.now_ms,
                "lifetime": 600_000,
            },
            tweaks={"sound": "ring"},
        )
        self._dispatch(notif)
        self.assertEqual(len(self.sent_requests), 1)
        req = self.sent_requests[0]
        self.assertEqual(req.priority, 10)
        self.assertEqual(
            req.message[RING_PAYLOAD_KEY],
            {"expires_at": self.now_ms + MAX_RING_LIFETIME_MS},
        )
        self.assertEqual(req.time_to_live, 120)

    def test_group_notification_unchanged(self) -> None:
        cases = [
            (
                RTC_NOTIFICATION_TYPE,
                {
                    "notification_type": "notification",
                    "sender_ts": self.now_ms,
                    "lifetime": 30_000,
                },
            ),
            (
                ENCRYPTED_EVENT_TYPE,
                {
                    "algorithm": "m.megolm.v1.aes-sha2",
                    "ciphertext": "opaque",
                    RING_HINT_KEY: {
                        "notification_type": "notification",
                        "sender_ts": self.now_ms,
                        "lifetime": 30_000,
                    },
                },
            ),
        ]
        for event_type, content in cases:
            with self.subTest(event_type=event_type):
                self.sent_requests.clear()
                notif = _make_notification(
                    event_type=event_type,
                    content=content,
                    tweaks={"sound": "ring"},
                    default_payload={"aps": {"sound": "default"}},
                )
                self._dispatch(notif)
                self.assertEqual(len(self.sent_requests), 1)
                req = self.sent_requests[0]
                self.assertEqual(
                    req.message["aps"]["alert"],
                    {"loc-key": "MSG_FROM_USER", "loc-args": ["Alice"]},
                )
                self.assertEqual(req.message["aps"]["sound"], "default")
                self.assertNotIn(RING_PAYLOAD_KEY, req.message)
                self.assertIsNone(req.time_to_live)

    def test_legacy_call_invite_unchanged(self) -> None:
        cases = [
            ("VOICE_CALL_FROM_USER", "v=0\r\nm=audio 9 RTP/AVP 0\r\n"),
            ("VIDEO_CALL_FROM_USER", "v=0\r\nm=audio 9 RTP/AVP 0\r\nm=video 9 RTP/AVP 96\r\n"),
        ]
        for expected_key, sdp in cases:
            with self.subTest(expected_key=expected_key):
                self.sent_requests.clear()
                notif = _make_notification(
                    event_type="m.call.invite",
                    content={
                        "offer": {"type": "offer", "sdp": sdp},
                        "notification_type": "ring",
                        "sender_ts": self.now_ms,
                        "lifetime": 30_000,
                    },
                    tweaks={"sound": "ring"},
                    default_payload={"aps": {"sound": "default"}},
                )
                self._dispatch(notif)
                self.assertEqual(len(self.sent_requests), 1)
                req = self.sent_requests[0]
                self.assertEqual(
                    req.message["aps"]["alert"],
                    {"loc-key": expected_key, "loc-args": ["Alice"]},
                )
                self.assertEqual(req.message["aps"]["sound"], "default")
                self.assertNotIn(RING_PAYLOAD_KEY, req.message)
                self.assertIsNone(req.time_to_live)

    def test_wrong_wire_type_unchanged(self) -> None:
        valid_ring = {
            "notification_type": "ring",
            "sender_ts": self.now_ms,
            "lifetime": 30_000,
            "m.call.intent": "audio",
        }
        cases = [
            # m.room.message carrying top-level ring fields
            ("m.room.message", {**valid_ring, "msgtype": "m.text", "body": "hello"}),
            # m.room.message carrying encrypted hint field
            ("m.room.message", {"msgtype": "m.text", "body": "hello", RING_HINT_KEY: valid_ring}),
            # RTC notification with ring fields nested under hint instead of top-level
            (RTC_NOTIFICATION_TYPE, {RING_HINT_KEY: valid_ring}),
            # m.room.encrypted with ring fields at top-level instead of under hint
            (ENCRYPTED_EVENT_TYPE, {**valid_ring, "algorithm": "m.megolm.v1.aes-sha2"}),
            # Unknown event type carrying ring fields
            ("com.example.custom", valid_ring),
        ]
        for event_type, content in cases:
            with self.subTest(event_type=event_type, content_keys=sorted(content.keys())):
                self.sent_requests.clear()
                notif = _make_notification(
                    event_type=event_type,
                    content=content,
                    tweaks={"sound": "ring"},
                    default_payload={"aps": {"sound": "default"}},
                )
                self._dispatch(notif)
                self.assertEqual(len(self.sent_requests), 1)
                req = self.sent_requests[0]
                self.assertNotEqual(
                    req.message["aps"]["alert"]["loc-key"], "VOICE_CALL_FROM_USER"
                )
                self.assertNotEqual(
                    req.message["aps"]["alert"]["loc-key"], "VIDEO_CALL_FROM_USER"
                )
                self.assertEqual(req.message["aps"]["sound"], "default")
                self.assertNotIn(RING_PAYLOAD_KEY, req.message)
                self.assertIsNone(req.time_to_live)

    def test_bad_or_far_future_timestamps_unchanged(self) -> None:
        bad_contents: List[Dict[str, Any]] = [
            {"notification_type": "ring", "lifetime": 30_000},
            {"notification_type": "ring", "sender_ts": self.now_ms},
            {"notification_type": "ring", "sender_ts": None, "lifetime": 30_000},
            {"notification_type": "ring", "sender_ts": self.now_ms, "lifetime": None},
            {"notification_type": "ring", "sender_ts": str(self.now_ms), "lifetime": 30_000},
            {"notification_type": "ring", "sender_ts": self.now_ms, "lifetime": "30000"},
            {"notification_type": "ring", "sender_ts": float(self.now_ms), "lifetime": 30_000},
            {"notification_type": "ring", "sender_ts": self.now_ms, "lifetime": 30000.0},
            {"notification_type": "ring", "sender_ts": True, "lifetime": 30_000},
            {"notification_type": "ring", "sender_ts": self.now_ms, "lifetime": True},
            {"notification_type": "ring", "sender_ts": 0, "lifetime": 30_000},
            {"notification_type": "ring", "sender_ts": -1_000, "lifetime": 30_000},
            {"notification_type": "ring", "sender_ts": self.now_ms, "lifetime": 0},
            {"notification_type": "ring", "sender_ts": self.now_ms, "lifetime": -5_000},
            {
                "notification_type": "ring",
                "sender_ts": self.now_ms + MAX_CLOCK_SKEW_MS + 1,
                "lifetime": 30_000,
            },
        ]
        for content in bad_contents:
            with self.subTest(content=content):
                self.sent_requests.clear()
                notif = _make_notification(
                    event_type=RTC_NOTIFICATION_TYPE,
                    content=content,
                    tweaks={"sound": "ring"},
                    default_payload={"aps": {"sound": "default"}},
                )
                self._dispatch(notif)
                self.assertEqual(len(self.sent_requests), 1)
                req = self.sent_requests[0]
                self.assertEqual(
                    req.message["aps"]["alert"],
                    {"loc-key": "MSG_FROM_USER", "loc-args": ["Alice"]},
                )
                self.assertEqual(req.message["aps"]["sound"], "default")
                self.assertNotIn(RING_PAYLOAD_KEY, req.message)
                self.assertIsNone(req.time_to_live)

    def test_clock_skew_upper_bound_accepted(self) -> None:
        sender_ts = self.now_ms + MAX_CLOCK_SKEW_MS
        notif = _make_notification(
            event_type=RTC_NOTIFICATION_TYPE,
            content={
                "notification_type": "ring",
                "sender_ts": sender_ts,
                "lifetime": 30_000,
            },
            tweaks={"sound": "ring"},
        )
        self._dispatch(notif)
        self.assertEqual(len(self.sent_requests), 1)
        req = self.sent_requests[0]
        self.assertEqual(req.message["aps"]["sound"], RING_SOUND)
        self.assertEqual(req.time_to_live, 50)

    def test_no_ring_tweak_unchanged(self) -> None:
        for tweaks in (None, {}, {"sound": "default"}):
            with self.subTest(tweaks=tweaks):
                self.sent_requests.clear()
                notif = _make_notification(
                    event_type=RTC_NOTIFICATION_TYPE,
                    content={
                        "notification_type": "ring",
                        "sender_ts": self.now_ms,
                        "lifetime": 30_000,
                    },
                    tweaks=tweaks,
                    default_payload={"aps": {"sound": "default"}},
                )
                self._dispatch(notif)
                self.assertEqual(len(self.sent_requests), 1)
                req = self.sent_requests[0]
                self.assertEqual(
                    req.message["aps"]["alert"],
                    {"loc-key": "MSG_FROM_USER", "loc-args": ["Alice"]},
                )
                self.assertEqual(req.message["aps"]["sound"], "default")
                self.assertNotIn(RING_PAYLOAD_KEY, req.message)
                self.assertIsNone(req.time_to_live)

    def test_regular_low_priority_and_event_id_only_unchanged(self) -> None:
        regular = _make_notification(
            event_type="m.room.message",
            content={"msgtype": "m.text", "body": "Hi"},
            prio="low",
        )
        self._dispatch(regular)
        self.assertEqual(len(self.sent_requests), 1)
        self.assertEqual(self.sent_requests[0].priority, 5)
        self.assertIsNone(self.sent_requests[0].time_to_live)
        self.assertNotIn(RING_PAYLOAD_KEY, self.sent_requests[0].message)

        self.sent_requests.clear()
        event_id_only = Notification(
            {
                "room_id": "!room:example.com",
                "event_id": "$event2",
                "counts": {"unread": 3},
                "devices": [
                    _make_device(
                        tweaks={"sound": "ring"},
                        default_payload={"aps": {"mutable-content": 1}},
                    )
                ],
            }
        )
        self._dispatch(event_id_only)
        self.assertEqual(len(self.sent_requests), 1)
        req = self.sent_requests[0]
        self.assertEqual(req.message["event_id"], "$event2")
        self.assertNotIn(RING_PAYLOAD_KEY, req.message)
        self.assertIsNone(req.time_to_live)

    def test_forged_mindroom_ring_in_default_payload_stripped_for_non_ring(self) -> None:
        notif = _make_notification(
            event_type="m.room.message",
            content={"msgtype": "m.text", "body": "Normal message"},
            default_payload={
                "aps": {"sound": "default"},
                RING_PAYLOAD_KEY: {"expires_at": self.now_ms - 10_000},
            },
        )
        rejected = self._dispatch(notif)
        self.assertEqual(rejected, [])
        self.assertEqual(len(self.sent_requests), 1)
        req = self.sent_requests[0]
        self.assertNotIn(RING_PAYLOAD_KEY, req.message)
        self.assertIsNone(req.time_to_live)

    def test_expired_before_first_try_dropped(self) -> None:
        cases = [
            # Exact deadline boundary (expires_at == now)
            (self.now_ms - 30_000, 30_000),
            # Already well past deadline (expires_at < now)
            (self.now_ms - 60_000, 30_000),
        ]
        for sender_ts, lifetime in cases:
            with self.subTest(sender_ts=sender_ts, lifetime=lifetime):
                self.sent_requests.clear()
                notif = _make_notification(
                    event_type=RTC_NOTIFICATION_TYPE,
                    content={
                        "notification_type": "ring",
                        "sender_ts": sender_ts,
                        "lifetime": lifetime,
                    },
                    tweaks={"sound": "ring"},
                )
                rejected = self._dispatch(notif)
                self.assertEqual(rejected, [])
                self.assertEqual(self.sent_requests, [])

    def test_expired_before_retry_dropped(self) -> None:
        # 5 seconds left on attempt 0; Sygnal's first retry delay is 10 seconds,
        # so by attempt 1 the ring has expired and must not be resent.
        self.send_handler = lambda req: NotificationResult(
            req.notification_id, "503", description="ServiceUnavailable"
        )
        notif = _make_notification(
            event_type=RTC_NOTIFICATION_TYPE,
            content={
                "notification_type": "ring",
                "sender_ts": self.now_ms - 25_000,
                "lifetime": 30_000,
            },
            tweaks={"sound": "ring"},
        )
        rejected = self._dispatch(notif, advance_seconds=[10])
        self.assertEqual(rejected, [])
        self.assertEqual(len(self.sent_requests), 1)
        self.assertEqual(self.sent_requests[0].time_to_live, 5)

    def test_live_retry_recomputes_time_to_live(self) -> None:
        # 25 seconds left on attempt 0 (503), then 15 seconds left on retry (200).
        attempts = 0

        def handler(req: NotificationRequest) -> NotificationResult:
            nonlocal attempts
            attempts += 1
            if attempts == 1:
                return NotificationResult(
                    req.notification_id, "503", description="ServiceUnavailable"
                )
            return NotificationResult(req.notification_id, "200")

        self.send_handler = handler
        notif = _make_notification(
            event_type=ENCRYPTED_EVENT_TYPE,
            content={
                "algorithm": "m.megolm.v1.aes-sha2",
                "ciphertext": "opaque",
                RING_HINT_KEY: {
                    "notification_type": "ring",
                    "sender_ts": self.now_ms - 5_000,
                    "lifetime": 30_000,
                    "m.call.intent": "audio",
                },
            },
            tweaks={"sound": "ring"},
        )
        rejected = self._dispatch(notif, advance_seconds=[10])
        self.assertEqual(rejected, [])
        self.assertEqual(len(self.sent_requests), 2)
        self.assertEqual(self.sent_requests[0].time_to_live, 25)
        self.assertEqual(self.sent_requests[1].time_to_live, 15)

    def test_time_to_live_ceil_rounding(self) -> None:
        cases = [
            (28_001, 29),
            (28_000, 28),
            (1, 1),
        ]
        for remaining_ms, expected_ttl in cases:
            with self.subTest(remaining_ms=remaining_ms):
                self.sent_requests.clear()
                notif = _make_notification(
                    event_type=RTC_NOTIFICATION_TYPE,
                    content={
                        "notification_type": "ring",
                        "sender_ts": self.now_ms + remaining_ms - 30_000,
                        "lifetime": 30_000,
                    },
                    tweaks={"sound": "ring"},
                )
                self._dispatch(notif)
                self.assertEqual(len(self.sent_requests), 1)
                self.assertEqual(self.sent_requests[0].time_to_live, expected_ttl)


    def test_expired_before_second_retry_dropped(self) -> None:
        # 25 s left on attempt 0 (503), 15 s left on attempt 1 at +10 s (503),
        # expired by attempt 2 at +30 s (10 s + 20 s) -> dropped without 3rd try.
        self.send_handler = lambda req: NotificationResult(
            req.notification_id, "503", description="ServiceUnavailable"
        )
        notif = _make_notification(
            event_type=RTC_NOTIFICATION_TYPE,
            content={
                "notification_type": "ring",
                "sender_ts": self.now_ms - 5_000,
                "lifetime": 30_000,
            },
            tweaks={"sound": "ring"},
        )
        rejected = self._dispatch(notif, advance_seconds=[10, 20])
        self.assertEqual(rejected, [])
        self.assertEqual(len(self.sent_requests), 2)
        self.assertEqual(self.sent_requests[0].time_to_live, 25)
        self.assertEqual(self.sent_requests[1].time_to_live, 15)

    def test_malformed_content_and_badge_only_unchanged(self) -> None:
        malformed_hint = _make_notification(
            event_type=ENCRYPTED_EVENT_TYPE,
            content={
                "algorithm": "m.megolm.v1.aes-sha2",
                "ciphertext": "opaque",
                RING_HINT_KEY: "not-a-dict",
            },
            tweaks={"sound": "ring"},
        )
        self._dispatch(malformed_hint)
        self.assertEqual(len(self.sent_requests), 1)
        self.assertNotIn(RING_PAYLOAD_KEY, self.sent_requests[0].message)
        self.assertIsNone(self.sent_requests[0].time_to_live)

        self.sent_requests.clear()
        no_content = _make_notification(
            event_type=RTC_NOTIFICATION_TYPE,
            content=None,
            tweaks={"sound": "ring"},
        )
        self._dispatch(no_content)
        self.assertEqual(len(self.sent_requests), 1)
        self.assertNotIn(RING_PAYLOAD_KEY, self.sent_requests[0].message)
        self.assertIsNone(self.sent_requests[0].time_to_live)

        self.sent_requests.clear()
        badge_only = Notification(
            {
                "type": None,
                "sender": "",
                "counts": {"unread": 2},
                "devices": [_make_device(tweaks={"sound": "ring"})],
            }
        )
        self._dispatch(badge_only)
        self.assertEqual(len(self.sent_requests), 1)
        self.assertEqual(self.sent_requests[0].message, {"aps": {"badge": 2}})
        self.assertIsNone(self.sent_requests[0].time_to_live)


if __name__ == "__main__":
    unittest.main()
