#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "pydantic-ai-slim[openai]",
#   "rich",
# ]
# ///
"""Auto-name Zellij tabs based on terminal context using a local AI model.

Usage:
    zellij-rename-tab.py              # Rename current tab
    zellij-rename-tab.py --all        # Rename all tabs (single AI query)
    zellij-rename-tab.py --all --debug  # Show full prompt and response

Environment variables:
    ZELLIJ_NAMER_BASE_URL: API base URL. Default: http://pc.local:9292/v1
    ZELLIJ_NAMER_MODEL: Model name. Default: gpt-oss-low:20b
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

from pydantic_ai import Agent, ModelRetry, RunContext
from pydantic_ai.models.openai import OpenAIChatModel
from pydantic_ai.providers.openai import OpenAIProvider
from rich.console import Console
from rich.panel import Panel
from rich.syntax import Syntax
from rich.text import Text

console = Console()
DEBUG = False
SESSION: str | None = None  # Target session name

# --- Configuration ---
BASE_URL = os.getenv("ZELLIJ_NAMER_BASE_URL", "http://pc.local:9292/v1")
MODEL = os.getenv("ZELLIJ_NAMER_MODEL", "gpt-oss-low:20b")

SYSTEM_PROMPT = """\
You generate very short tmux window names (1-2 words, preferably <10 chars).
Output ONLY the window names as a JSON list of strings, nothing else.
Use lowercase with hyphens. Brevity is key - save horizontal space.
"""

SINGLE_TAB_INSTRUCTIONS = """\
Generate a short tmux window name (<10 chars preferred) based on the terminal screen content.
Focus on: project name, directory, or task. Keep it brief!
For TUI apps (htop, btop, vim, nvim, etc), use the app name itself.
Examples: dotfiles, docker, ssh-nuc, git, npm, pipefunc, htop, nvim
"""

MULTI_TAB_INSTRUCTIONS = """\
Generate VERY short tmux window names. STRICT LIMIT: <10 chars each!
Return a JSON list with exactly one name per window, in order.

RULES:
- Max 10 characters per name - shorter is better!
- TUI apps (htop, btop, vim, nvim, k9s, etc): use the app name itself
- SSH sessions: use "<host>-<dir>" format (e.g., "nuc-home", "nuc-code")
  - Detect via "🌐 <host>" in prompt or "ssh <host>" command
  - IMPORTANT: The REMOTE prompt shows the remote cwd, not the local one!
  - Look for the prompt AFTER the ssh command to see actual remote directory
- Local: use directory basename only (e.g., "dotfiles" not "dotfiles-scripts")
- Always use the MOST RECENT prompt line to determine current state

Examples: ["dotfiles", "pipefunc", "nuc-home", "htop"]
"""


@dataclass
class TabContext:
    """Context for tab naming - holds expected number of tabs."""

    num_tabs: int


def zellij_action(*args: str) -> str:
    """Run a zellij action command and return output."""
    try:
        cmd = ["zellij"]
        if SESSION:
            cmd.extend(["-s", SESSION])
        cmd.extend(["action", *args])
        result = subprocess.run(
            cmd,
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
        return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""


def get_active_sessions() -> list[str]:
    """Get list of active (non-exited) Zellij sessions."""
    try:
        result = subprocess.run(
            ["zellij", "list-sessions"],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
        sessions = []
        for line in result.stdout.strip().split("\n"):
            if line and "EXITED" not in line:
                # Session name is the first word, strip ANSI codes
                name = line.split()[0]
                name = re.sub(r"\x1b\[[0-9;]*m", "", name)
                sessions.append(name)
        return sessions
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []


def dump_screen() -> str:
    """Dump current pane screen content."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
        temp_path = f.name

    try:
        zellij_action("dump-screen", temp_path)
        content = Path(temp_path).read_text()
        lines = content.strip().split("\n")[-30:]
        return "\n".join(lines)
    except Exception:
        return ""
    finally:
        Path(temp_path).unlink(missing_ok=True)


def query_tab_count() -> int:
    """Get the number of tabs."""
    output = zellij_action("query-tab-names")
    if not output:
        return 0
    return len(output.strip().split("\n"))


def build_single_agent() -> Agent[None, str]:
    """Build agent for single tab naming."""
    provider = OpenAIProvider(base_url=BASE_URL)
    model = OpenAIChatModel(model_name=MODEL, provider=provider)
    return Agent(
        model=model,
        system_prompt=SYSTEM_PROMPT,
        instructions=SINGLE_TAB_INSTRUCTIONS,
        output_type=str,
    )


def build_multi_agent() -> Agent[TabContext, list[str]]:
    """Build agent for multi-tab naming with validation."""
    provider = OpenAIProvider(base_url=BASE_URL)
    model = OpenAIChatModel(model_name=MODEL, provider=provider)

    agent: Agent[TabContext, list[str]] = Agent(
        model=model,
        system_prompt=SYSTEM_PROMPT,
        instructions=MULTI_TAB_INSTRUCTIONS,
        output_type=list[str],
        deps_type=TabContext,
    )

    @agent.output_validator
    def validate_tab_count(
        ctx: RunContext[TabContext],
        output: list[str],
    ) -> list[str]:
        expected = ctx.deps.num_tabs
        if len(output) != expected:
            raise ModelRetry(
                f"Expected exactly {expected} tab names, got {len(output)}. "
                f"Please return exactly {expected} names, one per tab.",
            )
        # Clean up names
        return [
            name.strip().strip("\"'").lower().replace(" ", "-")[:20] for name in output
        ]

    return agent


