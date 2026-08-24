#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "requests",
# ]
# ///
"""Update package versions in package-overrides.nix by fetching latest GitHub releases."""

import re
import subprocess
import sys
from base64 import b64encode
from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path

import requests


@dataclass
class Package:
    name: str
    owner: str
    repo: str
    tag_prefix: str
    version_pattern: re.Pattern
    semver: bool = False
    hash_count: int = 1


PACKAGES = [
    Package(
        name="ollama",
        owner="ollama",
        repo="ollama",
        tag_prefix="v",
        version_pattern=re.compile(
            r'(ollama\s*=\s*\(pkgs\.ollama\.override\s*\{[^}]*\}\)\.overrideAttrs\s*\(oldAttrs:\s*rec\s*\{\s*version\s*=\s*")(\d+\.\d+\.\d+)(";)',
            re.DOTALL,
        ),
        semver=True,
        hash_count=3,  # llama.cpp source hash + Ollama source hash + vendorHash
    ),
    Package(
        name="llama-cpp",
        owner="ggml-org",
        repo="llama.cpp",
        tag_prefix="b",
        version_pattern=re.compile(
            r'(llama-cpp\s*=\s*.*?version\s*=\s*")(\d+)(";)', re.DOTALL
        ),
        hash_count=2,  # src hash + npmDepsHash
    ),
    Package(
        name="llama-swap",
        owner="mostlygeek",
        repo="llama-swap",
        tag_prefix="v",
        version_pattern=re.compile(
            r"(https://github\.com/mostlygeek/llama-swap/releases/download/v)(\d+)(/llama-swap_)(\d+)(_linux_amd64\.tar\.gz)"
        ),
    ),
]


def parse_semver(version_str: str) -> tuple[int, ...] | None:
    """Parse semantic version string into tuple for comparison."""
    version_str = version_str.lstrip("v")
    try:
        return tuple(int(p) for p in version_str.split("."))
    except ValueError:
        return None


def get_latest_release(pkg: Package) -> str | None:
    """Fetch latest release version from GitHub."""
    url = f"https://api.github.com/repos/{pkg.owner}/{pkg.repo}/releases"
    try:
        response = requests.get(url)
        response.raise_for_status()
        releases = response.json()
    except Exception as e:
        print(f"Failed to fetch releases for {pkg.owner}/{pkg.repo}: {e}")
        return None

    if pkg.semver:
        max_ver, max_ver_str = (0, 0, 0), None
        for release in releases:
            if release.get("prerelease") or release.get("draft"):
                continue
            tag = release["tag_name"]
            if tag.startswith(pkg.tag_prefix):
                ver_str = tag[len(pkg.tag_prefix) :]
                if (parsed := parse_semver(ver_str)) and parsed > max_ver:
                    max_ver, max_ver_str = parsed, ver_str
        return max_ver_str
    else:
        max_ver = 0
        for release in releases:
            tag = release["tag_name"]
            if tag.startswith(pkg.tag_prefix):
                try:
                    ver = int(tag[len(pkg.tag_prefix) :])
                    max_ver = max(max_ver, ver)
                except ValueError:
                    continue
        return str(max_ver) if max_ver else None


def compare_versions(current: str, latest: str, semver: bool) -> bool:
    """Return True if latest > current."""
    if semver:
        return parse_semver(latest) > parse_semver(current)
    return int(latest) > int(current)


def dummy_hash(package_name: str, slot: int) -> str:
    """Return a stable, valid, package-specific placeholder hash."""
    digest = sha256(f"update-overrides:{package_name}:{slot}".encode()).digest()
    return f"sha256-{b64encode(digest).decode()}"


