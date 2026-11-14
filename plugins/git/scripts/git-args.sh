#!/usr/bin/env bash
# Pure helpers for reading git command lines, shared by the git plugin's hooks. Source this file;
# don't run it. Nothing here touches git or the filesystem.

# $2 resolved against directory $1.
join_dir() {
  case "$2" in
    /*) printf '%s' "$2" ;;
    *) printf '%s/%s' "$1" "$2" ;;
  esac
}

# Split one git invocation into the directory it runs in and its subcommand with arguments.
# $1 is the directory, the rest are git's arguments. Sets git_cwd and the array git_args.
read_git_invocation() {
  git_cwd="$1"
  git_args=()
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      -C)
        [ $# -gt 1 ] || return 0
        git_cwd=$(join_dir "$git_cwd" "$2")
        shift 2
        ;;
      -c | --git-dir | --work-tree | --namespace) shift 2 ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] && git_args=("$@")
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

# Succeed if any of the given options appears. Usage: has_option <args> -- <options>.
has_option() {
  local -a args=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do
    args+=("$1")
    shift
  done
  shift
  local arg opt
  for arg in ${args[@]+"${args[@]}"}; do
    for opt in "$@"; do
      [ "$arg" = "$opt" ] && return 0
    done
  done
  return 1
}

# One line per branch that `git push <args>` updates on the remote: a name, "HEAD" for the
# checked-out branch, or "@all" for every local branch.
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
