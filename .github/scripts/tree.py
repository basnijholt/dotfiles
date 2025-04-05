import subprocess


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

    for line in lines:
        processed_line = line
        for item, desc in descriptions.items():
            if line.strip().endswith(f"── {item}") and item in descriptions:
                padding = " " * (max_length - len(line))
                processed_line = f"{line}{padding}# {desc}"
                break

        output_lines.append(processed_line)

    print("\n".join(output_lines))
