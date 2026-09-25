#!/bin/sh
set -eu
set -- build/config.sml
while IFS= read -r source; do
  case "$source" in ''|'#'*) continue ;; esac
  set -- "$@" "$source"
done < sources.txt
install/bin/rune --lib "$PWD/lib" -o build/rune.self-check.rbc "$@" src/main/rune-main.sml
cmp bin/rune.rbc build/rune.self-check.rbc
printf 'CORPUS_RUNE_SELF_CHECK_PASS\n'
