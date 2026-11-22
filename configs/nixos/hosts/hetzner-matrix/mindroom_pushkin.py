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

import math
import time
from typing import Any, Dict, List, Optional

from aioapns import NotificationRequest
from aioapns.common import NotificationResult
from opentracing import Span

from sygnal.apnspushkin import ApnsPushkin
from sygnal.notifications import Device, Notification
from sygnal.utils import NotificationLoggerAdapter

RTC_NOTIFICATION_TYPE = "org.matrix.msc4075.rtc.notification"
ENCRYPTED_EVENT_TYPE = "m.room.encrypted"
RING_HINT_KEY = "io.mindroom.rtc.notification"

RING_TWEAK_SOUND = "ring"
RING_SOUND = "ring.wav"
RING_PAYLOAD_KEY = "mindroom_ring"

MAX_RING_LIFETIME_MS = 120_000
MAX_CLOCK_SKEW_MS = 20_000
HIGH_APNS_PRIORITY = 10


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


def _payload_ring_expires_at(payload: Dict[str, Any]) -> Optional[int]:
    """Return the integer ``expires_at`` deadline from a ring payload, if present."""
    ring = payload.get(RING_PAYLOAD_KEY)
    if not isinstance(ring, dict):
        return None
    expires_at = ring.get("expires_at")
    if type(expires_at) is not int:
        return None
    return expires_at


class MindroomApnsPushkin(ApnsPushkin):
    """Sygnal v0.17.0 ApnsPushkin subclass adding MindRoom call-ring alerts."""

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
            payload.pop(RING_PAYLOAD_KEY, None)
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
        expires_at = _payload_ring_expires_at(shaved_payload)
        if expires_at is not None:
            if expires_at <= now_ms():
                log.info(
                    "Dropping expired ring notification (expires_at=%d)",
                    expires_at,
                )
                span.log_kv({"event": "mindroom_ring_expired"})
                return []
            prio = HIGH_APNS_PRIORITY
        return await super()._dispatch_request(
            log, span, device, shaved_payload, prio, notif_id
        )

    async def _send_notification(
        self, request: NotificationRequest
    ) -> NotificationResult:
        expires_at = _payload_ring_expires_at(request.message)
        if expires_at is not None:
            remaining_ms = expires_at - now_ms()
            request.time_to_live = max(0, math.ceil(remaining_ms / 1000))
        return await super()._send_notification(request)
