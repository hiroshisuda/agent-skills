#!/usr/bin/env bash
# Pure helpers for the PR-title check. Source this file; don't run it.
# The rules mirror skills/commit-messages/SKILL.md: a squash merge turns the PR title into the
# commit subject that release tooling reads.

# shellcheck source=shell-words.sh
. "$(dirname "${BASH_SOURCE[0]}")/shell-words.sh"

PR_TITLE_TYPES='feat|fix|docs|refactor|test|chore|perf|build|ci|style|revert'
PR_TITLE_MAX_LENGTH=72
PR_TITLE_PATTERN="^(${PR_TITLE_TYPES})(\([^()[:space:]]+\))?!?: ([^[:space:]].*)$"

# Print why title $1 isn't a Conventional Commits subject, as "; "-separated reasons, or nothing.
pr_title_problem() {
  local -a reasons=()
  case "$1" in
    *'$'* | *'`'*)
      echo "it's built by the shell (it contains \$ or a backtick), so it can't be checked; pass the title as literal text"
      return 0
      ;;
  esac
  if [[ $1 == *$'\n'* ]]; then
    reasons+=("it spans more than one line")
  elif [[ $1 =~ $PR_TITLE_PATTERN ]]; then
    local subject="${BASH_REMATCH[3]}"
    [[ $subject =~ ^[A-Z] ]] && reasons+=("the subject starts with a capital letter")
    [[ $subject == *. ]] && reasons+=("it ends with a period")
  else
    reasons+=("it doesn't match type(optional scope)!: subject, with type one of ${PR_TITLE_TYPES//|/, }")
  fi
  [ ${#1} -gt "$PR_TITLE_MAX_LENGTH" ] &&
    reasons+=("it's ${#1} characters, over the limit of $PR_TITLE_MAX_LENGTH")
  [ ${#reasons[@]} -gt 0 ] || return 0
  local IFS=';'
  printf '%s\n' "${reasons[*]}" | sed 's/;/; /g'
}

# Print "- <what>: <problem>" for each PR or squash-commit title in shell command $1 that breaks
# the rules.
pr_title_problems_in_command() {
  for_each_command pr_title_problems_in_simple_command "$1"
}

# Callback for for_each_command: checks gh pr create, gh pr edit and gh pr merge --squash.
pr_title_problems_in_simple_command() {
  [ "$1" = gh ] && [ "${2:-}" = pr ] || return 0
  local action="${3:-}" title="" has_title=0 squash=0
  shift 3 2>/dev/null || return 0
  while [ $# -gt 0 ]; do
    case "$action:$1" in
      create:-t | create:--title | edit:-t | edit:--title | merge:-t | merge:--subject)
        title="${2:-}" has_title=1
        shift
        ;;
      create:--title=* | edit:--title=* | merge:--subject=*)
        title="${1#*=}" has_title=1
        ;;
      merge:-s | merge:--squash) squash=1 ;;
    esac
    shift
  done
  case "$action" in
    create)
      if [ "$has_title" = 0 ]; then
        echo "- gh pr create: it has no --title, so gh would fill the title from commits or the branch name; pass --title explicitly"
        return 0
      fi
      ;;
    edit) [ "$has_title" = 1 ] || return 0 ;;
    merge) [ "$has_title" = 1 ] && [ "$squash" = 1 ] || return 0 ;;
    *) return 0 ;;
  esac
  report_title_problem "gh pr $action" "$title"
}

# Print "- <what> '<title>': <problem>" when title $2 breaks the rules.
report_title_problem() { # what, title
  local problem
  problem=$(pr_title_problem "$2")
  [ -z "$problem" ] || printf -- "- %s '%s': %s\n" "$1" "$2" "$problem"
}
