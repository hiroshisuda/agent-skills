#!/usr/bin/env bash
# PreToolUse (Bash and GitHub MCP pull request tools), all sessions: block PR titles and
# squash-merge commit titles that aren't Conventional Commits subjects. Claude gets the reason
# through stderr (exit 2).
set -u

command -v jq >/dev/null 2>&1 || exit 0

# shellcheck source=pr-titles.sh
. "$(dirname "$0")/pr-titles.sh"

input=$(cat)
field() { printf '%s' "$input" | jq -r "$1 // empty"; }

tool=$(field .tool_name)
case "$tool" in
  Bash)
    command=$(field .tool_input.command)
    case "$command" in
      *gh*pr*) problems=$(pr_title_problems_in_command "$command") ;;
      *) exit 0 ;;
    esac
    ;;
  *__create_pull_request)
    problems=$(report_title_problem "$tool" "$(field .tool_input.title)")
    ;;
  *__update_pull_request)
    title=$(field .tool_input.title)
    [ -n "$title" ] || exit 0
    problems=$(report_title_problem "$tool" "$title")
    ;;
  *__merge_pull_request)
    title=$(field .tool_input.commit_title)
    [ "$(field .tool_input.merge_method)" = squash ] && [ -n "$title" ] || exit 0
    problems=$(report_title_problem "$tool commit_title" "$title")
    ;;
  *) exit 0 ;;
esac

[ -n "$problems" ] || exit 0
cat >&2 <<EOF
Blocked by the git plugin: PR titles, and commit titles given for a squash merge, must be
Conventional Commits subjects, as the commit-messages skill describes, because a squash merge turns
the title into the commit that release tooling reads. Use type(optional scope)!: subject, with
type one of ${PR_TITLE_TYPES//|/, }, a subject that starts lowercase with no trailing period,
and at most $PR_TITLE_MAX_LENGTH characters in all. Example: feat(export): add CSV export for reports
$problems
EOF
exit 2
