# Investigated differences

The suite keeps these outcomes as failures. They are not expected-pass rules,
and they do not change the eligibility of compiler artifacts that passed their
separate bootstrap validation. A regression profile containing these checks
returns a nonzero exit status with the affected tasks and logs preserved.

## Poly/ML 5.9.2: extreme substring bounds

`Substring.substring ("", valOf Int.maxInt, valOf Int.maxInt)` raises `Overflow`
in the tested corpus-built Poly/ML. The required exception is `Subscript`.
The [Basis specification](https://smlfamily.github.io/Basis/substring.html)
explicitly requires bounds checking that does not raise `Overflow`.
The corresponding minimum-integer case correctly raises `Subscript`.

The suite first reports `substring.test30f[0]: expected OK, got EXN`.
[The reduced program](reproducers/substring-extreme-bounds.sml) prints each
exception and exits unsuccessfully for a different exception or unexpected
success. It was compiled by the exact Poly/ML stage-2 artifact and reproduced
`maximum: UNEXPECTED Overflow` and `minimum: Subscript`.

**Rune tests:** `~/rune`'s Basis Library suite already exercises this exact
case: `tests/basis/substring.sml`'s overflow section
(`Substring.substring/Subscript-not-Overflow-sum-*`,
`Substring.extract/SOME-Subscript-not-Overflow-sum-*`,
`Substring.extract/NONE-Subscript-not-Overflow-smallest`), built from
`Int.maxInt`/`Int.minInt` as its `big`/`small`. Running
`sh tests/basis/run-matrix.sh --configs native:polyml substring` against the
same `polyml-5.9.2` reproduces exactly these 7 checks as failures, each
already recorded as a `HOST-BUG` in `tests/basis/deviations.txt` (mirrored in
`tests/basis/annotations.txt`); 0 unexplained failures.

**Upstream status:** reported as
[polyml/polyml#315](https://github.com/polyml/polyml/issues/315) on
2026-09-25 (no existing report was found before that; searched `substring`,
`extract`, `overflow subscript`, `bounds`). `basis/String.sml`'s
`Substring.substring`/`extract` (current `master`) still bound-check with
plain `int` addition (`i + j`) before comparing against the string length,
unlike `String.substring`/`extract` in the same file, which convert to
`word` first specifically to avoid the overflow; the issue includes a
minimal reproducer and a suggested fix, also preserved at
`rune/docs/bugreport/polyml/Substring.substring/Subscript-not-Overflow/BUGREPORT.md`.

## Poly/ML 5.9.2: hexadecimal word prefix

`Word8.fromString "0w21"` and hexadecimal `Word8.scan` return the word `0wx21`
in the tested Poly/ML. The [Basis scanning grammar](https://smlfamily.github.io/Basis/word.html)
requires a hexadecimal prefix to include `x` or `X`; without it, the valid
initial numeric substring is `"0"`. The expected result is `SOME 0w0`.

The suite first reports `word8.test13a[5]: expected OK, got WRONG`.
[The reduced program](reproducers/word8-hex-prefix.sml) checks both APIs and
prints `UNEXPECTED SOME 21` for each, with 21 displayed in hexadecimal.
This difference is present in an unchanged upstream expectation and is separate
from the two corrected upstream `"0w1"` expectations described in the README.

**Rune tests:** the same case is covered generically for every `Word*`
structure by `tests/basis/fn/word_fn.sml` (`fromString`) and
`tests/basis/fn/word_scan_fn.sml` (`scan`), instantiated for `Word8` in
`tests/basis/word8.sml`, case `0w-is-no-prefix`. Running against the same
`polyml-5.9.2` reproduces `Word8.fromString/0w-is-no-prefix` and
`Word8.scan/HEX-0w-is-no-prefix` exactly, both recorded as a `HOST-BUG` in
`tests/basis/deviations.txt`; 0 unexplained failures.

**Upstream status:** already reported and fixed, but not yet released.
[polyml/polyml#290](https://github.com/polyml/polyml/issues/290)
("Inconsistency converting with other compilers when calling
`Word.fromString`"), fixed by commit `fcd823f` merged into `master` on
2026-06-27. The newest release remains v5.9.2 (2025-08-11), which predates the
fix, so the corpus's pinned artifact still shows the bug until Poly/ML cuts a
new release.

## MLton 20241230: invalid C-string escape

The expanded selection retains the same `String.fromCString "\\q"` failure as
[the portable subset](../../../known-differences.md). All nine other expanded
cases passed in the initial MLton validation. No MLton library patch is applied.

**Upstream status:** reported as
[MLton/mlton#658](https://github.com/MLton/mlton/issues/658) on 2026-09-25.
See the portable subset's write-up for Rune-test references, and the issue
(also preserved at
`rune/docs/bugreport/mlton/String.fromCString/NONE-illegal-escape/BUGREPORT.md`)
for a suggested fix.

## Reproduction and follow-up

Build either reduced program with `bin/corpus program SOURCE ARTIFACT_RECORD`,
then invoke `bin/corpus execute` with the resulting program artifact. The command
prints its new artifact/log path. The exact validated Poly/ML artifact and run
IDs are recorded in [implementation notes](../../../../../../docs/implementation.md).
The exported lifecycle bundle `_work/polyml-592-expanded-basis-failures.tar.gz`
contains the suite's generated SML reproducers, records and raw logs. Reduced
program sources are committed here so they do not depend on that local bundle.

The follow-up is an upstream library fix or an explicitly versioned corpus patch
with its own justification and validation, followed by a fresh compiler build
and rerun. Keep the original compiler artifact and failures for comparison.
There is no known Rune failure in this expanded selection and no Rune repository
change was needed.
