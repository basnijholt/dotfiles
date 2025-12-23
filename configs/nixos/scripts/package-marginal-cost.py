#!/usr/bin/env python3
"""Calculate marginal closure cost of packages - the REAL size impact.

This measures how much each package ACTUALLY adds to a NixOS system,
accounting for shared dependencies.
"""

import subprocess
import json
import sys

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


def get_closure_paths(expr: str) -> set[str]:
    """Get all store paths in a closure."""
    try:
        result = subprocess.run(
            ["nix", "path-info", "-r", "--json", expr],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode != 0:
            return set()
        data = json.loads(result.stdout)
        return set(data.keys())
    except Exception:
        return set()


def get_paths_size(paths: set[str]) -> int:
    """Get total NAR size of a set of paths."""
    if not paths:
        return 0
    try:
        result = subprocess.run(
            ["nix", "path-info", "-s", "--json"] + list(paths),
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode != 0:
            return 0
        data = json.loads(result.stdout)
        return sum(info.get("narSize", 0) for info in data.values())
    except Exception:
        return 0


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
    print("Calculating marginal package costs...")
    print("(This measures ACTUAL additional size, not misleading closure size)\n")

    # Get base system closure - packages you'll DEFINITELY install
    print("Step 1: Building baseline from must-have packages...")

    # Realistic baseline: packages that will always be on the system
    base_pkgs = [
        # Core system
        "coreutils", "bash", "glibc", "openssl", "zlib",
        # Always installed dev tools
        "gcc",           # C compiler - pulls in lots of deps
        "docker",        # Container runtime
        "python3",       # Python interpreter
        "git",           # Version control
        "nodejs_20",     # Node.js runtime
        "neovim",        # Editor
    ]
    base_paths = set()
    for i, pkg in enumerate(base_pkgs, 1):
        print(f"   [{i}/{len(base_pkgs)}] Adding {pkg} to baseline...", end="\r")
        base_paths.update(get_closure_paths(f"nixpkgs#{pkg}"))

    print(f"\n   Baseline has {len(base_paths)} store paths\n")

    print("Step 2: Calculating marginal cost per package...\n")

    results = []
    for i, pkg in enumerate(PACKAGES, 1):
        print(f"\r[{i}/{len(PACKAGES)}] Analyzing {pkg}...", end="", flush=True)

        pkg_paths = get_closure_paths(f"nixpkgs#{pkg}")
        if not pkg_paths:
            results.append((pkg, -1, -1, -1))
            continue

        # Marginal paths = paths this package adds that aren't in base
        marginal_paths = pkg_paths - base_paths
        marginal_size = get_paths_size(marginal_paths)

        # Also get the package's own NAR size
        try:
            result = subprocess.run(
                ["nix", "eval", "--raw", f"nixpkgs#{pkg}.outPath"],
                capture_output=True, text=True, timeout=30,
            )
            pkg_path = result.stdout.strip() if result.returncode == 0 else None

            if pkg_path:
                result = subprocess.run(
                    ["nix", "path-info", "-s", "--json", pkg_path],
                    capture_output=True, text=True, timeout=30,
                )
                if result.returncode == 0:
                    data = json.loads(result.stdout)
                    nar_size = list(data.values())[0].get("narSize", 0)
                else:
                    nar_size = -1
            else:
                nar_size = -1
        except Exception:
            nar_size = -1

        closure_size = get_paths_size(pkg_paths)
        results.append((pkg, nar_size, closure_size, marginal_size))

        # Update base with this package's paths for cumulative analysis
        # (uncomment if you want cumulative marginal cost)
        # base_paths.update(pkg_paths)

    print("\n\n")

    # Sort by marginal size
    results.sort(key=lambda x: x[3], reverse=True)

    print(f"{'Package':<25} {'NAR Size':>12} {'Closure':>12} {'Marginal':>12}")
    print("-" * 65)

    large_marginal = []  # > 50MB marginal
    medium_marginal = []  # 10-50MB
    small_marginal = []  # < 10MB

    for pkg, nar, closure, marginal in results:
        if marginal < 0:
            marker = "⚪"
            small_marginal.append((pkg, marginal))
        elif marginal > 50 * 1024 * 1024:
            marker = "🔴"
            large_marginal.append((pkg, marginal))
        elif marginal > 10 * 1024 * 1024:
            marker = "🟡"
            medium_marginal.append((pkg, marginal))
        else:
            marker = "🟢"
            small_marginal.append((pkg, marginal))

        print(f"{marker} {pkg:<23} {format_size(nar):>12} {format_size(closure):>12} {format_size(marginal):>12}")

    print("\n" + "=" * 65)
    print("\n📊 MARGINAL COST SUMMARY")
    print("-" * 40)
    print(f"🔴 Large marginal (>50MB):   {len(large_marginal)} packages")
    print(f"🟡 Medium marginal (10-50MB): {len(medium_marginal)} packages")
    print(f"🟢 Small marginal (<10MB):    {len(small_marginal)} packages")

    if large_marginal:
        print("\n🔴 PACKAGES WITH LARGE UNIQUE DEPENDENCIES:")
        for pkg, size in sorted(large_marginal, key=lambda x: -x[1]):
            print(f"   {pkg:<25} +{format_size(size):>12}")

    if medium_marginal:
        print("\n🟡 MEDIUM MARGINAL COST:")
        for pkg, size in sorted(medium_marginal, key=lambda x: -x[1]):
            print(f"   {pkg:<25} +{format_size(size):>12}")

    print("\n💡 TIP: Marginal cost shows ACTUAL disk impact when adding to a system.")
    print("   Packages with small marginal cost share most deps with the base system.")


if __name__ == "__main__":
    main()
