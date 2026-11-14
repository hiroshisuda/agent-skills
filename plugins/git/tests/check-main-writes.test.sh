#!/usr/bin/env bash
# Tests for the protected-branch check. Run all tests with plugins/git/tests/run.sh.
set -u
here=$(cd "$(dirname "$0")" && pwd)
scripts="$here/../scripts"
# shellcheck source=lib.sh
. "$here/lib.sh"
# shellcheck source=../scripts/main-writes.sh
. "$scripts/main-writes.sh"

# Protected names
for name in main master; do
  check "protects $name" 0 "$(is_protected_branch "$name" "" && echo 0)"
done
check "protects default" 0 "$(is_protected_branch trunk trunk && echo 0)"
check "allows feature" "" "$(is_protected_branch csv-export trunk && echo 0)"
check "allows main-like" "" "$(is_protected_branch main-fix "" && echo 0)"

# Command parsing
t=$'\t'
w() { main_writes_in_command "$1" /r; }
check "commit" "/r${t}HEAD${t}commit" "$(w 'git commit -m "fix: x"')"
check "commit -am" "/r${t}HEAD${t}commit" "$(w 'git commit -am wip')"
check "cherry-pick" "/r${t}HEAD${t}cherry-pick" "$(w 'git cherry-pick abc123')"
check "revert" "/r${t}HEAD${t}revert" "$(w 'git revert HEAD')"
check "am" "/r${t}HEAD${t}am" "$(w 'git am < p.patch')"
check "merge" "/r${t}HEAD${t}merge" "$(w 'git merge feature')"
check "merge ff-only" "" "$(w 'git merge --ff-only origin/main')"
check "merge abort" "" "$(w 'git merge --abort')"
check "rebase" "/r${t}HEAD${t}rebase" "$(w 'git rebase origin/main')"
check "rebase named branch" "/r${t}main${t}rebase" "$(w 'git rebase origin/main main')"
check "rebase onto" "/r${t}HEAD${t}rebase" "$(w 'git rebase --onto main old')"
check "rebase abort" "" "$(w 'git rebase --abort')"
check "push current" "/r${t}HEAD${t}push" "$(w 'git push -u origin')"
check "push named" "/r${t}main${t}push" "$(w 'git push origin main')"
check "push refspec" "/r${t}main${t}push" "$(w 'git push origin feat:main')"
check "push all" "/r${t}@all${t}push" "$(w 'git push --all origin')"
check "pull" "" "$(w 'git pull --ff-only origin main')"
check "status" "" "$(w 'git status && git log --oneline')"
check "switch -c then commit" "/r${t}feat${t}commit" "$(w 'git switch -c feat && git commit -m x')"
check "checkout -b then push" "/r${t}feat${t}push" "$(w 'git checkout -b feat; git push -u origin')"
check "switch main then commit" "/r${t}main${t}commit" "$(w 'git switch main && git commit -m x')"
check "checkout main then commit" "/r${t}main${t}commit" "$(w 'git checkout main && git commit -m x')"
check "checkout files keeps HEAD" "/r${t}HEAD${t}commit" "$(w 'git checkout -- a.txt && git commit -m x')"
check "checkout from branch keeps HEAD" "/r${t}HEAD${t}commit" "$(w 'git checkout main a.txt && git commit -m x')"
check "switch back is unknown" "/r${t}-${t}commit" "$(w 'git switch - && git commit -m x')"
check "branch state is per dir" "/r/sub${t}HEAD${t}commit" "$(w 'git switch -c feat && git -C sub commit -m x')"
check "cd then commit" "/abs${t}HEAD${t}commit" "$(w 'cd /abs && git commit -m x')"
check "not git" "" "$(w 'echo git commit')"

# The hook end to end
repo=$(mktemp -d)
remote=$(mktemp -d)
trap 'rm -rf "$repo" "$remote"' EXIT
git -C "$repo" init -q -b main
printf 'ignored.txt\n' >"$repo/.gitignore"
git -C "$repo" add .gitignore
git -C "$repo" -c user.name=t -c user.email=t@t commit -q -m init
run_hook() { # allow flag, tool, command or file path
  local input
  if [ "$2" = Bash ]; then
    input=$(jq -n --arg c "$3" --arg d "$repo" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}')
  else
    input=$(jq -n --arg t "$2" --arg f "$3" '{tool_name: $t, tool_input: {file_path: $f}}')
  fi
  printf '%s' "$input" | GIT_ALLOW_MAIN="$1" "$scripts/check-main-writes.sh" >/dev/null 2>&1
  echo $?
}
check "hook blocks commit on main" 2 "$(run_hook '' Bash 'git commit -m x')"
check "hook blocks push to main" 2 "$(run_hook '' Bash 'git push origin main')"
check "hook blocks push of main" 2 "$(run_hook '' Bash 'git push -u origin')"
check "hook blocks push all" 2 "$(run_hook '' Bash 'git push --all origin')"
check "hook blocks edit on main" 2 "$(run_hook '' Edit "$repo/a.txt")"
check "hook blocks new file on main" 2 "$(run_hook '' Write "$repo/new/dir/b.txt")"
check "hook allows ignored file on main" 0 "$(run_hook '' Write "$repo/ignored.txt")"
check "hook allows file outside repo" 0 "$(run_hook '' Write "$remote/c.txt")"
check "hook allows pull on main" 0 "$(run_hook '' Bash 'git pull --ff-only origin main')"
check "hook allows branching then commit" 0 "$(run_hook '' Bash 'git switch -c feat && git commit -m x')"
check "hook allows opt-out" 0 "$(run_hook 1 Bash 'git commit -m x')"
check "hook allows opt-out edit" 0 "$(run_hook 1 Edit "$repo/a.txt")"

git -C "$repo" switch -q -c feat
check "hook allows commit on feature" 0 "$(run_hook '' Bash 'git commit -m x')"
check "hook allows edit on feature" 0 "$(run_hook '' Edit "$repo/a.txt")"
check "hook blocks switch to main then commit" 2 "$(run_hook '' Bash 'git switch main && git commit -m x')"
check "hook blocks push to main from feature" 2 "$(run_hook '' Bash 'git push origin HEAD:main')"

# A default branch other than main or master, read from origin/HEAD.
git -C "$remote" init -q --bare -b trunk
git -C "$repo" branch -q -m main trunk
git -C "$repo" remote add origin "$remote"
git -C "$repo" push -q origin trunk 2>/dev/null
git -C "$repo" remote set-head origin trunk >/dev/null
check "hook blocks push to default branch" 2 "$(run_hook '' Bash 'git push origin feat:trunk')"

# A new repository with no commits has no main to branch from yet.
fresh=$(mktemp -d)
git -C "$fresh" init -q -b main
check "hook allows first commit" 0 "$(cd "$fresh" && jq -n --arg d "$fresh" \
  '{tool_name: "Bash", tool_input: {command: "git commit -m init"}, cwd: $d}' |
  "$scripts/check-main-writes.sh" >/dev/null 2>&1; echo $?)"
check "hook allows edit in new repo" 0 "$(run_hook '' Write "$fresh/a.txt")"
rm -rf "$fresh"

finish
