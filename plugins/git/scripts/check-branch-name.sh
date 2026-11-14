#!/usr/bin/env bash
# PreToolUse (Bash), cloud sessions only: block git commands that create or push a branch whose
# name breaks the branching skill's convention. Claude gets the reason through stderr (exit 2).
set -u

[ "${CLAUDE_CODE_REMOTE:-}" = true ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# shellcheck source=branch-names.sh
. "$(dirname "$0")/branch-names.sh"

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
case "$command" in
  *git*) ;;
  *) exit 0 ;;
esac

# Expand HEAD and @all into the local branch names they stand for.
resolve() { # dir, name
  case "$2" in
    HEAD) git -C "$1" symbolic-ref --short -q HEAD 2>/dev/null ;;
    @all) git -C "$1" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null ;;
    *) printf '%s\n' "$2" ;;
  esac
}

problems=""
while IFS=$'\t' read -r dir name; do
  while IFS= read -r branch; do
    [ -n "$branch" ] || continue
    problem=$(branch_name_problem "$branch")
    [ -n "$problem" ] && problems="${problems}- '$branch': $problem
"
  done < <(resolve "$dir" "$name")
done < <(branches_in_command "$command" "${cwd:-$PWD}")

[ -n "$problems" ] || exit 0
cat >&2 <<EOF
Blocked by the git plugin: in cloud sessions, branches must be named for the feature or change
they implement, as the branching skill describes: lowercase kebab-case such as csv-export or
fix-empty-input-crash, optionally prefixed with a ticket such as proj-218-csv-export, with no
personal names or dates. This applies to the branch the session assigned too.
${problems}Pick a convention-following name and use it instead: for a branch you haven't pushed,
rename it with git branch -m <new-name>, then push that branch.
EOF
exit 2
