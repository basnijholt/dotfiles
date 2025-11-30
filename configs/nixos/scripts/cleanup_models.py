#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "PyYAML",
# ]
# ///
import os
import re
import yaml
import glob
import sys

CONFIG_YAML_PATH = "/etc/llama-swap/config.yaml"
CACHE_DIR = os.path.expanduser("~/.cache/llama.cpp/")


def get_configured_models():
    if not os.path.exists(CONFIG_YAML_PATH):
        print(f"Error: {CONFIG_YAML_PATH} not found.")
        sys.exit(1)

    with open(CONFIG_YAML_PATH, "r") as f:
        yaml_text = f.read()

    try:
        config = yaml.safe_load(yaml_text)
        models = config.get("models", {})

        configured_repos = []
        configured_files = []

        for model_config in models.values():
            cmd = model_config.get("cmd", "")

            # Extract repo
            match = re.search(r"(?:-hf|--hf-repo)\s+([^\s]+)", cmd)
            if match:
                repo_tag = match.group(1)
                if ":" in repo_tag:
                    repo_tag = repo_tag.split(":")[0]
                configured_repos.append(repo_tag)

            # Extract mmproj-url filename
            match_mmproj = re.search(r"--mmproj-url\s+([^\s]+)", cmd)
            if match_mmproj:
                url = match_mmproj.group(1)
                filename = url.split("/")[-1]
                configured_files.append(filename)

        return configured_repos, configured_files
    except yaml.YAMLError as e:
        print(f"Error parsing YAML: {e}")
        sys.exit(1)


def get_cached_files():
    if not os.path.exists(CACHE_DIR):
        print(f"Cache directory {CACHE_DIR} does not exist.")
        return []

    # We look for files that look like model files
    files = glob.glob(os.path.join(CACHE_DIR, "*"))
    return files


def main():
    configured_repos, configured_files = get_configured_models()
    # Normalize configured repos for matching against cache filenames
    # unsloth/Qwen3 -> unsloth_Qwen3
    configured_patterns = [repo.replace("/", "_").lower() for repo in configured_repos]

    # Add specific files to patterns (or check explicitly)
    # configured_files are exact filenames like "mmproj-model-f16.gguf"

    cached_files = get_cached_files()

    unused_files = []
    total_size = 0

    print(f"{'Unused Cached File':<60} | {'Size (GB)':<10}")
    print("-" * 75)

    for f in cached_files:
        if os.path.isdir(f):
            continue

        fname = os.path.basename(f)
        fname_lower = fname.lower()

        # Check if this file belongs to any configured repo or matches a configured file
        is_configured = False

        # Check repos
        for pattern in configured_patterns:
            if pattern in fname_lower:
                is_configured = True
                break

        # Check specific files
        if not is_configured:
            if fname in configured_files:
                is_configured = True

        if not is_configured:
            # Check for common extensions to avoid listing random metadata files if desired,
            # though usually we want to clean everything.
            if not (
                fname.endswith(".json") or fname.endswith(".etag")
            ):  # Optional: filter only heavy files
                size = os.path.getsize(f)
                size_gb = size / (1024**3)
                unused_files.append((f, size_gb))
                print(f"{fname:<60} | {size_gb:.2f}")
                total_size += size_gb

    print("-" * 75)
    print(f"Total potentially unused size: {total_size:.2f} GB")

    if unused_files:
        response = input("\nDo you want to delete these files? (y/N): ").strip().lower()
        if response == "y":
            for f, size in unused_files:
                try:
                    os.remove(f)
                    print(f"Deleted {os.path.basename(f)}")
                except Exception as e:
                    print(f"Error deleting {f}: {e}")
            print("Cleanup complete.")
        else:
            print("No files deleted.")
    else:
        print("No unused files found.")


if __name__ == "__main__":
    main()
