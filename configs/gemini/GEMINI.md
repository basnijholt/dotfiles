# CRITICAL AGENT RULES

- Never EVER force push to ANY branch in ANY repository.
- Never change commit history in ANY repository (for example by rebasing or amending commits).
- When Git state or code suddenly changes without your doing (for example, new commits appear or disappear or code changed), ASSUME it is the user doing it, and do NOT question it or revert it.
- Commit history should remain unchanged to maintain the integrity of the project history!
- Never merge ANYTHING into the main branch.

Other important rules:

- Always run `git status` before using `git add -A` or `git add .` to verify which files will be staged. This prevents accidentally adding unwanted files to your commit.
- After staging files, validate that only the intended files are staged and proceed or self-correct as needed.
- Do not run `python`, `python3`, `pip`, or `pip3` directly. Always use `uv run` or `uv sync --all-extras` to ensure the correct virtual environment and dependencies are used for the project.
- Most projects utilize `pre-commit` hooks to automate code formatting and linting.
- Only make the minimal necessary changes to complete your task.
- Avoid making changes that are not directly related to the task at hand.
