#!/usr/bin/env python3
import json
import subprocess
import sys
import os
from dataclasses import dataclass


@dataclass
class Model:
    id: str
    display_name: str


@dataclass
class Workspace:
    current_dir: str
    project_dir: str


@dataclass
class CurrentUsage:
    input_tokens: int = 0
    output_tokens: int = 0
    cache_creation_input_tokens: int = 0
    cache_read_input_tokens: int = 0


@dataclass
class ContextWindow:
    total_input_tokens: int = 0
    total_output_tokens: int = 0
    context_window_size: int = 0
    current_usage: CurrentUsage | None = None


@dataclass
class Cost:
    total_cost_usd: float
    total_duration_ms: int
    total_api_duration_ms: int
    total_lines_added: int
    total_lines_removed: int


@dataclass
class OutputStyle:
    name: str


@dataclass
class StatusInput:
    session_id: str
    transcript_path: str
    cwd: str
    model: Model
    workspace: Workspace
    version: str
    output_style: OutputStyle
    cost: Cost
    exceeds_200k_tokens: bool
    context_window: ContextWindow | None = None


def parse_input(raw: dict) -> StatusInput:
    ctx_data = raw.get("context_window", {})
    current_usage = None
    if ctx_data.get("current_usage"):
        current_usage = CurrentUsage(**ctx_data["current_usage"])

    context_window = (
        ContextWindow(
            total_input_tokens=ctx_data.get("total_input_tokens", 0),
            total_output_tokens=ctx_data.get("total_output_tokens", 0),
            context_window_size=ctx_data.get("context_window_size", 0),
            current_usage=current_usage,
        )
        if ctx_data
        else None
    )

    return StatusInput(
        session_id=raw["session_id"],
        transcript_path=raw["transcript_path"],
        cwd=raw["cwd"],
        model=Model(**raw["model"]),
        workspace=Workspace(**raw["workspace"]),
        version=raw["version"],
        output_style=OutputStyle(**raw["output_style"]),
        cost=Cost(**raw["cost"]),
        exceeds_200k_tokens=raw["exceeds_200k_tokens"],
        context_window=context_window,
    )


# Save input to temp file for debugging
raw = sys.stdin.read()
with open("/tmp/statusline_input.json", "w") as f:
    f.write(raw)
data = parse_input(json.loads(raw))

# Get git info
repo_name = os.path.basename(data.workspace.project_dir)
branch = ""
git_root = data.workspace.project_dir  # fallback
is_git_repo = False
try:
    result = subprocess.run(
        ["git", "-C", data.workspace.project_dir, "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        timeout=1,
    )
    if result.returncode == 0:
        is_git_repo = True
        git_root = result.stdout.strip()
        repo_name = os.path.basename(git_root)

    result = subprocess.run(
        ["git", "-C", data.workspace.project_dir, "branch", "--show-current"],
        capture_output=True,
        text=True,
        timeout=1,
    )
    if result.returncode == 0 and result.stdout.strip():
        branch = "@" + result.stdout.strip()
except Exception:
    pass

# Get hostname and OS icon
hostname = os.uname().nodename.split(".")[0]
if "macbook" in hostname.lower():
    hostname = "macbook"

# Detect OS
os_icon = ""
if sys.platform == "darwin":
    os_icon = "\uf179"  # Apple
elif sys.platform == "linux":
    try:
        with open("/etc/os-release") as f:
            os_release = f.read().lower()
        if "nixos" in os_release:
            os_icon = "\uf313"  # NixOS
        elif "debian" in os_release:
            os_icon = "\uf306"  # Debian
        else:
            os_icon = "\uf17c"  # Generic Linux
    except Exception:
        os_icon = "\uf17c"  # Generic Linux

# Get start folder (where Claude was started, relative to git root)
start_folder = ""
if data.workspace.project_dir != git_root:
    start_folder = os.path.relpath(data.workspace.project_dir, git_root)

# Colors
CYAN = "\033[36m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
MAGENTA = "\033[35m"
RESET = "\033[0m"

# Icons (Nerd Font)
ICON_GIT = "\uf1d3"
ICON_SERVER = "\uf233"
ICON_FOLDER = "\uf07b"
ICON_CHART = "\uf080"
ICON_COST = "\uf155"  # dollar sign
ICON_GOOGLE = "\uf1a0"

# Model icon
if "opus" in data.model.id.lower():
    model_icon = f"{MAGENTA}󰘨{RESET}"
elif "sonnet" in data.model.id.lower():
    model_icon = f"{CYAN}󰎈{RESET}"
elif "haiku" in data.model.id.lower():
    model_icon = f"{GREEN}󰯈{RESET}"
else:
    model_icon = ""

# Check if using Vertex AI (Google)
provider_info = ""
if os.environ.get("CLAUDE_CODE_USE_VERTEX"):
    provider_info = f"{YELLOW}{ICON_GOOGLE}{RESET}"

model_info = f"{model_icon} {provider_info} " if (model_icon and provider_info) else f"{model_icon or provider_info} " if (model_icon or provider_info) else ""

# Build folder info
# start_folder: where Claude was started (relative to git root)
# current_folder: where Claude cd'd to (relative to project_dir)
folder_parts = []
if start_folder:
    folder_parts.append(start_folder)
if data.workspace.current_dir != data.workspace.project_dir:
    current_folder = os.path.relpath(
        data.workspace.current_dir, data.workspace.project_dir
    )
    folder_parts.append(current_folder)

folder_info = ""
if folder_parts:
    folder_info = f" {YELLOW}{ICON_FOLDER} {' → '.join(folder_parts)}{RESET}"

# Calculate context usage
context_info = ""
if data.context_window and data.context_window.context_window_size > 0:
    ctx = data.context_window
    if ctx.current_usage:
        tokens = (
            ctx.current_usage.input_tokens
            + ctx.current_usage.cache_creation_input_tokens
            + ctx.current_usage.cache_read_input_tokens
        )
    else:
        tokens = ctx.total_input_tokens + ctx.total_output_tokens

    if tokens > 0:
        pct = tokens * 100 // ctx.context_window_size
        context_info = f" {MAGENTA}{ICON_CHART} {pct}%{RESET}"

# Calculate cost
cost_info = ""
if data.cost.total_cost_usd > 0:
    cost_info = f" {YELLOW}{ICON_COST}{data.cost.total_cost_usd:.2f}{RESET}"

project_icon = ICON_GIT if is_git_repo else ICON_FOLDER
print(
    f"{model_info}{CYAN}{project_icon} {repo_name}{branch}{RESET}{folder_info} {GREEN}{os_icon} {hostname}{RESET}{context_info}{cost_info}"
)
