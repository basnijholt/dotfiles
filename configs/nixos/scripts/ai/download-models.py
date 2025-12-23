#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "PyYAML",
# ]
# ///
import os
import yaml
import shlex
import subprocess
import sys

CONFIG_YAML_PATH = "/etc/llama-swap/config.yaml"


def parse_args_from_cmd(cmd_str):
    """
    Extracts relevant arguments (-hf, --hf-repo, --hf-file, --mmproj-url)
    from the command string.
    """
    args = shlex.split(cmd_str)
    relevant_args = []

    i = 0
    while i < len(args):
        arg = args[i]

        if arg in ["-hf", "--hf-repo", "--hf-file", "--mmproj-url"]:
            relevant_args.append(arg)
            if i + 1 < len(args):
                relevant_args.append(args[i + 1])
                i += 1

        i += 1

    return relevant_args


def main():
    if not os.path.exists(CONFIG_YAML_PATH):
        print(f"Error: {CONFIG_YAML_PATH} not found.")
        sys.exit(1)

    print(f"Reading configuration from {CONFIG_YAML_PATH}...")
    with open(CONFIG_YAML_PATH, "r") as f:
        yaml_text = f.read()

    try:
        config = yaml.safe_load(yaml_text)
    except yaml.YAMLError as e:
        print(f"Error parsing YAML: {e}")
        sys.exit(1)

    models = config.get("models", {})

    print(f"Found {len(models)} models.")
    print("-" * 60)

    for model_name, model_config in models.items():
        cmd = model_config.get("cmd", "")
        if not cmd:
            print(f"Skipping {model_name}: No command found.")
            continue

        print(f"Processing model: {model_name}")
        dl_args = parse_args_from_cmd(cmd)

        if not dl_args:
            print("  Warning: No HuggingFace arguments found in command. Skipping.")
            continue

        # Construct llama-completion command
        # We use -p "check" -n 1 to just load the model and generate 1 token, ensuring it's downloaded.
        # We assume llama-completion is in the PATH.
        cli_cmd = (
            ["llama-completion"]
            + dl_args
            + [
                "-p",
                "System check",
                "-n",
                "1",
                "--no-display-prompt",
            ]
        )

        print(f"  Running: {' '.join(cli_cmd)}")

        try:
            # We allow it to fail if it's just a download check, but ideally it succeeds.
            # Using subprocess.call to show output to user so they see download progress.
            subprocess.run(cli_cmd, check=True, stdin=subprocess.DEVNULL)
            print("  -> Success/Verified.")
        except subprocess.CalledProcessError:
            print("  -> Failed (or maybe just interrupted).")
        except FileNotFoundError:
            print(
                "  -> Error: 'llama-completion' not found in PATH. Please run inside a 'nix-shell -p llama-cpp' or similar."
            )
            return

        print("-" * 60)


if __name__ == "__main__":
    main()
