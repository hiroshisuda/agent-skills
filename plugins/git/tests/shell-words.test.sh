#!/usr/bin/env bash
# Tests for the shell tokenizer. Run all tests with plugins/git/tests/run.sh.
set -u
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
. "$here/lib.sh"
# shellcheck source=../scripts/shell-words.sh
. "$here/../scripts/shell-words.sh"

# Commands as lines, words joined by "|", for easy comparison.
show() {
  local line="" w
  while IFS= read -r -d '' w; do
    if [ "$w" = "$COMMAND_END" ]; then
      [ -n "$line" ] && printf '%s\n' "${line#|}"
      line=""
    else
      line+="|$w"
    fi
  done < <(shell_words "$1")
}

check "plain" "git|push|origin" "$(show 'git push origin')"
check "single quotes" "a|b c|d" "$(show "a 'b c' d")"
check "double quotes" "a|b \"c\" \$x" "$(show 'a "b \"c\" $x"')"
check "joined quotes" "--title=x y" "$(show "--title='x y'")"
check "backslash" "a b" "$(show 'a\ b')"
check "separators" $'a\nb\nc\nd' "$(show 'a && b; c | d')"
check "newline" $'a\nb' "$(show $'a\nb')"
check "separator in quotes" "echo|a; b && c" "$(show "echo 'a; b && c'")"
check "substitution" 'x|$(cat <<A
y; z
A
)' "$(show 'x "$(cat <<A
y; z
A
)"')"
check "bare substitution" 'x|$(a b)' "$(show 'x $(a b)')"
check "comment" "a" "$(show 'a # b c')"
check "hash in word" "a#b" "$(show 'a#b')"
check "empty quotes" "a||b" "$(show "a '' b")"
check "continuation" "a|b" "$(show $'a \\\nb')"

FOO=0
count() { FOO=$((FOO + 1)); }
for_each_command count 'X=1 a; b && Y=2 c'
check "for_each_command keeps state" 3 "$FOO"
args() { printf '%s,' "$@"; }
check "for_each_command drops assignments" "c," "$(for_each_command args 'Y=2 c')"

finish
