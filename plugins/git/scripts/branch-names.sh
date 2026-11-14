#!/usr/bin/env bash
# Pure helpers for the branch-name check. Source this file; don't run it.
# Nothing here touches git or the filesystem, so the tests can call every function directly.

# shellcheck source=shell-words.sh
. "$(dirname "${BASH_SOURCE[0]}")/shell-words.sh"

# The naming convention from skills/branching/SKILL.md: lowercase kebab-case, no slashes.
BRANCH_NAME_PATTERN='^[a-z0-9]+(-[a-z0-9]+)*$'
# A year from 1900-2099 followed by a month, with an optional day: 2026-11, 202611, 2026-11-14.
BRANCH_DATE_PATTERN='(^|-)(19|20)[0-9]{2}-?(0[1-9]|1[0-2])(-?[0-3][0-9])?(-|$)'

# Print why branch name $1 breaks the convention, or nothing when it follows it.
branch_name_problem() {
  if ! [[ $1 =~ $BRANCH_NAME_PATTERN ]]; then
    echo "it isn't lowercase kebab-case (letters, digits and single hyphens, no slashes or prefixes such as claude/)"
  elif [[ $1 =~ $BRANCH_DATE_PATTERN ]]; then
    echo "it contains a date"
  fi
}

# Print "<dir><TAB><branch>" for each branch that shell command $1, run in directory $2, would
# create or push. <branch> is a name, "HEAD" for the branch checked out in <dir>, or "@all" for
# every local branch.
branches_in_command() {
  local dir="$2"
  for_each_command branches_in_simple_command "$1"
}

# Callback for for_each_command. Updates branches_in_command's dir on cd.
branches_in_simple_command() {
  case "$1" in
    cd) [ $# -gt 1 ] && dir=$(join_dir "$dir" "$2") ;;
    git) branches_in_git "$dir" "${@:2}" ;;
    gh) [ "${2:-}" = stack ] && branches_in_gh_stack "$dir" "${@:3}" ;;
  esac
  return 0
}

# Branches that gh stack init or gh stack add create: $1 is the directory, the rest are the
# arguments after "gh stack".
branches_in_gh_stack() {
  local dir="$1" sub="${2:-}" arg
  case "$sub" in
    init | add) ;;
    *) return 0 ;;
  esac
  shift 2
  for arg in "$@"; do
    case "$arg" in
      -*) ;;
      *) printf '%s\t%s\n' "$dir" "$arg" ;;
    esac
  done
}

# $2 resolved against directory $1.
join_dir() {
  case "$2" in
    /*) printf '%s' "$2" ;;
    *) printf '%s/%s' "$1" "$2" ;;
  esac
}

# Branches touched by one git invocation: $1 is the directory, the rest are git's arguments.
branches_in_git() {
  local dir="$1"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      -C)
        [ $# -gt 1 ] || return 0
        dir=$(join_dir "$dir" "$2")
        shift 2
        ;;
      -c | --git-dir | --work-tree | --namespace) shift 2 ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || return 0
  local sub="$1" name
  shift
  case "$sub" in
    switch) name=$(option_value "$@" -- -c -C --create --force-create --orphan) ;;
    checkout) name=$(option_value "$@" -- -b -B --orphan) ;;
    branch) name=$(new_branch_name "$@") ;;
    push)
      push_targets "$@" | while IFS= read -r name; do printf '%s\t%s\n' "$dir" "$name"; done
      return 0
      ;;
    *) return 0 ;;
  esac
  [ -n "$name" ] && printf '%s\t%s\n' "$dir" "$name"
  return 0
}

# Print the word after the first of the given options. Usage: option_value <args> -- <options>.
option_value() {
  local -a args=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do
    args+=("$1")
    shift
  done
  shift
  local i opt
  for ((i = 0; i < ${#args[@]} - 1; i++)); do
    for opt in "$@"; do
      if [ "${args[i]}" = "$opt" ]; then
        printf '%s' "${args[i + 1]}"
        return 0
      fi
    done
  done
}

# The branch that `git branch <args>` creates, renames to, or copies to, if any.
new_branch_name() {
  local -a positional=()
  local renaming=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -m | -M | --move | -c | -C | --copy) renaming=1 ;;
      # Listing, deleting, and upstream or description changes create no branch.
      -d | -D | --delete | -l | --list | -a | --all | -r | --remotes | -v | -vv | --verbose | \
        --show-current | --contains | --no-contains | --merged | --no-merged | --points-at | \
        -u | --set-upstream-to* | --unset-upstream | --edit-description | --format* | --sort*)
        return 0
        ;;
      --) ;;
      -*) ;;
      *) positional+=("$1") ;;
    esac
    shift
  done
  [ ${#positional[@]} -gt 0 ] || return 0
  if [ "$renaming" = 1 ]; then
    printf '%s' "${positional[${#positional[@]} - 1]}"
  else
    printf '%s' "${positional[0]}"
  fi
}

# One line per branch that `git push <args>` updates on the remote.
push_targets() {
  local -a positional=()
  local all=0 tags=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -d | --delete) return 0 ;;
      --all | --mirror | --branches) all=1 ;;
      --tags) tags=1 ;;
      -o | --push-option | --repo | --receive-pack | --exec) shift ;;
      -*) ;;
      *) positional+=("$1") ;;
    esac
    shift
  done
  if [ "$all" = 1 ]; then
    echo "@all"
    return 0
  fi
  if [ ${#positional[@]} -le 1 ]; then
    [ "$tags" = 1 ] || echo HEAD
    return 0
  fi
  local refspec dst
  for refspec in "${positional[@]:1}"; do
    refspec="${refspec#+}"
    case "$refspec" in
      :*) continue ;; # deletes a remote branch
      *:) continue ;;
      *:*) dst="${refspec#*:}" ;;
      *) dst="$refspec" ;;
    esac
    dst="${dst#refs/heads/}"
    case "$dst" in
      refs/*) continue ;; # tags, notes, and other non-branch refs
    esac
    echo "$dst"
  done
}
