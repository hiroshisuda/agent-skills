#!/usr/bin/env bash
# Tests for the PR-title check. Run all tests with plugins/git/tests/run.sh.
set -u
here=$(cd "$(dirname "$0")" && pwd)
scripts="$here/../scripts"
# shellcheck source=lib.sh
. "$here/lib.sh"
# shellcheck source=../scripts/pr-titles.sh
. "$scripts/pr-titles.sh"

# Titles
for title in 'feat: add csv export' 'fix(parser): handle empty input' 'feat(api)!: drop v1 endpoints' \
  'refactor!: rename config keys' 'docs(git/branching): describe the hook' 'chore: bump ruff to 0.8'; do
  check "accepts $title" "" "$(pr_title_problem "$title")"
done
rejects() { # description, title, expected text in the problem
  local problem
  problem=$(pr_title_problem "$2")
  check "$1" 1 "$([[ $problem == *"$3"* ]] && echo 1)"
}
rejects "no type" 'Add CSV export' "doesn't match"
rejects "unknown type" 'feature: add csv export' "doesn't match"
rejects "capital type" 'Feat: add csv export' "doesn't match"
rejects "no space" 'feat:add csv export' "doesn't match"
rejects "empty subject" 'feat: ' "doesn't match"
rejects "empty scope" 'feat(): add csv export' "doesn't match"
rejects "capital subject" 'feat: Add csv export' "capital letter"
rejects "trailing period" 'feat: add csv export.' "period"
rejects "too long" "feat: $(printf 'a%.0s' {1..70})" "over the limit of 72"
rejects "shell expansion" 'feat: $TITLE' "built by the shell"
rejects "empty" '' "doesn't match"
check "reports every reason" "the subject starts with a capital letter; it ends with a period" \
  "$(pr_title_problem 'fix: Typo.')"

# gh commands
blocked() { # description, command
  check "$1 is blocked" 1 "$([ -n "$(pr_title_problems_in_command "$2")" ] && echo 1)"
}
allowed() { # description, command
  check "$1 is allowed" "" "$(pr_title_problems_in_command "$2")"
}
allowed "good create" 'gh pr create --title "feat(git): check pr titles" --body "Why."'
allowed "good create short flag" "gh pr create -t 'fix: handle empty input' -b x"
allowed "good create equals" "gh pr create --title='feat: add x' --body y"
blocked "bad create" 'gh pr create --title "Check PR titles" --body x'
blocked "create without title" 'gh pr create --fill'
allowed "good edit" 'gh pr edit 12 --title "fix: handle empty input"'
blocked "bad edit" 'gh pr edit 12 -t "Handle empty input"'
allowed "edit without title" 'gh pr edit 12 --add-label bug'
allowed "good squash subject" 'gh pr merge 12 --squash --subject "feat: add x (#12)"'
blocked "bad squash subject" 'gh pr merge 12 -s -t "Add x"'
allowed "merge commit subject" 'gh pr merge 12 --merge --subject "Merge x"'
allowed "squash without subject" 'gh pr merge 12 --squash'
blocked "chained" 'git push -u origin x && gh pr create --title "WIP" --body y'
allowed "other gh" 'gh pr view 12 --json title'
allowed "not gh" 'echo gh pr create --title Bad'
blocked "multiline title" $'gh pr create --title "feat: a\nb" --body y'

# The hook end to end
run_hook() { # tool input JSON with tool_name and tool_input
  printf '%s' "$1" | "$scripts/check-pr-title.sh" >/dev/null 2>&1
  echo $?
}
bash_input() { jq -n --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}'; }
check "hook blocks bad gh title" 2 "$(run_hook "$(bash_input 'gh pr create --title "Add x" --body y')")"
check "hook allows good gh title" 0 "$(run_hook "$(bash_input 'gh pr create --title "feat: add x" --body y')")"
check "hook allows other commands" 0 "$(run_hook "$(bash_input 'ls')")"
check "hook blocks bad MCP create" 2 \
  "$(run_hook '{"tool_name":"mcp__github__create_pull_request","tool_input":{"title":"Add x"}}')"
check "hook allows good MCP create" 0 \
  "$(run_hook '{"tool_name":"mcp__github__create_pull_request","tool_input":{"title":"feat: add x"}}')"
check "hook blocks bad MCP retitle" 2 \
  "$(run_hook '{"tool_name":"mcp__github__update_pull_request","tool_input":{"title":"Add x"}}')"
check "hook allows MCP update without title" 0 \
  "$(run_hook '{"tool_name":"mcp__github__update_pull_request","tool_input":{"body":"x"}}')"
check "hook blocks bad MCP squash title" 2 \
  "$(run_hook '{"tool_name":"mcp__github__merge_pull_request","tool_input":{"merge_method":"squash","commit_title":"Add x"}}')"
check "hook allows MCP merge commit title" 0 \
  "$(run_hook '{"tool_name":"mcp__github__merge_pull_request","tool_input":{"merge_method":"merge","commit_title":"Merge x"}}')"
check "hook allows MCP squash without title" 0 \
  "$(run_hook '{"tool_name":"mcp__github__merge_pull_request","tool_input":{"merge_method":"squash"}}')"

finish
