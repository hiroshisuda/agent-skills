#!/usr/bin/env bash
# PreToolUse (Bash and file-editing tools), all sessions: keep agents off protected branches (main,
# master, and the repository's default branch). Blocks git commands that commit to, rewrite, or
# push one, and file edits in a repository while one is checked out. Claude gets the reason
# through stderr (exit 2). The user can allow it for a session with GIT_ALLOW_MAIN=1.
set -u

[ "${GIT_ALLOW_MAIN:-}" = 1 ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# shellcheck source=main-writes.sh
. "$(dirname "$0")/main-writes.sh"

input=$(cat)
field() { printf '%s' "$input" | jq -r "$1 // empty"; }

# The repository's default branch, from origin/HEAD.
default_branch() { # dir
  local ref
  ref=$(git -C "$1" symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null) || return 0
  printf '%s' "${ref#origin/}"
}

# Succeed if the repository at $1 has commits. Until then there is no main to branch from.
has_commits() { git -C "$1" rev-parse -q --verify HEAD >/dev/null 2>&1; }

# Print the protected branches among the names $2 stands for in repository $1.
protected_in() { # dir, name
  local dir="$1" default name
  has_commits "$dir" || return 0
  default=$(default_branch "$dir")
  case "$2" in
    HEAD) name=$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null) ;;
    @all) name=$(git -C "$dir" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null) ;;
    *) name=$2 ;;
  esac
  while IFS= read -r name; do
    [ -n "$name" ] && is_protected_branch "$name" "$default" && printf '%s\n' "$name"
  done <<<"$name"
}

# The nearest existing directory at or above path $1, so new files resolve to their repository.
existing_dir() {
  local dir
  dir=$(dirname "$1")
  while [ ! -d "$dir" ]; do dir=$(dirname "$dir"); done
  printf '%s' "$dir"
}

problems=""
tool=$(field .tool_name)
case "$tool" in
  Bash)
    command=$(field .tool_input.command)
    case "$command" in
      *git*) ;;
      *) exit 0 ;;
    esac
    cwd=$(field .cwd)
    while IFS=$'\t' read -r dir name action; do
      [ -n "$dir" ] || continue
      while IFS= read -r branch; do
        [ -n "$branch" ] && problems="${problems}- git $action would write to '$branch' in $dir
"
      done < <(protected_in "$dir" "$name")
    done < <(main_writes_in_command "$command" "${cwd:-$PWD}")
    ;;
  *)
    file=$(field '.tool_input.file_path // .tool_input.notebook_path')
    [ -n "$file" ] || exit 0
    dir=$(existing_dir "$file")
    git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
    # Ignored files (local config, build output) never reach a commit.
    git -C "$dir" check-ignore -q -- "$file" 2>/dev/null && exit 0
    branch=$(protected_in "$dir" HEAD)
    [ -n "$branch" ] && problems="- $tool would change $file while '$branch' is checked out
"
    ;;
esac

[ -n "$problems" ] || exit 0
cat >&2 <<EOF
Blocked by the git plugin: agents don't commit to, rewrite, push, or edit files on main, master, or
the repository's default branch. Work on a feature branch, as the branching skill describes:
update main with git pull --ff-only, then git switch -c <feature-name> (uncommitted changes come
along), and open a pull request from it.
${problems}If local commits already landed on main, create the feature branch from them and ask the user
before resetting main. If the user explicitly wants work on main, they can allow it for the session
by starting Claude Code with GIT_ALLOW_MAIN=1 set.
EOF
exit 2
