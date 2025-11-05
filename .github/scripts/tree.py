import subprocess
from pathlib import Path


def list_files(folder: str = ".", excludes=(), level: int = 2) -> str:
    # Use tre command with exclusions
    cmd = ["tre", "-l", str(level)]
    for exclude in excludes:
        cmd.append("-E")
        cmd.append(exclude)
    cmd.append(folder)
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout


def print_with_comments(result: str, descriptions: dict) -> str:
    """Add comments to lines based on the descriptions dictionary."""
    lines = result.strip().split("\n")
    output_lines = []

    # Find the maximum length for aligning comments
    max_length = max(len(line) for line in lines) + 2

    # Determine which names are tracked by git (files and their ancestor directories)
    ls = subprocess.run(["git", "ls-files"], capture_output=True, text=True, check=True)
    tracked_names = set()
    for p in ls.stdout.splitlines():
        p = p.strip()
        if not p:
            continue
        parts = Path(p).parts
        tracked_names.update(parts)

    used = set()
    for line in lines:
        processed_line = line
        for item, desc in descriptions.items():
            # Only add a description if the item is tracked (avoid annotating untracked files)
            if line.strip().endswith(f"── {item}") and item in descriptions and item in tracked_names:
                padding = " " * (max_length - len(line))
                processed_line = f"{line}{padding}# {desc}"
                used.add(item)
                break

        output_lines.append(processed_line)
    unused = set(descriptions.keys()) - used
    if unused:
        print(f"❌ Unused descriptions: {unused}")

    print("\n".join(output_lines))
