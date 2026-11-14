#!/usr/bin/env bash
# Tests for the branch-name check. Run all tests with plugins/git/tests/run.sh.
set -u
here=$(cd "$(dirname "$0")" && pwd)
scripts="$here/../scripts"
# shellcheck source=lib.sh
. "$here/lib.sh"
# shellcheck source=../scripts/branch-names.sh
. "$scripts/branch-names.sh"

# Names
for name in csv-export fix-empty-input-crash proj-218-csv-export v2-api main; do
  check "accepts $name" "" "$(branch_name_problem "$name")"
done
for name in claude/amazing-lamport-wl9v25 Feature-X csv_export csv--export -csv csv- feature/csv; do
  check "rejects $name" "1" "$([ -n "$(branch_name_problem "$name")" ] && echo 1)"
done
for name in csv-export-2026-11-14 20261114-fix release-2026-11 fix-202611; do
  check "rejects dated $name" "it contains a date" "$(branch_name_problem "$name")"
done

# Command parsing
t=$'\t'
check "switch -c" "/r${t}csv-export" "$(branches_in_command 'git switch -c csv-export' /r)"
check "checkout -b" "/r${t}Bad" "$(branches_in_command 'git checkout -b Bad origin/main' /r)"
check "plain checkout" "" "$(branches_in_command 'git checkout main' /r)"
check "branch create" "/r${t}new" "$(branches_in_command 'git branch new main' /r)"
check "branch rename" "/r${t}new" "$(branches_in_command 'git branch -m old new' /r)"
check "branch delete" "" "$(branches_in_command 'git branch -D claude/x' /r)"
check "branch list" "" "$(branches_in_command 'git branch -a' /r)"
check "push current" "/r${t}HEAD" "$(branches_in_command 'git push -u origin' /r)"
check "push bare" "/r${t}HEAD" "$(branches_in_command 'git push' /r)"
check "push named" "/r${t}feat" "$(branches_in_command 'git push -u origin feat' /r)"
check "push refspec" "/r${t}claude/x" "$(branches_in_command 'git push origin HEAD:refs/heads/claude/x' /r)"
check "push force refspec" "/r${t}dst" "$(branches_in_command 'git push origin +src:dst' /r)"
check "push delete" "" "$(branches_in_command 'git push origin --delete claude/x' /r)"
check "push colon delete" "" "$(branches_in_command 'git push origin :claude/x' /r)"
check "push tags" "" "$(branches_in_command 'git push --tags origin' /r)"
check "push tag ref" "" "$(branches_in_command 'git push origin refs/tags/v1' /r)"
check "push all" "/r${t}@all" "$(branches_in_command 'git push --all origin' /r)"
check "push option value" "/r${t}feat" "$(branches_in_command 'git push -o ci.skip origin feat' /r)"
check "git -C" "/r/sub${t}HEAD" "$(branches_in_command 'git -C sub push' /r)"
check "cd then push" "/abs${t}HEAD" "$(branches_in_command 'cd /abs && git push' /r)"
check "env and quotes" "/r${t}x" "$(branches_in_command "FOO=1 git switch -c 'x'" /r)"
check "quoted message" "/r${t}HEAD" "$(branches_in_command 'git commit -m "fix: a; b" && git push' /r)"
check "chain" "/r${t}a"$'\n'"/r${t}HEAD" "$(branches_in_command 'git switch -c a; git commit -m wip && git push' /r)"
check "gh stack init" "/r${t}a"$'\n'"/r${t}b" "$(branches_in_command 'gh stack init a b' /r)"
check "gh stack add" "/r${t}refactor/foo" "$(branches_in_command 'gh stack add refactor/foo' /r)"
check "gh stack submit" "" "$(branches_in_command 'gh stack submit --auto' /r)"
check "not git" "" "$(branches_in_command 'echo git push origin bad/name' /r)"

# The hook end to end
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
git -C "$repo" init -q -b claude/amazing-lamport-wl9v25
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
run_hook() { # remote flag, command
  jq -n --arg c "$2" --arg d "$repo" '{tool_input: {command: $c}, cwd: $d}' |
    CLAUDE_CODE_REMOTE="$1" "$scripts/check-branch-name.sh" >/dev/null 2>&1
  echo $?
}
check "hook blocks assigned branch push" 2 "$(run_hook true 'git push -u origin claude/amazing-lamport-wl9v25')"
check "hook blocks current branch push" 2 "$(run_hook true 'git push -u origin HEAD')"
check "hook blocks bad create" 2 "$(run_hook true 'git switch -c fix-2026-11-14')"
check "hook blocks bad stack layer" 2 "$(run_hook true 'gh stack add claude/api')"
check "hook allows good create" 0 "$(run_hook true 'git switch -c csv-export')"
check "hook allows good push" 0 "$(run_hook true 'git push -u origin csv-export')"
check "hook allows non-git" 0 "$(run_hook true 'ls -la')"
check "hook ignores local sessions" 0 "$(run_hook '' 'git push -u origin claude/x')"
git -C "$repo" branch -q -m csv-export
check "hook allows renamed branch push" 0 "$(run_hook true 'git push -u origin')"

finish
