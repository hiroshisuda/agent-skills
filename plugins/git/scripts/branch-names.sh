#!/usr/bin/env bash
# Pure helpers for the branch-name check. Source this file; don't run it.
# Nothing here touches git or the filesystem, so the tests can call every function directly.

# shellcheck source=shell-words.sh
. "$(dirname "${BASH_SOURCE[0]}")/shell-words.sh"
# shellcheck source=git-args.sh
. "$(dirname "${BASH_SOURCE[0]}")/git-args.sh"

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

# Branches touched by one git invocation: $1 is the directory, the rest are git's arguments.
branches_in_git() {
  read_git_invocation "$@"
  [ ${#git_args[@]} -gt 0 ] || return 0
  set -- "${git_args[@]}"
  local dir="$git_cwd" sub="$1" name
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
