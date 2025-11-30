#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "PyYAML",
# ]
# ///
import os
import re
import yaml
import shlex
import subprocess
import sys

# Path to the ai.nix file
AI_NIX_PATH = os.path.join(os.path.dirname(__file__), "../hosts/pc/ai.nix")
CONFIG_YAML_PATH = "/etc/llama-swap/config.yaml"


def extract_yaml_from_nix(file_path):
    with open(file_path, "r") as f:
        content = f.read()

    # Regex to find the content between environment.etc."llama-swap/config.yaml".text = '' and '';
    match = re.search(
        r'environment\.etc\."llama-swap/config\.yaml"\.text\s*=\s*\'\'(.*?)\'\';',
        content,
        re.DOTALL,
    )
    if not match:
        print("Error: Could not find config.yaml content in ai.nix")
        sys.exit(1)

    yaml_content = match.group(1)

    # Sanitize Nix interpolation for YAML parsing
    # Replace ${pkgs.llama-cpp} with a placeholder or simple string
    yaml_content = re.sub(r"\$\{pkgs\.llama-cpp\}", "pkgs.llama-cpp", yaml_content)
    # Replace ${PORT} with a placeholder
    yaml_content = re.sub(r"\$\{PORT\}", "8080", yaml_content)

    return yaml_content


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
    yaml_text = ""
    if os.path.exists(CONFIG_YAML_PATH):
        print(f"Reading configuration from {CONFIG_YAML_PATH}...")
        with open(CONFIG_YAML_PATH, "r") as f:
            yaml_text = f.read()
    elif os.path.exists(AI_NIX_PATH):
        print(
            f"Warning: {CONFIG_YAML_PATH} not found. Falling back to {AI_NIX_PATH}..."
        )
        yaml_text = extract_yaml_from_nix(AI_NIX_PATH)
    else:
        print(f"Error: Neither {CONFIG_YAML_PATH} nor {AI_NIX_PATH} found.")
        sys.exit(1)

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

        # Construct llama-cli command
        # We use -p "check" -n 1 to just load the model and generate 1 token, ensuring it's downloaded.
        # We assume llama-cli is in the PATH.
        cli_cmd = (
            ["llama-cli"]
            + dl_args
            + ["-p", "System check", "-n", "1", "--no-display-prompt"]
        )

        print(f"  Running: {' '.join(cli_cmd)}")

        try:
            # We allow it to fail if it's just a download check, but ideally it succeeds.
            # Using subprocess.call to show output to user so they see download progress.
            subprocess.run(cli_cmd, check=True)
            print("  -> Success/Verified.")
        except subprocess.CalledProcessError:
            print("  -> Failed (or maybe just interrupted).")
        except FileNotFoundError:
            print(
                "  -> Error: 'llama-cli' not found in PATH. Please run inside a 'nix-shell -p llama-cpp' or similar."
            )
            return

        print("-" * 60)


if __name__ == "__main__":
    main()
