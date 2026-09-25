#!/bin/sh
set -eu
compiler=$1
runtime=$2
source=$3
out=$4
"$compiler" "$source" -o "$out"
"$runtime" "$out"