def rename_current_tab() -> str:
    """Rename the current tab and return the new name."""
    screen = dump_screen()
    if not screen.strip():
        name = "shell"
    else:
        prompt = f"Terminal screen content:\n{screen}"
        if DEBUG:
            console.print(
                Panel(
                    Text(prompt),
                    title="[bold cyan]Prompt[/bold cyan]",
                    border_style="cyan",
                ),
            )
        agent = build_single_agent()
        try:
            result = agent.run_sync(prompt)
            name = result.output.strip().strip("\"'").lower().replace(" ", "-")[:20]
            name = name if name else "shell"
            if DEBUG:
                console.print(
                    Panel(
                        Text(name),
                        title="[bold green]Response[/bold green]",
                        border_style="green",
                    ),
                )
                console.print(f"[dim]Usage: {result.usage()}[/dim]")
        except Exception:
            name = "shell"

    zellij_action("rename-tab", name)
    return name


def rename_all_tabs() -> None:
    """Rename all tabs with a single AI query."""
    # Print marker to find original tab
    marker = f"__ZELLIJ_NAMER_{os.getpid()}__"
    print(marker)

    num_tabs = query_tab_count()
    if num_tabs == 0:
        print("Error: Could not query tabs", file=sys.stderr)
        sys.exit(1)

    print(f"Collecting context from {num_tabs} tabs...")

    # Find original tab and collect all screen contents
    original_tab = 1
    screens: list[str] = []

    for i in range(1, num_tabs + 1):
        zellij_action("go-to-tab", str(i))
        time.sleep(0.05)  # Brief pause for screen to update
        screen = dump_screen()
        screens.append(screen)

        if marker in screen:
            original_tab = i

    # Return to original tab immediately (don't wait at last tab during AI call)
    zellij_action("go-to-tab", str(original_tab))

    # Build prompt with all tab contents
    prompt_parts = []
    for i, screen in enumerate(screens, 1):
        prompt_parts.append(f"=== WINDOW {i} ===\n{screen}\n")

    full_prompt = (
        f"Generate exactly {num_tabs} window names for these {num_tabs} tmux windows:\n\n"
        + "\n".join(prompt_parts)
    )

    if DEBUG:
        console.print(
            Panel(
                Text(full_prompt),  # Escape markup characters
                title="[bold cyan]Prompt[/bold cyan]",
                border_style="cyan",
            ),
        )

    print("Generating names with AI (single query)...")

    # Single AI query for all tabs
    agent = build_multi_agent()
    try:
        result = agent.run_sync(full_prompt, deps=TabContext(num_tabs=num_tabs))
        names = result.output

        if DEBUG:
            console.print(
                Panel(
                    Syntax(json.dumps(names, indent=2), "json", theme="monokai"),
                    title="[bold green]Response[/bold green]",
                    border_style="green",
                ),
            )
            console.print(f"[dim]Usage: {result.usage()}[/dim]")
    except Exception as e:
        print(f"AI failed: {e}, using fallback names", file=sys.stderr)
        names = [f"tab-{i}" for i in range(1, num_tabs + 1)]

    # Apply names to tabs (no sleep needed - just renaming)
    print("Applying names...")
    for i, name in enumerate(names, 1):
        zellij_action("go-to-tab", str(i))
        zellij_action("rename-tab", name)
        print(f"  Tab {i}: {name}")

    # Return to original tab
    zellij_action("go-to-tab", str(original_tab))
    print(f"Done! (returned to tab {original_tab})")


def main() -> None:
    """Main entry point."""
    global DEBUG, SESSION

    parser = argparse.ArgumentParser(description="Auto-name Zellij tabs")
    parser.add_argument(
        "--all",
        "-a",
        action="store_true",
        help="Rename all tabs (single AI query)",
    )
    parser.add_argument(
        "--debug",
        "-d",
        action="store_true",
        help="Print full prompt and response",
    )
    parser.add_argument(
        "--session",
        "-s",
        help="Target session name (auto-detects if only one active)",
    )
    args = parser.parse_args()

    DEBUG = args.debug

    # Determine target session
    if args.session:
        SESSION = args.session
    elif not os.environ.get("ZELLIJ"):
        # Not inside Zellij - try to find active session
        active = get_active_sessions()
        if len(active) == 0:
            print("Error: No active Zellij sessions found", file=sys.stderr)
            sys.exit(1)
        elif len(active) == 1:
            SESSION = active[0]
            console.print(f"[dim]Using session: {SESSION}[/dim]")
        else:
            print(
                f"Error: Multiple active sessions: {', '.join(active)}",
                file=sys.stderr,
            )
            print("Use --session to specify which one", file=sys.stderr)
            sys.exit(1)

    if args.all:
        rename_all_tabs()
    else:
        name = rename_current_tab()
        print(f"Tab renamed to: {name}")


if __name__ == "__main__":
    main()
