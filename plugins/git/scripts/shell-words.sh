#!/usr/bin/env bash
# Shell command tokenizer shared by the git plugin's hooks. Source this file; don't run it.
# It handles the quoting agents use (single and double quotes, backslashes, $(...)) without running
# anything. Expansions such as $VAR and $(...) stay as literal text.

# Word that marks the end of a simple command in shell_words output.
COMMAND_END=$'\x1e'

# Print the words of shell command $1, each NUL-terminated, with COMMAND_END after each simple
# command. Command separators (newline ; & | && || ( )) split commands.
shell_words() {
  local LC_ALL=C
  local s="$1" i=0 n=${#1} c rest part word="" have=0
  while ((i < n)); do
    c=${s:i:1}
    case "$c" in
      $'\n' | ';' | '&' | '|' | '(' | ')')
        ((have)) && printf '%s\0' "$word"
        word="" have=0
        printf '%s\0' "$COMMAND_END"
        ((i++))
        ;;
      ' ' | $'\t')
        ((have)) && printf '%s\0' "$word"
        word="" have=0
        ((i++))
        ;;
      "'")
        rest=${s:i+1}
        part=${rest%%"'"*}
        word+=$part have=1
        ((i += ${#part} + 2))
        ;;
      '"')
        ((i++))
        have=1
        while ((i < n)); do
          c=${s:i:1}
          if [ "$c" = '"' ]; then
            ((i++))
            break
          elif [ "$c" = '\' ]; then
            case "${s:i+1:1}" in
              '"' | '\' | '$' | '`') word+=${s:i+1:1} ;;
              $'\n') ;;
              *) word+=${s:i:2} ;;
            esac
            ((i += 2))
          elif [ "${s:i:2}" = '$(' ]; then
            part=$(balanced_substitution "$s" "$i")
            word+=$part
            ((i += ${#part}))
          else
            word+=$c
            ((i++))
          fi
        done
        ;;
      '\')
        [ "${s:i+1:1}" = $'\n' ] || word+=${s:i+1:1} have=1
        ((i += 2))
        ;;
      '$')
        if [ "${s:i+1:1}" = '(' ]; then
          part=$(balanced_substitution "$s" "$i")
        else
          part='$'
        fi
        word+=$part have=1
        ((i += ${#part}))
        ;;
      '#')
        if ((have)); then
          word+=$c
          ((i++))
        else
          rest=${s:i}
          part=${rest%%$'\n'*}
          ((i += ${#part}))
        fi
        ;;
      *)
        word+=$c have=1
        ((i++))
        ;;
    esac
  done
  ((have)) && printf '%s\0' "$word"
  printf '%s\0' "$COMMAND_END"
}

# The $(...) that starts at offset $2 of $1, up to its matching parenthesis (or the end of $1).
balanced_substitution() {
  local LC_ALL=C
  local s="$1" i=$(($2 + 2)) depth=1 c
  while ((i < ${#s} && depth > 0)); do
    c=${s:i:1}
    if [ "$c" = '(' ]; then
      ((depth++))
    elif [ "$c" = ')' ]; then
      ((depth--))
    fi
    ((i++))
  done
  printf '%s' "${s:$2:i-$2}"
}

# Call function $1 with the words of each simple command in shell command $2, after dropping
# leading VAR=value assignments. The function runs in the current shell, so it can keep state.
for_each_command() {
  local callback="$1" w
  local -a words=()
  while IFS= read -r -d '' w; do
    if [ "$w" != "$COMMAND_END" ]; then
      words+=("$w")
      continue
    fi
    while [ ${#words[@]} -gt 0 ] && [[ ${words[0]} =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do
      words=("${words[@]:1}")
    done
    [ ${#words[@]} -gt 0 ] && "$callback" "${words[@]}"
    words=()
  done < <(shell_words "$2")
}
