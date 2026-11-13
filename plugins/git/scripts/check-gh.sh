#!/usr/bin/env bash
# SessionStart: stay silent when gh is ready; otherwise tell Claude what's missing.
if ! command -v gh >/dev/null 2>&1; then
  echo "Note from the git plugin: the gh CLI is not installed, so the stacked-prs skill can't create PRs. If the user asks for PR work, tell them to install it (https://cli.github.com) and run 'gh auth login'."
elif ! gh auth status >/dev/null 2>&1; then
  echo "Note from the git plugin: the gh CLI is installed but not authenticated. If the user asks for PR work, tell them to run 'gh auth login'."
fi
exit 0
