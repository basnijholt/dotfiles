#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "pydantic-ai-slim[openai]",
#   "rich",
#   "pydantic",
#   "pyperclip",
# ]
# ///
"""
Generates a commit message based on staged Git changes using an AI model.
"""

import argparse
import os
import subprocess
import sys
import tempfile
import time
import textwrap

import pyperclip
from pydantic import BaseModel, Field
from pydantic_ai import Agent
from pydantic_ai.models.openai import OpenAIModel
from pydantic_ai.providers.openai import OpenAIProvider
from rich.console import Console
from rich.panel import Panel
from rich.status import Status

# --- Configuration ---
MY_OLLAMA_HOST = os.getenv("MY_OLLAMA_HOST", "http://localhost:11434")
DEFAULT_MODEL = "gpt-oss:20b"

# The agent's core identity and immutable rules.
SYSTEM_PROMPT = """\
You are an expert at writing conventional commit messages from git diffs.
Your task is to analyze a git diff and generate a concise and informative commit message that follows the conventional commit specification.

**How to Read the Diff:**
The input you receive is a standard git diff. Pay close attention to the prefixes on each line:
- `+`: This line was added.
- `-`: This line was removed.
- A space ` `: This line is unchanged context. It's there to help you understand where the changes happened.

**Your Goal:**
- Your generated commit message must ONLY describe the changes indicated by the `+` and `-` lines. **Do not describe the unchanged context lines.**
- Focus on the main purpose of the changes. For example, if a new function is added, describe its purpose, but avoid mentioning trivial supporting changes like adding a necessary import statement.

**Commit Message Format:**
The message should have a subject line and an optional body.

- The subject line should be in the format: `type(scope): description`.
  - `type` must be one of: feat, fix, docs, style, refactor, perf, test, build, ci, chore.
  - `scope` is optional and indicates the part of the codebase affected.
  - `description` is a short summary of the code changes.

- The body should provide more context, explaining the 'what' and 'why' of the changes.
  - For very small or self-explanatory changes (e.g., fixing a typo, formatting), the body is optional and can be omitted. A clear subject line is sufficient.

**Output Rules:**
- Do not include any introductory phrases like "Here is the commit message:".
- Do not wrap the output in markdown or code blocks.
"""

# The specific task for the current run.
AGENT_INSTRUCTIONS = """\
Analyze the following git diff and generate a structured conventional commit message.
"""


# --- Data Models ---
class ConventionalCommit(BaseModel):
    """A structured conventional commit message."""

    commit_type: str = Field(
        ...,
        description="The type of the commit. Must be one of: feat, fix, docs, style, refactor, perf, test, build, ci, chore.",
    )
    scope: str | None = Field(
        default=None,
        description="Optional. The scope of the changes (e.g., a file, component, or feature name).",
    )
    subject: str = Field(
        ...,
        description="A short, imperative-tense description of the changes, under 72 characters.",
    )
    body: str | None = Field(
        default=None,
        description="Optional. A more detailed explanation of the changes, including motivation and context. Use markdown newlines for paragraphs.",
    )

    def to_message(self) -> str:
        """
        Formats the structured data into a conventional commit message string.
        The body is automatically formatted to have one sentence per line,
        while preserving original line breaks for lists.
        """
        scope_str = f"({self.scope})" if self.scope else ""
        header = f"{self.commit_type}{scope_str}: {self.subject}"

        if not self.body:
            return header

        # Process each line to split sentences, preserving original line breaks.
        lines = self.body.strip().split("\n")
        processed_lines = [line.replace(". ", ".\n") for line in lines]
        formatted_body = "\n".join(processed_lines)

        return f"{header}\n\n{formatted_body}"


