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

## MLton 20241230: invalid C-string escape

The expanded selection retains the same `String.fromCString "\\q"` failure as
[the portable subset](../../../known-differences.md). All nine other expanded
cases passed in the initial MLton validation. No MLton library patch is applied.

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
