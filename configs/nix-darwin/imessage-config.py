"""Merge Nix-managed settings into a private mautrix-imessage config."""

import json
import os
from pathlib import Path
import sys
import tempfile

import yaml


def merge(target, overrides):
    for key, value in overrides.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            merge(target[key], value)
        else:
            target[key] = value


def main():
    example, private, settings = map(Path, sys.argv[1:])
    config = yaml.safe_load(example.read_text())
    merge(config, yaml.safe_load(private.read_text()))
    merge(config, json.loads(settings.read_text()))
    for key in ("as_token", "hs_token"):
        token = config["appservice"].get(key)
        if not isinstance(token, str) or not token or token.startswith("This value"):
            raise SystemExit("iMessage bridge: generate appservice registration before starting")

    # Atomic replacement keeps credentials private even if preparation fails.
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=private.parent, delete=False) as output:
            temporary = Path(output.name)
            yaml.safe_dump(config, output, sort_keys=False)
        os.replace(temporary, private)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
