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
"""Resilient Sygnal pushkin loader that falls back to stock ApnsPushkin."""

import importlib
import logging
from typing import TYPE_CHECKING, Any, Dict

from sygnal.apnspushkin import ApnsPushkin

if TYPE_CHECKING:
    from sygnal.sygnal import Sygnal

logger = logging.getLogger(__name__)


class SafeApnsPushkin:
    """Factory for MindroomApnsPushkin that falls back to stock ApnsPushkin."""

    @classmethod
    async def create(
        cls, name: str, sygnal: "Sygnal", config: Dict[str, Any]
    ) -> ApnsPushkin:
        try:
            mod = importlib.import_module("mindroom_pushkin")
            pushkin_cls = getattr(mod, "MindroomApnsPushkin")
            pushkin = await pushkin_cls.create(name, sygnal, config)
            if not isinstance(pushkin, ApnsPushkin):
                raise TypeError(f"Expected ApnsPushkin, got {type(pushkin)!r}")
            return pushkin
        except Exception:
            logger.exception(
                "Failed to initialize MindroomApnsPushkin for %s; falling back to stock ApnsPushkin",
                name,
            )
            return await ApnsPushkin.create(name, sygnal, config)
