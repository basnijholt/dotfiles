#!/usr/bin/env bash
# Merge a GitHub PR with a LOCAL signed merge commit, then push main.
#
# Why not the web merge button: comin verifies SSH signatures on the main
# tip against my key, and GitHub's web merges are GPG-signed by GitHub's
# web-flow key instead. Every web merge therefore freezes fleet deploys
# until a signed commit lands on main. This script is the paved road.
#
# Usage: merge-pr.sh <pr-number>
set -euo pipefail

pr="${1:?usage: merge-pr.sh <pr-number>}"

state="$(gh pr view "$pr" --json state -q .state)"
if [ "$state" != "OPEN" ]; then
  echo "PR #$pr is $state, not OPEN" >&2
  exit 1
fi

branch="$(gh pr view "$pr" --json headRefName -q .headRefName)"
title="$(gh pr view "$pr" --json title -q .title)"

git fetch origin main "$branch"
git switch main
git merge --ff-only origin/main
git merge --no-ff -S -m "$title (#$pr)" "origin/$branch"
git push origin main

echo "Merged and pushed. comin fetches within ~1 min; verify with:"
echo "  comin status   # Fetcher should show the new tip, signed"