# --- Main Application Logic ---


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments and return the parsed namespace."""
    parser = argparse.ArgumentParser(
        description="Generate and manage AI-powered git commit messages."
    )
    parser.add_argument(
        "--model",
        "-m",
        default=DEFAULT_MODEL,
        help=f"The Ollama model to use. Default is {DEFAULT_MODEL}.",
    )
    parser.add_argument(
        "-a",
        "--all",
        action="store_true",
        help="Automatically stage all modified and deleted files (like `git commit -a`).",
    )
    parser.add_argument(
        "-p",
        "--prompt",
        default=None,
        help="Add a custom one-time instruction to the AI model.",
    )
    parser.add_argument(
        "--repo-path",
        default=None,
        help="Path to the git repository. Defaults to the current working directory.",
    )

    action_group = parser.add_mutually_exclusive_group()
    action_group.add_argument(
        "--execute",
        "-x",
        action="store_true",
        help="Automatically execute git commit with the generated message.",
    )
    action_group.add_argument(
        "--copy",
        "-c",
        action="store_true",
        help="Copy the generated commit message to the clipboard.",
    )
    action_group.add_argument(
        "--edit",
        action="store_true",
        help="Open the generated message in your default editor for review before committing.",
    )

    return parser.parse_args()


def get_diff(console: Console, repo_path: str | None, all_changes: bool) -> str | None:
    """
    Retrieves the git diff.

    If `all_changes` is True, it gets the diff of all tracked files (like `git diff`).
    Otherwise, it retrieves the diff of staged changes only (like `git diff --staged`).
    """
    try:
        # The --patch-with-raw option is used to handle binary files
        command = ["git", "diff"]
        if not all_changes:
            command.append("--staged")

        # Ignore dirty submodules so unstaged changes within them don't pollute the diff.
        command.extend(["--ignore-submodules=dirty", "--patch-with-raw"])
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True,
            encoding="utf-8",
            cwd=repo_path,
        )
        return result.stdout
    except FileNotFoundError:
        console.print(
            "[bold red]Error: 'git' command not found. Is Git installed and in your PATH?[/bold red]"
        )
        return None
    except subprocess.CalledProcessError as e:
        # This can happen for various reasons, e.g., not a git repository
        error_message = e.stderr.strip()
        console.print(f"[bold red]Error getting git diff:[/bold red]\n{error_message}")
        return None


def build_agent(model: str, custom_prompt: str | None = None) -> Agent:
    """Construct and return a PydanticAI agent configured for local Ollama."""
    agent_instructions = AGENT_INSTRUCTIONS
    if custom_prompt:
        agent_instructions += (
            f"\n\nIMPORTANT: You must also follow this instruction: {custom_prompt}"
        )

    ollama_provider = OpenAIProvider(base_url=f"{MY_OLLAMA_HOST}/v1")
    ollama_model = OpenAIModel(
        model_name=model,
        provider=ollama_provider,
    )
    return Agent(
        model=ollama_model,
        system_prompt=SYSTEM_PROMPT,
        instructions=agent_instructions,
        output_type=ConventionalCommit,
        retries=3,
        output_retries=3,
    )


def generate_commit_message(
    agent: Agent, diff: str
) -> tuple[ConventionalCommit, float]:
    """Run the agent synchronously and return the commit message and elapsed time."""
    t_start = time.monotonic()
    result = agent.run_sync(diff)
    t_end = time.monotonic()
    return result.output, t_end - t_start


def main() -> None:
    """Orchestrate argument parsing, diff retrieval, and message generation."""
    args = parse_args()
    console = Console()

    diff = get_diff(console, args.repo_path, args.all)

    if diff is None:
        sys.exit(1)

    if not diff.strip():
        if args.all:
            console.print(
                "[yellow]No tracked changes found. Nothing to commit.[/yellow]"
            )
        else:
            console.print(
                "[yellow]No staged changes found. Nothing to commit.[/yellow]"
            )
        sys.exit(0)

    agent = build_agent(args.model, args.prompt)

    try:
        if args.prompt:
            console.print(
                f"🕵️  [bold yellow]Custom instruction added:[/bold yellow] [italic]'{args.prompt}'[/italic]"
            )

        with Status(
            f"[bold yellow]🤖 Analyzing diff with {args.model}...[/bold yellow]",
            console=console,
        ):
            commit_obj, elapsed = generate_commit_message(agent, diff)

        commit_message = commit_obj.to_message()

        console.print(
            Panel(
                commit_message,
                title="[bold green]🚀 Generated Commit Message[/bold green]",
                border_style="green",
                padding=(1, 2),
                subtitle=f"[dim]took {elapsed:.2f}s[/dim]",
            )
        )

        if args.execute:
            console.print("\n[bold yellow]Executing git commit...[/bold yellow]")
            try:
                commit_command = ["git", "commit"]
                if args.all:
                    commit_command.append("-a")
                commit_command.extend(["-F", "-"])
                subprocess.run(
                    commit_command,
                    input=commit_message,
                    text=True,
                    check=True,
                    capture_output=True,  # Capture output to check for commit success
                    cwd=args.repo_path,
                )
                console.print("[bold green]✅ Commit successful![/bold green]")
            except subprocess.CalledProcessError as e:
                console.print(f"[bold red]❌ Git commit failed:[/bold red]\n{e.stderr}")
            except FileNotFoundError:
                console.print("[bold red]❌ Error: 'git' command not found.[/bold red]")

        elif args.copy:
            try:
                pyperclip.copy(commit_message)
                console.print(
                    "\n[bold green]✅ Commit message copied to clipboard.[/bold green]"
                )
                console.print(
                    "💡 [bold]Run `git commit -F -` and paste the message to commit.[/bold]"
                )
            except pyperclip.PyperclipException:
                console.print(
                    "[bold red]❌ Could not copy to clipboard. Is a tool like xclip or pbcopy installed?[/bold red]"
                )

        elif args.edit:
            console.print("\n[bold yellow]Opening editor for review...[/bold yellow]")
            tmp_file_path = None
            try:
                # Create a temporary file to hold the commit message.
                # We use delete=False so we can pass the file path to git, then clean up manually.
                with tempfile.NamedTemporaryFile(
                    mode="w", delete=False, suffix=".txt", encoding="utf-8"
                ) as tmp_file:
                    tmp_file.write(commit_message)
                    tmp_file_path = tmp_file.name

                commit_command = ["git", "commit", "--edit", "--verbose"]
                if args.all:
                    commit_command.append("-a")
                commit_command.append(f"--file={tmp_file_path}")
                # We don't check=True because the user might abort the commit, which is not an error.
                # This command tells git to open the editor with the content of our temp file.
                # Because we don't pipe stdin, the editor can correctly attach to the terminal.
                result = subprocess.run(
                    commit_command,
                    check=False,
                    cwd=args.repo_path,
                )
                if result.returncode == 0:
                    console.print("[bold green]✅ Commit successful![/bold green]")
                else:
                    console.print(
                        "[bold yellow]ℹ️ Commit aborted by user.[/bold yellow]"
                    )
            except FileNotFoundError:
                console.print("[bold red]❌ Error: 'git' command not found.[/bold red]")
            except Exception as e:
                console.print(
                    f"[bold red]❌ An error occurred during the edit process: {e}[/bold red]"
                )
            finally:
                if tmp_file_path and os.path.exists(tmp_file_path):
                    os.remove(tmp_file_path)

        else:  # Default "dry-run" behavior
            console.print(
                "\n💡 [bold]To commit, run the command below or use `--edit` to review in your editor.[/bold]"
            )
            console.print("\n[bold]Command:[/bold]")
            git_prefix = f"git -C '{args.repo_path}'" if args.repo_path else "git"
            commit_verb = "commit -a" if args.all else "commit"
            console.print(
                textwrap.dedent(
                    f"""
                    cat <<'EOM' | {git_prefix} {commit_verb} -F -
                    {commit_message}
                    EOM
                    """
                )
            )

    except Exception as e:
        console.print(f"❌ [bold red]An unexpected error occurred: {e}[/bold red]")
        console.print(
            f"   Please check that your Ollama server is running at [bold cyan]{MY_OLLAMA_HOST}[/bold cyan]"
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
