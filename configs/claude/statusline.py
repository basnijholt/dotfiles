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


data = parse_input(json.load(sys.stdin))

# Get repo name and branch
repo_name = os.path.basename(data.workspace.project_dir)
branch = ""
try:
    result = subprocess.run(
        ["git", "-C", data.workspace.project_dir, "remote", "get-url", "origin"],
        capture_output=True,
        text=True,
        timeout=1,
    )
    if result.returncode == 0:
        repo_name = result.stdout.strip().split("/")[-1].removesuffix(".git")

    result = subprocess.run(
        ["git", "-C", data.workspace.project_dir, "branch", "--show-current"],
        capture_output=True,
        text=True,
        timeout=1,
    )
    if result.returncode == 0 and result.stdout.strip():
        branch = "@" + result.stdout.strip()
except:
    pass

# Get hostname
hostname = os.uname().nodename.split(".")[0]

# Get folder name
folder = os.path.basename(data.workspace.project_dir)

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
    cost_info = f" {GREEN}{ICON_COST}{data.cost.total_cost_usd:.2f}{RESET}"

print(
    f"{CYAN}{ICON_GIT} {repo_name}{branch}{RESET} {GREEN}{ICON_SERVER} {hostname}{RESET} {YELLOW}{ICON_FOLDER} {folder}{RESET}{context_info}{cost_info}"
)
