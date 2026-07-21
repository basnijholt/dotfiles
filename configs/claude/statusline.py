#!/usr/bin/env python3
from __future__ import annotations

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
    effort_level: str = ""


def parse_input(raw: dict) -> StatusInput:
    # Only pick the fields we use: the JSON schema gains new keys over time,
    # and strict **-unpacking into dataclasses breaks on every addition.
    ctx_data = raw.get("context_window", {})
    current_usage = None
    usage_data = ctx_data.get("current_usage")
    if usage_data:
        current_usage = CurrentUsage(
            input_tokens=usage_data.get("input_tokens", 0),
            output_tokens=usage_data.get("output_tokens", 0),
            cache_creation_input_tokens=usage_data.get(
                "cache_creation_input_tokens", 0
            ),
            cache_read_input_tokens=usage_data.get("cache_read_input_tokens", 0),
        )

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

    model_data = raw.get("model", {})
    workspace_data = raw.get("workspace", {})
    cost_data = raw.get("cost", {})
    cwd = raw.get("cwd", os.getcwd())

    return StatusInput(
        session_id=raw.get("session_id", ""),
        transcript_path=raw.get("transcript_path", ""),
        cwd=cwd,
        model=Model(
            id=model_data.get("id", ""),
            display_name=model_data.get("display_name", ""),
        ),
        workspace=Workspace(
            current_dir=workspace_data.get("current_dir", cwd),
            project_dir=workspace_data.get("project_dir", cwd),
        ),
        version=raw.get("version", ""),
        output_style=OutputStyle(name=raw.get("output_style", {}).get("name", "")),
        cost=Cost(
            total_cost_usd=cost_data.get("total_cost_usd", 0.0),
            total_duration_ms=cost_data.get("total_duration_ms", 0),
            total_api_duration_ms=cost_data.get("total_api_duration_ms", 0),
            total_lines_added=cost_data.get("total_lines_added", 0),
            total_lines_removed=cost_data.get("total_lines_removed", 0),
        ),
        exceeds_200k_tokens=raw.get("exceeds_200k_tokens", False),
        context_window=context_window,
        effort_level=(raw.get("effort") or {}).get("level", ""),
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
BLUE = "\033[34m"
RED = "\033[31m"
RESET = "\033[0m"

# Icons (Nerd Font)
ICON_GIT = "\uf1d3"
ICON_SERVER = "\uf233"
ICON_FOLDER = "\uf07b"
ICON_CHART = "\uf080"
ICON_COST = "\uf155"  # dollar sign
ICON_GOOGLE = "\uf1a0"
ICON_BRAIN = "\U000f09d1"  # nf-md-brain

# Model icon
if "fable" in data.model.id.lower():
    model_icon = f"{BLUE}{RESET}"  # book, fitting for Fable
elif "opus" in data.model.id.lower():
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

# Thinking effort level
EFFORT_COLORS = {
    "low": GREEN,
    "medium": CYAN,
    "high": YELLOW,
    "xhigh": MAGENTA,
    "max": RED,
}
effort_info = ""
if data.effort_level:
    color = EFFORT_COLORS.get(data.effort_level, YELLOW)
    effort_info = f"{color}{ICON_BRAIN} {data.effort_level}{RESET} "

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
if data.context_window:
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
        if tokens >= 1_000_000:
            tok_str = f"{tokens / 1_000_000:.2f}M"
        elif tokens >= 1_000:
            tok_str = f"{tokens / 1_000:.0f}k"
        else:
            tok_str = str(tokens)
        context_info = f" {MAGENTA}{ICON_CHART} {tok_str}{RESET}"

# Calculate cost
cost_info = ""
if data.cost.total_cost_usd > 0:
    cost_info = f" {YELLOW}{ICON_COST}{data.cost.total_cost_usd:.2f}{RESET}"

project_icon = ICON_GIT if is_git_repo else ICON_FOLDER
print(
    f"{model_info}{effort_info}{CYAN}{project_icon} {repo_name}{branch}{RESET}{folder_info} {GREEN}{os_icon} {hostname}{RESET}{context_info}{cost_info}"
)
