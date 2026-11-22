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
"""MindRoom APNs pushkin subclass for Sygnal v0.17.0 incoming-call rings."""

import asyncio
import json
import time
import weakref
from typing import TYPE_CHECKING, Any, Dict, List, Optional, Type

from aioapns import NotificationRequest
from aioapns.common import NotificationResult
from aioapns.exceptions import MaxAttemptsExceeded
from opentracing import Span

from sygnal.apnspushkin import ApnsPushkin
from sygnal.exceptions import TemporaryNotificationDispatchException
from sygnal.notifications import Device, Notification
from sygnal.utils import NotificationLoggerAdapter

if TYPE_CHECKING:
    from sygnal.sygnal import Sygnal

RTC_NOTIFICATION_TYPE = "org.matrix.msc4075.rtc.notification"
ENCRYPTED_EVENT_TYPE = "m.room.encrypted"
RING_HINT_KEY = "io.mindroom.rtc.notification"

RING_TWEAK_SOUND = "ring"
RING_SOUND = "ring.wav"
RING_PAYLOAD_KEY = "mindroom_ring"

MAX_RING_LIFETIME_MS = 120_000
MAX_CLOCK_SKEW_MS = 20_000
HIGH_APNS_PRIORITY = 10


class _ExpiredRingError(Exception):
    """Raised when a ring passes its deadline before APNs frame transmission."""


def now_ms() -> int:
    """Return the current wall-clock time in milliseconds."""
    return int(time.time() * 1000)


def ring_of(n: Notification, now: int) -> Optional[Dict[str, Any]]:
    """Return validated ring fields for ``n``, or None if it is not a valid ring."""
    content = n.content
    if not isinstance(content, dict):
        return None
    if n.type == RTC_NOTIFICATION_TYPE:
        ring = content
    elif n.type == ENCRYPTED_EVENT_TYPE:
        ring = content.get(RING_HINT_KEY)
    else:
        return None
    if not isinstance(ring, dict) or ring.get("notification_type") != "ring":
        return None
    sender_ts = ring.get("sender_ts")
    lifetime = ring.get("lifetime")
    if (
        type(sender_ts) is not int
        or type(lifetime) is not int
        or sender_ts <= 0
        or lifetime <= 0
        or sender_ts > now + MAX_CLOCK_SKEW_MS
    ):
        return None
    return ring


