# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "requests",
# ]
# ///
import re
import subprocess
import sys
from pathlib import Path
import requests


def get_latest_github_release(owner, repo, prefix=""):
    url = f"https://api.github.com/repos/{owner}/{repo}/releases"
    try:
        response = requests.get(url)
        response.raise_for_status()
        releases = response.json()
    except Exception as e:
        print(f"Failed to fetch releases for {owner}/{repo}: {e}")
        return None

    max_ver = 0
    for release in releases:
        name = release["tag_name"]
        if name.startswith(prefix):
            try:
                # Strip prefix and parse int
                ver_str = name[len(prefix) :]
                # Handle cases like "v1.2" if necessary, but here we expect integers for bXXX or vXXX
                # If there are dots, we might need different logic.
                # For now, llama-cpp (b7205) and llama-swap (v175) use integers.
                ver = int(ver_str)
                if ver > max_ver:
                    max_ver = ver
            except ValueError:
                continue
    return str(max_ver)


def update_llama_cpp(content):
    print("\n--- Checking llama-cpp ---")
    # Regex for: llama-cpp = ... version = "7097";
    version_pattern = re.compile(
        r'(llama-cpp\s*=\s*.*?version\s*=\s*")(\d+)(";)', re.DOTALL
    )
    match = version_pattern.search(content)
    if not match:
        print("Could not find llama-cpp version definition.")
        return content, False

    current_ver = match.group(2)
    latest_ver = get_latest_github_release("ggml-org", "llama.cpp", "b")

    if not latest_ver:
        return content, False

    print(f"Current: {current_ver}, Latest: {latest_ver}")

    if int(latest_ver) <= int(current_ver):
        print("Already up to date.")
        return content, False

    print(f"Updating llama-cpp to {latest_ver}...")
    new_content = version_pattern.sub(rf"\g<1>{latest_ver}\g<3>", content)

    # Find hash after version
    ver_end = match.end()
    hash_pattern = re.compile(r'(hash\s*=\s*")(sha256-.*?|)";')
    hash_match = hash_pattern.search(new_content, pos=ver_end)

    if not hash_match:
        print("Could not find hash field for llama-cpp.")
        return content, False

    dummy_hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

    # Replace hash with dummy
    # We need to reconstruct the string carefully using the match object relative to new_content
    # Since we modified new_content (version replaced), the positions might have shifted?
    # Yes, version length might change.
    # Re-searching is safer.

    # Let's use a scoped replacement.
    # Extract the full llama-cpp block? No, easier to just regex replace the FIRST hash after version.

    prefix = new_content[: hash_match.start(2)]
    suffix = new_content[hash_match.end(2) :]
    content_with_dummy = prefix + dummy_hash + suffix

    return content_with_dummy, True


def update_llama_swap(content):
    print("\n--- Checking llama-swap ---")
    # Regex for URL: .../download/v172/llama-swap_172_linux_amd64...
    # We look for the numeric ID appearing twice in the URL pattern
    url_pattern = re.compile(
        r"(https://github\.com/mostlygeek/llama-swap/releases/download/v)(\d+)(/llama-swap_)(\d+)(_linux_amd64\.tar\.gz)"
    )

    match = url_pattern.search(content)
    if not match:
        print("Could not find llama-swap URL definition.")
        return content, False

    current_ver = match.group(2)  # First capture of version
    # Verify consistency
    if match.group(4) != current_ver:
        print(
            f"Warning: Inconsistent versions in URL: {current_ver} vs {match.group(4)}"
        )

    latest_ver = get_latest_github_release("mostlygeek", "llama-swap", "v")

    if not latest_ver:
        return content, False

    print(f"Current: {current_ver}, Latest: {latest_ver}")

    if int(latest_ver) <= int(current_ver):
        print("Already up to date.")
        return content, False

    print(f"Updating llama-swap to {latest_ver}...")

    # Replace version in URL (both occurrences)
    new_content = url_pattern.sub(rf"\g<1>{latest_ver}\g<3>{latest_ver}\g<5>", content)

    # Find hash for llama-swap
    # It usually follows the URL in fetchurl
    # We search starting from the URL match position
    # But wait, we modified the content.
    # Re-search the new URL to get position
    new_match = url_pattern.search(new_content)
    start_pos = new_match.end()

    hash_pattern = re.compile(r'(hash\s*=\s*")(sha256-.*?|)";')
    hash_match = hash_pattern.search(new_content, pos=start_pos)

    if not hash_match:
        print("Could not find hash field for llama-swap.")
        return content, False

    dummy_hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

    prefix = new_content[: hash_match.start(2)]
    suffix = new_content[hash_match.end(2) :]
    content_with_dummy = prefix + dummy_hash + suffix

    return content_with_dummy, True


def get_new_hash(pkg_attribute):
    print(f"Attempting to build {pkg_attribute} to capture new hash...")
    cmd = [
        "nix",
        "build",
        f".#nixosConfigurations.pc.pkgs.{pkg_attribute}",
        "--no-link",
        "--cores",
        "1",
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    stderr = result.stderr

    got_pattern = re.compile(r"\s+got:\s+(sha256-\S+)")
    got_match = got_pattern.search(stderr)

    if not got_match:
        print(f"Build failed but could not extract new hash for {pkg_attribute}.")
        # print("Stderr output:", stderr) # Verbose
        return None

    return got_match.group(1)


def main():
    file_path = Path("hosts/pc/package-overrides.nix")
    if not file_path.exists():
        print(f"Error: {file_path} not found.")
        sys.exit(1)

    content = file_path.read_text()

    # Process llama-cpp
    content, updated_cpp = update_llama_cpp(content)
    if updated_cpp:
        # Write dummy to file
        file_path.write_text(content)
        new_hash = get_new_hash("llama-cpp")
        if new_hash:
            print(f"Found new hash: {new_hash}")
            content = content.replace(
                "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", new_hash
            )
            file_path.write_text(content)
            print("Successfully updated llama-cpp.")
        else:
            print("Failed to update llama-cpp hash. Reverting manually required.")
            sys.exit(1)

    # Process llama-swap
    # Read content again? No, we have the latest in 'content' variable (with llama-cpp updated)
    content, updated_swap = update_llama_swap(content)
    if updated_swap:
        file_path.write_text(content)
        new_hash = get_new_hash("llama-swap")
        if new_hash:
            print(f"Found new hash: {new_hash}")
            content = content.replace(
                "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", new_hash
            )
            file_path.write_text(content)
            print("Successfully updated llama-swap.")
        else:
            print("Failed to update llama-swap hash.")
            sys.exit(1)


if __name__ == "__main__":
    main()