def replace_hashes_in_block(
    content: str,
    start: int,
    count: int,
    package_name: str = "block",
    slot_offset: int = 0,
) -> str:
    """Replace `count` hash occurrences after `start` position with dummy hash."""
    hash_pattern = re.compile(
        r'((?:hash|vendorHash|npmDepsHash)\s*=\s*")(sha256-[^"]*)(";)'
    )
    package_pattern = re.compile(r"^        [A-Za-z][\w-]*\s*=", re.MULTILINE)
    target_pattern = re.compile(
        rf"^        {re.escape(package_name)}\s*=", re.MULTILINE
    )
    enclosing_packages = [
        match for match in target_pattern.finditer(content) if match.start() <= start
    ]
    if not enclosing_packages:
        raise ValueError(f"Could not find the start of the {package_name} block.")
    current_package = enclosing_packages[-1]
    next_package = package_pattern.search(content, current_package.end())
    end = next_package.start() if next_package else len(content)

    matches = list(hash_pattern.finditer(content, start, end))
    if len(matches) < count:
        raise ValueError(
            f"Expected {count} hashes in the {package_name} block, found {len(matches)}."
        )

    slots = range(slot_offset, slot_offset + count)
    for match, slot in reversed(list(zip(matches[:count], slots, strict=True))):
        placeholder = dummy_hash(package_name, slot)
        content = content[: match.start(2)] + placeholder + content[match.end(2) :]
    return content


def get_ollama_llama_cpp_version(ollama_version: str) -> str | None:
    """Return the llama.cpp build tag pinned by an Ollama release."""
    url = (
        "https://raw.githubusercontent.com/ollama/ollama/"
        f"v{ollama_version}/LLAMA_CPP_VERSION"
    )
    try:
        response = requests.get(url)
        response.raise_for_status()
    except Exception as e:
        print(f"Failed to fetch Ollama LLAMA_CPP_VERSION: {e}")
        return None

    tag = response.text.strip()
    return tag if tag.startswith("b") else None


def update_ollama_llama_cpp_pin(content: str, ollama_version: str) -> str:
    """Update the llama.cpp source pin used by the custom Ollama build."""
    llama_tag = get_ollama_llama_cpp_version(ollama_version)
    if not llama_tag:
        print("Could not determine Ollama llama.cpp pin.")
        sys.exit(1)

    print(f"Ollama {ollama_version} pins llama.cpp {llama_tag}.")

    pattern = re.compile(
        r"(ollamaLlamaCppSrc\s*=\s*pkgs\.fetchFromGitHub\s*\{"
        r"(?:(?!\n\s*\};).)*?"
        r'tag\s*=\s*")([^"]+)(";'
        r"(?:(?!\n\s*\};).)*?"
        r'hash\s*=\s*")([^"]+)(";)',
        re.DOTALL,
    )
    replacement = rf"\g<1>{llama_tag}\g<3>{dummy_hash('ollama', 0)}\g<5>"
    updated, count = pattern.subn(replacement, content, count=1)
    if count != 1:
        print("Could not update ollamaLlamaCppSrc pin.")
        sys.exit(1)

    return updated


def update_version(content: str, pkg: Package) -> tuple[str, bool]:
    """Update package version and replace hashes with dummy values."""
    print(f"\n--- Checking {pkg.name} ---")

    match = pkg.version_pattern.search(content)
    if not match:
        print(f"Could not find {pkg.name} version definition.")
        return content, False

    current = match.group(2)
    latest = get_latest_release(pkg)

    if not latest:
        return content, False

    print(f"Current: {current}, Latest: {latest}")

    if not compare_versions(current, latest, pkg.semver):
        print("Already up to date.")
        return content, False

    print(f"Updating {pkg.name} to {latest}...")

    # Replace version - handle llama-swap special case (version appears twice in URL)
    if pkg.name == "llama-swap":
        content = pkg.version_pattern.sub(rf"\g<1>{latest}\g<3>{latest}\g<5>", content)
    else:
        content = pkg.version_pattern.sub(rf"\g<1>{latest}\g<3>", content)

    if pkg.name == "ollama":
        content = update_ollama_llama_cpp_pin(content, latest)

    # Replace hashes with dummy. Ollama's llama.cpp pin lives before the
    # override block and is handled by update_ollama_llama_cpp_pin().
    updated_match = pkg.version_pattern.search(content)
    if not updated_match:
        print(f"Could not find updated {pkg.name} version definition.")
        return content, False
    block_hash_count = 2 if pkg.name == "ollama" else pkg.hash_count
    slot_offset = 1 if pkg.name == "ollama" else 0
    content = replace_hashes_in_block(
        content, updated_match.start(), block_hash_count, pkg.name, slot_offset
    )

    return content, True


