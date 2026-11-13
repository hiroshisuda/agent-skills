#!/usr/bin/env bash
# SessionStart: stay silent when gh and gh stack are ready; otherwise tell Claude what's missing.
if ! command -v gh >/dev/null 2>&1; then
  echo "Note from the git plugin: the gh CLI is not installed, so the gh-stack skill can't run. If the user asks for PR work, tell them to install it (https://cli.github.com), run 'gh auth login', then 'gh extension install github/gh-stack'."
  exit 0
fi
missing=()
gh auth status >/dev/null 2>&1 || missing+=("gh is not authenticated (user should run 'gh auth login')")
gh extension list 2>/dev/null | grep -q 'gh-stack' || missing+=("the gh stack extension is not installed (install with 'gh extension install github/gh-stack', after asking)")
if [ ${#missing[@]} -gt 0 ]; then
  printf 'Note from the git plugin, relevant only if the user asks for PR work: %s.\n' "$(IFS=';'; echo "${missing[*]}" | sed 's/;/; /g')"
fi
exit 0
