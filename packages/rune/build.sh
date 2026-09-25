#!/bin/sh
# Run inside the freshly extracted commit; the seed and its VM are explicit.
set -eu
stage=$1
seed=$2
seed_vm=$3
seed_library=$4
sh scripts/gen-build-files.sh "$PWD"
mkdir -p bin
make JOBS=4 DOCTOR=no CC=gcc bin/runevm
set -- build/config.sml
while IFS= read -r source; do
  case "$source" in ''|'#'*) continue ;; esac
  set -- "$@" "$source"
done < sources.txt
set -- "$@" src/main/rune-main.sml
case "$stage" in
  1)
    # Stage 1 is hosted by the external seed's Basis and matching VM. The
    # resulting compiler emits this commit's bytecode in the next stage.
    "$seed" --lib "$seed_library" -o bin/rune.rbc "$@"
    cp bin/runevm build/runevm-target
    cp "$seed_vm" bin/runevm
    ;;
  2)
    "$seed" --lib "$PWD/lib" -o bin/rune.rbc "$@"
    ;;
  *) echo 'invalid Rune bootstrap stage' >&2; exit 1 ;;
esac
sh scripts/install.sh --prefix "$PWD/install"
if [ "$stage" = 1 ]; then cp build/runevm-target install/bin/runevm-target; fi
