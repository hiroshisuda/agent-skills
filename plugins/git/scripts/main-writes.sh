#!/usr/bin/env bash
# Pure helpers for the protected-branch check. Source this file; don't run it.
# Nothing here touches git or the filesystem, so the tests can call every function directly.

# shellcheck source=shell-words.sh
. "$(dirname "${BASH_SOURCE[0]}")/shell-words.sh"
# shellcheck source=git-args.sh
. "$(dirname "${BASH_SOURCE[0]}")/git-args.sh"

# Succeed if branch $1 is protected: main, master, or the repository's default branch $2.
is_protected_branch() {
  case "$1" in
    main | master) return 0 ;;
  esac
  [ -n "${2:-}" ] && [ "$1" = "$2" ]
}

# Print "<dir><TAB><branch><TAB><action>" for each branch that shell command $1, run in directory
# $2, would commit to, rewrite, or push. <branch> is a name, "HEAD" for the branch checked out in
# <dir> before the command, or "@all" for every local branch. The command's own branch switches
# are followed, so `git switch -c feature && git commit` reports feature, not HEAD.
main_writes_in_command() {
  local dir="$2" branch_dir="" branch=""
  for_each_command main_writes_in_simple_command "$1"
}

# Callback for for_each_command. Updates main_writes_in_command's dir, branch_dir and branch.
main_writes_in_simple_command() {
  case "$1" in
    cd) [ $# -gt 1 ] && dir=$(join_dir "$dir" "$2") ;;
    git) main_writes_in_git "${@:2}" ;;
  esac
  return 0
}

# Writes made by one git invocation; $@ are git's arguments.
main_writes_in_git() {
  read_git_invocation "$dir" "$@"
  [ ${#git_args[@]} -gt 0 ] || return 0
  set -- "${git_args[@]}"
  local here="$git_cwd" sub="$1" current=HEAD target
  shift
  [ "$here" = "$branch_dir" ] && current=$branch
  case "$sub" in
    switch | checkout)
      target=$(switched_branch "$sub" "$@")
      [ -n "$target" ] && branch_dir=$here branch=$target
      ;;
    commit | cherry-pick | revert | am)
      has_option "$@" -- --abort --quit --skip || printf '%s\t%s\t%s\n' "$here" "$current" "$sub"
      ;;
    merge)
      has_option "$@" -- --abort --quit --ff-only ||
        printf '%s\t%s\t%s\n' "$here" "$current" "$sub"
      ;;
    rebase)
      has_option "$@" -- --abort --quit --skip && return 0
      target=$(rebased_branch "$@")
      if [ -n "$target" ]; then
        branch_dir=$here branch=$target
      else
        target=$current
      fi
      printf '%s\t%s\t%s\n' "$here" "$target" "$sub"
      ;;
    push)
      push_targets "$@" | while IFS= read -r target; do
        [ "$target" = HEAD ] && target=$current
        printf '%s\t%s\t%s\n' "$here" "$target" "$sub"
      done
      ;;
  esac
  return 0
}

# The branch that `git switch` or `git checkout` ($1, followed by its arguments) leaves checked
# out, if the command line names one. Prints "-" when the result is unknown (such as `git switch -`
# or a detached HEAD), and nothing when the command checks out files instead.
switched_branch() {
  local sub="$1"
  shift
  local created
  if [ "$sub" = switch ]; then
    created=$(option_value "$@" -- -c -C --create --force-create --orphan)
  else
    created=$(option_value "$@" -- -b -B --orphan)
  fi
  if [ -n "$created" ]; then
    printf '%s' "$created"
    return 0
  fi
  has_option "$@" -- -d --detach && {
    printf '%s' -
    return 0
  }
  local -a positional=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --) [ "$sub" = checkout ] && return 0 ;; # checkout -- <paths>
      -) positional+=(-) ;;
      -*) ;;
      *) positional+=("$1") ;;
    esac
    shift
  done
  # `git checkout <branch> <paths>` copies files and stays on the current branch.
  [ ${#positional[@]} -eq 1 ] && printf '%s' "${positional[0]}"
  return 0
}

# The branch `git rebase <upstream> <branch>` checks out and rewrites, if it names one.
rebased_branch() {
  local -a positional=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --onto | -s | --strategy | -X | --strategy-option | -x | --exec) shift ;;
      -*) ;;
      *) positional+=("$1") ;;
    esac
    shift
  done
  [ ${#positional[@]} -ge 2 ] && printf '%s' "${positional[1]}"
  return 0
}