def _make_deadline_protocol_class(
    base_cls: Type[Any],
    request_deadlines: Dict[str, int],
) -> Type[Any]:
    """Subclass an aioapns protocol to enforce ring deadlines at frame send time."""

    class _MindroomDeadlineProtocol(base_cls):  # type: ignore[valid-type, misc]
        async def send_notification(
            self, request: NotificationRequest
        ) -> NotificationResult:
            expires_at = request_deadlines.get(request.notification_id)
            if expires_at is None:
                return await super().send_notification(request)

            if expires_at <= now_ms():
                raise _ExpiredRingError(expires_at)

            stream_id = await self.free_channels.acquire()
            if expires_at <= now_ms():
                self.free_channels.release()
                raise _ExpiredRingError(expires_at)

            headers = [
                (":method", "POST"),
                (":scheme", "https"),
                (":path", "/3/device/%s" % request.device_token),
                ("host", self.APNS_SERVER),
                ("apns-id", request.notification_id),
                ("apns-topic", request.apns_topic or self.apns_topic),
                ("apns-expiration", str(expires_at // 1000)),
            ]
            if request.priority is not None:
                headers.append(("apns-priority", str(request.priority)))
            if request.collapse_key is not None:
                headers.append(("apns-collapse-id", request.collapse_key))
            if request.push_type is not None:
                headers.append(("apns-push-type", request.push_type.value))
            if self.auth_provider:
                headers.append(("authorization", self.auth_provider.get_header()))

            self.conn.send_headers(stream_id=stream_id, headers=headers)
            data = json.dumps(request.message, ensure_ascii=False).encode()
            self.conn.send_data(
                stream_id=stream_id,
                data=data,
                end_stream=True,
            )
            self.flush()

            future_response: asyncio.Future[NotificationResult] = asyncio.Future()
            self.requests[request.notification_id] = future_response
            self.request_streams[stream_id] = request.notification_id
            return await future_response

    return _MindroomDeadlineProtocol


class MindroomApnsPushkin(ApnsPushkin):
    """Sygnal v0.17.0 ApnsPushkin subclass adding MindRoom call-ring alerts."""

    def __init__(self, name: str, sygnal: "Sygnal", config: Dict[str, Any]) -> None:
        super().__init__(name, sygnal, config)
        # Validated ring deadlines tracked out-of-band so caller-supplied
        # default_payload fields can never affect gateway dispatch behavior.
        self._dispatch_deadlines: "weakref.WeakKeyDictionary[NotificationLoggerAdapter, int]" = (
            weakref.WeakKeyDictionary()
        )
        self._request_deadlines: Dict[str, int] = {}
        pool = getattr(self.apns_client, "pool", None)
        protocol_class = getattr(pool, "protocol_class", None)
        if pool is not None and isinstance(protocol_class, type):
            pool.protocol_class = _make_deadline_protocol_class(
                protocol_class, self._request_deadlines
            )

    def _get_payload_full(
        self,
        n: Notification,
        device: Device,
        log: NotificationLoggerAdapter,
        send_badge_counts: bool,
    ) -> Optional[Dict[str, Any]]:
        payload = super()._get_payload_full(n, device, log, send_badge_counts)
        if payload is None:
            return None
        ring = (
            ring_of(n, now_ms())
            if device.tweaks.sound == RING_TWEAK_SOUND
            else None
        )
        aps = payload.get("aps")
        if ring is None or not isinstance(aps, dict) or "alert" not in aps:
            return payload

        name = (n.sender_display_name or n.sender or " ")[: self.MAX_FIELD_LENGTH]
        is_video = ring.get("m.call.intent") == "video"
        aps["alert"] = {
            "loc-key": "VIDEO_CALL_FROM_USER" if is_video else "VOICE_CALL_FROM_USER",
            "loc-args": [name],
        }
        aps["sound"] = RING_SOUND
        expires_at = ring["sender_ts"] + min(ring["lifetime"], MAX_RING_LIFETIME_MS)
        payload[RING_PAYLOAD_KEY] = {"expires_at": expires_at}
        self._dispatch_deadlines[log] = expires_at
        return payload

    async def _dispatch_request(
        self,
        log: NotificationLoggerAdapter,
        span: Span,
        device: Device,
        shaved_payload: Dict[str, Any],
        prio: int,
        notif_id: str,
    ) -> List[str]:
        expires_at = self._dispatch_deadlines.get(log)
        if expires_at is None:
            return await super()._dispatch_request(
                log, span, device, shaved_payload, prio, notif_id
            )

        if expires_at <= now_ms():
            log.info(
                "Dropping expired ring notification (expires_at=%d)",
                expires_at,
            )
            span.log_kv({"event": "mindroom_ring_expired"})
            return []

        self._request_deadlines[notif_id] = expires_at
        try:
            return await super()._dispatch_request(
                log, span, device, shaved_payload, HIGH_APNS_PRIORITY, notif_id
            )
        except _ExpiredRingError:
            log.info(
                "Dropping expired ring notification at send time (expires_at=%d)",
                expires_at,
            )
            span.log_kv({"event": "mindroom_ring_expired"})
            return []
        except (TemporaryNotificationDispatchException, MaxAttemptsExceeded):
            if expires_at <= now_ms():
                log.info(
                    "Dropping expired ring notification after failure (expires_at=%d)",
                    expires_at,
                )
                span.log_kv({"event": "mindroom_ring_expired"})
                return []
            raise
        finally:
            self._request_deadlines.pop(notif_id, None)

    async def _send_notification(
        self, request: NotificationRequest
    ) -> NotificationResult:
        expires_at = self._request_deadlines.get(request.notification_id)
        if expires_at is not None:
            current_ms = now_ms()
            if expires_at <= current_ms:
                raise _ExpiredRingError(expires_at)
            request.time_to_live = max(0, (expires_at // 1000) - (current_ms // 1000))
        return await super()._send_notification(request)
