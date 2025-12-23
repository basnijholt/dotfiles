#!/usr/bin/env python3
"""Analyze package sizes from common/packages.nix to identify large packages."""

import subprocess
import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

# Packages from common/packages.nix
PACKAGES = [
    # CLI Power Tools
    "_1password-cli", "act", "asciinema", "atuin", "azure-cli", "bandwhich",
    "bat", "btop", "claude-code", "codex", "coreutils", "cups", "docker",
    "devbox", "dnsutils", "duf", "eza", "fastfetch", "fzf", "gemini-cli",
    "google-cloud-sdk", "gh", "git", "git-filter-repo", "git-lfs", "git-secret",
    "gnugrep", "gnupg", "gnused", "gping", "hcloud", "htop", "iperf3", "jq",
    "just", "k9s", "keyd", "lazydocker", "lazygit", "lm_sensors", "lsof",
    "micro", "mosh", "neovim", "nixfmt-rfc-style", "nmap", "packer", "parallel",
    "postgresql", "procs", "psmisc", "pwgen", "rclone", "ripgrep", "starship",
    "tealdeer", "terraform", "tmux", "tokei", "tre-command", "tree", "typst",
    "unzip", "usbutils", "vhs", "wakeonlan", "wget", "yazi", "yq-go", "zellij",
    # Yazi preview deps
    "chafa", "ffmpegthumbnailer", "file", "glow", "poppler-utils",
    # Development toolchains
    "bun", "cargo", "cmake", "gcc", "go", "gnumake", "meson", "nodejs_20",
    "openjdk", "pkg-config", "pnpm", "portaudio", "yarn",
]


def get_package_size(pkg: str) -> tuple[str, int, int]:
    """Get package NAR size and closure size in bytes."""
    try:
        # Get the store path
        result = subprocess.run(
            ["nix", "eval", "--raw", f"nixpkgs#{pkg}.outPath"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            return (pkg, -1, -1)

        store_path = result.stdout.strip()

        # Get NAR size (package itself) and closure size (with all deps)
        result = subprocess.run(
            ["nix", "path-info", "-S", "-s", "--json", store_path],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            return (pkg, -1, -1)

        data = json.loads(result.stdout)
        info = list(data.values())[0]
        nar_size = info.get("narSize", 0)
        closure_size = info.get("closureSize", 0)
        return (pkg, nar_size, closure_size)
    except Exception as e:
        print(f"Error with {pkg}: {e}", file=sys.stderr)
        return (pkg, -1, -1)


def format_size(size_bytes: int) -> str:
    """Format bytes to human readable."""
    if size_bytes < 0:
        return "N/A"
    for unit in ["B", "KB", "MB", "GB"]:
        if size_bytes < 1024:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024
    return f"{size_bytes:.1f} TB"


def main():
    print("Analyzing package sizes (this may take a few minutes)...\n")

    results = []
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {executor.submit(get_package_size, pkg): pkg for pkg in PACKAGES}
        for i, future in enumerate(as_completed(futures), 1):
            pkg, nar, closure = future.result()
            results.append((pkg, nar, closure))
            print(f"\r[{i}/{len(PACKAGES)}] Processed {pkg}...", end="", flush=True)

    print("\n")

    # Sort by closure size (what actually matters for disk space)
    results.sort(key=lambda x: x[2], reverse=True)

    # Print results
    print(f"{'Package':<25} {'NAR Size':>12} {'Closure Size':>14}")
    print("-" * 55)

    total_closure = 0
    large_packages = []  # > 100MB closure
    medium_packages = []  # 50-100MB
    small_packages = []  # < 50MB

    for pkg, nar, closure in results:
        if closure > 0:
            total_closure = max(total_closure, closure)  # Closures overlap

        nar_str = format_size(nar)
        closure_str = format_size(closure)

        if closure > 100 * 1024 * 1024:
            large_packages.append((pkg, closure))
            marker = "🔴"
        elif closure > 50 * 1024 * 1024:
            medium_packages.append((pkg, closure))
            marker = "🟡"
        else:
            small_packages.append((pkg, closure))
            marker = "🟢"

        print(f"{marker} {pkg:<23} {nar_str:>12} {closure_str:>14}")

    print("\n" + "=" * 55)
    print("\n📊 SUMMARY")
    print("-" * 40)
    print(f"🔴 Large (>100MB closure):  {len(large_packages)} packages")
    print(f"🟡 Medium (50-100MB):       {len(medium_packages)} packages")
    print(f"🟢 Small (<50MB):           {len(small_packages)} packages")

    print("\n🔴 LARGE PACKAGES TO CONSIDER REMOVING:")
    for pkg, size in sorted(large_packages, key=lambda x: -x[1]):
        print(f"   {pkg:<25} {format_size(size):>12}")

    print("\n🟡 MEDIUM PACKAGES (optional to remove):")
    for pkg, size in sorted(medium_packages, key=lambda x: -x[1]):
        print(f"   {pkg:<25} {format_size(size):>12}")


if __name__ == "__main__":
    main()
