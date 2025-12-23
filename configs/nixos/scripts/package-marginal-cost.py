#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.12"
# dependencies = ["tree-sitter", "tree-sitter-nix", "rich"]
# ///
"""Calculate marginal closure cost of packages - the REAL size impact.

This measures how much each package ACTUALLY adds to a NixOS system,
accounting for shared dependencies. Parses packages.nix using tree-sitter.
"""

import json
import subprocess
from pathlib import Path

import tree_sitter_nix as tsnix
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn
from rich.table import Table
from tree_sitter import Language, Parser

SCRIPT_DIR = Path(__file__).parent
PACKAGES_NIX = SCRIPT_DIR.parent / "common" / "packages.nix"

console = Console()


def parse_packages_from_nix(nix_file: Path) -> list[str]:
    """Parse package names from a Nix file using tree-sitter."""
    NIX_LANGUAGE = Language(tsnix.language())
    parser = Parser(NIX_LANGUAGE)

    source = nix_file.read_bytes()
    tree = parser.parse(source)

    packages = []

    def extract_identifiers(node, in_list=False):
        """Recursively extract package identifiers from list expressions."""
        if node.type == "list_expression":
            for child in node.children:
                extract_identifiers(child, in_list=True)
        elif node.type == "parenthesized_expression" and in_list:
            # Preserve in_list context through parentheses
            for child in node.children:
                extract_identifiers(child, in_list=True)
        elif node.type == "identifier" and in_list:
            name = source[node.start_byte : node.end_byte].decode()
            packages.append(name)
        elif node.type == "apply_expression" and in_list:
            # Handle things like (python3.withPackages ...)
            func_node = node.children[0] if node.children else None
            if func_node and func_node.type == "select_expression":
                # Get the base identifier (e.g., "python3")
                # Structure: select_expression -> variable_expression -> identifier
                if func_node.children:
                    base = func_node.children[0]
                    if base.type == "variable_expression" and base.children:
                        ident = base.children[0]
                        if ident.type == "identifier":
                            name = source[ident.start_byte : ident.end_byte].decode()
                            packages.append(name)
        else:
            for child in node.children:
                extract_identifiers(child, in_list)

    extract_identifiers(tree.root_node)

    # Filter out Nix keywords and common non-package identifiers
    keywords = {"with", "pkgs", "let", "in", "ps", "rec"}
    packages = [p for p in packages if p not in keywords]

    return packages


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
            ["nix", "path-info", "-s", "--json", *list(paths)],
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
    console.print("\n[bold blue]📦 Package Marginal Cost Analyzer[/bold blue]")
    console.print("Measures ACTUAL additional size, not misleading closure size\n")

    # Parse packages from nix file
    console.print(f"[dim]Parsing packages from {PACKAGES_NIX}...[/dim]")
    packages = parse_packages_from_nix(PACKAGES_NIX)
    console.print(f"[green]Found {len(packages)} packages[/green]\n")

    # Build baseline from must-have packages
    base_pkgs = [
        "coreutils",
        "bash",
        "glibc",
        "openssl",
        "zlib",
        "gcc",
        "docker",
        "python3",
        "git",
        "nodejs_20",
        "neovim",
    ]

    base_paths = set()
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
        console=console,
    ) as progress:
        task = progress.add_task("[cyan]Building baseline...", total=len(base_pkgs))
        for pkg in base_pkgs:
            base_paths.update(get_closure_paths(f"nixpkgs#{pkg}"))
            progress.advance(task)

    console.print(f"[dim]Baseline has {len(base_paths)} store paths[/dim]\n")

    # Calculate marginal cost per package
    results = []
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
        console=console,
    ) as progress:
        task = progress.add_task("[cyan]Analyzing packages...", total=len(packages))
        for pkg in packages:
            progress.update(task, description=f"[cyan]Analyzing {pkg}...")

            pkg_paths = get_closure_paths(f"nixpkgs#{pkg}")
            if not pkg_paths:
                results.append((pkg, -1, -1, -1))
                progress.advance(task)
                continue

            marginal_paths = pkg_paths - base_paths
            marginal_size = get_paths_size(marginal_paths)

            # Get package's own NAR size
            try:
                result = subprocess.run(
                    ["nix", "eval", "--raw", f"nixpkgs#{pkg}.outPath"],
                    capture_output=True,
                    text=True,
                    timeout=30,
                )
                pkg_path = result.stdout.strip() if result.returncode == 0 else None

                if pkg_path:
                    result = subprocess.run(
                        ["nix", "path-info", "-s", "--json", pkg_path],
                        capture_output=True,
                        text=True,
                        timeout=30,
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
            progress.advance(task)

    # Sort by marginal size
    results.sort(key=lambda x: x[3], reverse=True)

    # Build results table
    table = Table(title="\n📊 Package Analysis Results", show_header=True)
    table.add_column("", width=2)
    table.add_column("Package", style="cyan", width=25)
    table.add_column("NAR Size", justify="right", width=12)
    table.add_column("Closure", justify="right", width=12)
    table.add_column("Marginal", justify="right", width=12)

    large_marginal = []
    medium_marginal = []
    small_marginal = []

    for pkg, nar, closure, marginal in results:
        if marginal < 0:
            marker = "⚪"
            style = "dim"
            small_marginal.append((pkg, marginal))
        elif marginal > 50 * 1024 * 1024:
            marker = "🔴"
            style = "red bold"
            large_marginal.append((pkg, marginal))
        elif marginal > 10 * 1024 * 1024:
            marker = "🟡"
            style = "yellow"
            medium_marginal.append((pkg, marginal))
        else:
            marker = "🟢"
            style = "green"
            small_marginal.append((pkg, marginal))

        table.add_row(
            marker,
            pkg,
            format_size(nar),
            format_size(closure),
            f"[{style}]{format_size(marginal)}[/{style}]",
        )

    console.print(table)

    # Summary
    console.print("\n[bold]📊 MARGINAL COST SUMMARY[/bold]")
    console.print(f"  🔴 Large (>50MB):   [red]{len(large_marginal)}[/red] packages")
    console.print(
        f"  🟡 Medium (10-50MB): [yellow]{len(medium_marginal)}[/yellow] packages"
    )
    console.print(
        f"  🟢 Small (<10MB):    [green]{len(small_marginal)}[/green] packages"
    )

    if large_marginal:
        console.print("\n[bold red]🔴 LARGE UNIQUE DEPENDENCIES:[/bold red]")
        for pkg, size in sorted(large_marginal, key=lambda x: -x[1]):
            console.print(f"   {pkg:<25} [red]+{format_size(size):>12}[/red]")

    if medium_marginal:
        console.print("\n[bold yellow]🟡 MEDIUM MARGINAL COST:[/bold yellow]")
        for pkg, size in sorted(medium_marginal, key=lambda x: -x[1]):
            console.print(f"   {pkg:<25} [yellow]+{format_size(size):>12}[/yellow]")

    console.print(
        "\n[dim]💡 Marginal cost = actual disk impact when adding to a system.[/dim]"
    )
    console.print(
        "[dim]   Small marginal = shares most deps with the baseline.[/dim]\n"
    )


if __name__ == "__main__":
    main()
