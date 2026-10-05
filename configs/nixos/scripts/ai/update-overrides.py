#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "requests",
# ]
# ///
"""Update the AI packages in package-overrides.nix to their latest GitHub releases.

Run from configs/nixos. Each package's hashes are replaced with placeholders,
then the package is built until Nix has reported every real hash. Rerunning
after an interruption resumes where it stopped.
"""

import itertools
import re
import subprocess
import sys
from base64 import b64encode
from hashlib import sha256
from pathlib import Path

import requests

FILE = Path("hosts/pc/package-overrides.nix")
# Package attribute: (GitHub repository, release tag prefix)
PACKAGES = {
    "ollama": ("ollama/ollama", "v"),
    "llama-cpp": ("ggml-org/llama.cpp", "b"),
    "llama-swap": ("mostlygeek/llama-swap", "v"),
}
HASH = re.compile(r"sha256-[A-Za-z0-9+/]{43}=")


def parse_version(version: str) -> tuple[int, ...] | None:
    """Parse "0.35.1" or "11430"; return None for tags like "0.40.0-rc3"."""
    try:
        return tuple(int(part) for part in version.split("."))
    except ValueError:
        return None


def latest_release(repo: str, prefix: str) -> str:
    """Return the highest numeric version among the repository's recent releases."""
    response = requests.get(f"https://api.github.com/repos/{repo}/releases")
    response.raise_for_status()
    tags = (release["tag_name"] for release in response.json())
    versions = [tag[len(prefix) :] for tag in tags if tag.startswith(prefix)]
    return max(filter(parse_version, versions), key=parse_version)


def ollama_llama_cpp_tag(version: str) -> str:
    """Return the llama.cpp tag that an Ollama release builds against."""
    url = (
        f"https://raw.githubusercontent.com/ollama/ollama/v{version}/LLAMA_CPP_VERSION"
    )
    response = requests.get(url)
    response.raise_for_status()
    return response.text.strip()


def placeholder(name: str, index: int) -> str:
    """Return a valid fake hash that marks the index-th hash of a package."""
    digest = sha256(f"update-overrides:{name}:{index}".encode()).digest()
    return f"sha256-{b64encode(digest).decode()}"


def package_span(content: str, name: str) -> tuple[int, int]:
    """Return where a package's attribute starts and the next one begins."""
    match = re.search(rf"^( *){re.escape(name)} =", content, re.MULTILINE)
    following = re.compile(rf"^{match[1]}\S", re.MULTILINE).search(content, match.end())
    return match.start(), following.start() if following else len(content)


def bump(content: str, name: str) -> str:
    """Set a package to its latest release and replace its hashes with placeholders."""
    start, end = package_span(content, name)
    block = content[start:end]
    current = re.search(r'version = "([^"]+)"', block)[1]
    latest = latest_release(*PACKAGES[name])
    print(f"{name}: current {current}, latest {latest}")
    if parse_version(latest) <= parse_version(current):
        return content

    block = block.replace(f'version = "{current}"', f'version = "{latest}"')
    if name == "ollama":
        tag = ollama_llama_cpp_tag(latest)
        block = re.sub(r'tag = "b\d+"', f'tag = "{tag}"', block)
    index = itertools.count()
    block = HASH.sub(lambda _: placeholder(name, next(index)), block)
    return content[:start] + block + content[end:]


def hash_mismatch(name: str) -> tuple[str, str]:
    """Build a package and return the hash Nix was given and the one it got."""
    print(f"Building {name} to find its next hash...")
    result = subprocess.run(
        ["nix", "build", f".#nixosConfigurations.pc.pkgs.{name}"]
        + ["--no-link", "--cores", "1"],
        capture_output=True,
        text=True,
        check=False,
    )
    match = re.search(r"specified:\s+(\S+)\s+got:\s+(\S+)", result.stderr)
    if not match:
        sys.exit(f"nix build reported no hash mismatch:\n{result.stderr}")
    return match[1], match[2]


def resolve_hashes(content: str, name: str) -> str:
    """Replace a package's placeholders with the hashes Nix reports."""
    while True:
        start, end = package_span(content, name)
        hashes = HASH.findall(content, start, end)
        pending = [h for i, h in enumerate(hashes) if h == placeholder(name, i)]
        if not pending:
            return content
        specified, got = hash_mismatch(name)
        if specified not in pending:
            sys.exit(f"Nix reported {specified}, expected one of {pending}.")
        print(f"Found {got}")
        content = content.replace(specified, got)
        FILE.write_text(content)


def main() -> None:
    content = FILE.read_text()
    for name in PACKAGES:
        content = bump(content, name)
        FILE.write_text(content)
        content = resolve_hashes(content, name)


if __name__ == "__main__":
    main()
