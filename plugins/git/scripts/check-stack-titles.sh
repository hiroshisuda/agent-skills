#!/usr/bin/env bash
# PostToolUse (Bash), all sessions: after gh stack submit --auto opens PRs with generated titles,
# check each open PR's title and send Claude the ones to fix (exit 2). When gh can't read the
# stack, ask Claude to check every title itself.
set -u

command -v jq >/dev/null 2>&1 || exit 0

# shellcheck source=pr-titles.sh
. "$(dirname "$0")/pr-titles.sh"

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
case "$command" in
  *stack*submit*) is_stack_auto_submit "$command" || exit 0 ;;
  *) exit 0 ;;
esac
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
cd "${cwd:-.}" 2>/dev/null || true

rules="PR titles must be Conventional Commits subjects, as the commit-messages skill describes, \
because a squash merge turns the title into the commit that release tooling reads"

# Print "<number><TAB><title>" for each open PR in the stack, or fail when gh can't.
stack_pr_titles() {
  local stack numbers number title
  stack=$(gh stack view --json 2>/dev/null) || return 1
  numbers=$(jq -r '.branches[] | select(.pr.state == "OPEN") | .pr.number' <<<"$stack") || return 1
  for number in $numbers; do
    title=$(gh pr view "$number" --json title -q .title 2>/dev/null) || return 1
    printf '%s\t%s\n' "$number" "$title"
  done
}

if ! titles=$(command -v gh >/dev/null 2>&1 && stack_pr_titles); then
  echo "Note from the git plugin: gh stack submit --auto opened PRs with generated titles, and the plugin couldn't read them. $rules. Check the title of every PR in the stack, and retitle each one that isn't a Conventional Commits subject (with gh pr edit <number> --title or the GitHub MCP update_pull_request tool)." >&2
  exit 2
fi

problems=$(while IFS=$'\t' read -r number title; do
  [ -z "$number" ] || report_title_problem "PR #$number" "$title"
done <<<"$titles")

[ -n "$problems" ] || exit 0
cat >&2 <<MSG
Note from the git plugin: gh stack submit --auto opened PRs with generated titles. $rules.
Retitle each of these with gh pr edit <number> --title "<type>(<scope>): <subject>":
$problems
MSG
exit 2