def get_hash_mismatch(pkg_attribute: str) -> tuple[str, str] | None:
    """Build package and return its specified and actual hash mismatch."""
    print(f"Building {pkg_attribute} to capture hash...")
    result = subprocess.run(
        [
            "nix",
            "build",
            f".#nixosConfigurations.pc.pkgs.{pkg_attribute}",
            "--no-link",
            "--cores",
            "1",
        ],
        capture_output=True,
        text=True,
        check=False,
    )

    for stream_content in (result.stdout, result.stderr):
        if match := re.search(
            r"\bspecified:\s+(sha256-[A-Za-z0-9+/=]+).*?"
            r"\bgot:\s+(sha256-[A-Za-z0-9+/=]+)",
            stream_content,
            re.DOTALL,
        ):
            return match.group(1), match.group(2)

    print(
        f"Could not extract hash for {pkg_attribute}; "
        f"nix build exited with status {result.returncode}.",
        file=sys.stderr,
    )
    for stream_name, stream_content in (
        ("stdout", result.stdout),
        ("stderr", result.stderr),
    ):
        if stream_content.strip():
            print(f"--- nix build {stream_name} ---", file=sys.stderr)
            print(stream_content.rstrip(), file=sys.stderr)
    return None


def resolve_hashes(file_path: Path, content: str, pkg: Package) -> str:
    """Resolve dummy hashes by building and extracting correct values."""
    pending_hashes = {
        dummy_hash(pkg.name, slot)
        for slot in range(pkg.hash_count)
        if dummy_hash(pkg.name, slot) in content
    }
    total = len(pending_hashes)
    for i in range(total):
        print(f"Resolving {pkg.name} hash {i + 1}/{total}...")

        mismatch = get_hash_mismatch(pkg.name)
        if not mismatch:
            print(f"Failed to resolve {pkg.name} hash {i + 1}/{total}.")
            sys.exit(1)

        specified_hash, new_hash = mismatch
        print(f"Found hash: {new_hash}")
        if specified_hash not in pending_hashes:
            print(
                f"Nix reported unexpected placeholder {specified_hash} for {pkg.name}."
            )
            sys.exit(1)
        if content.count(specified_hash) != 1:
            print(
                f"Expected exactly one occurrence of {specified_hash} for "
                f"{pkg.name}, found {content.count(specified_hash)}."
            )
            sys.exit(1)
        content = content.replace(specified_hash, new_hash)
        pending_hashes.remove(specified_hash)
        file_path.write_text(content)

    print(f"Successfully updated {pkg.name}.")
    return content


def main():
    file_path = Path("hosts/pc/package-overrides.nix")
    if not file_path.exists():
        print(f"Error: {file_path} not found.")
        sys.exit(1)

    content = file_path.read_text()

    for pkg in PACKAGES:
        content, updated = update_version(content, pkg)
        has_pending_hashes = any(
            dummy_hash(pkg.name, slot) in content for slot in range(pkg.hash_count)
        )
        if updated or has_pending_hashes:
            if has_pending_hashes and not updated:
                print(f"Resuming interrupted {pkg.name} hash resolution...")
            file_path.write_text(content)
            content = resolve_hashes(file_path, content, pkg)


if __name__ == "__main__":
    main()
