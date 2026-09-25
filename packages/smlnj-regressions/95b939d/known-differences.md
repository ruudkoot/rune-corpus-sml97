# Investigated regression differences

## Vector length arithmetic

The unmodified upstream `vector.test4a` evaluates `Vector.maxLen + 1` and expects
`Vector.tabulate` to reject that length. An implementation may set `maxLen` to
the greatest representable `int`; the argument computation then overflows before
the library function is called. The [Basis Vector specification](https://smlfamily.github.io/Basis/vector.html)
defines a maximum supported length without requiring an integer above it.

`vector-limit.patch` therefore accepts arithmetic `Overflow` only when
`Int.maxInt = SOME Vector.maxLen`. Every representable length above `maxLen`
still requires `Size`. No compiler implementation is changed. The standalone
`reproducers/vector-limit.sml` reports both limits and the argument evaluation.

## Invalid C escape at the start of a string

MLton 20241230's initial shared-suite attempt
`_work/attempts/1790263874785980-2B3F3C-1` failed `string.test24`, whose oracle
requires `NONE` for invalid initial C escapes. This is separate from the vector
test issue. The [Basis STRING specification](https://smlfamily.github.io/Basis/string.html#SIG:STRING.fromCString:VAL)
gives `fromCString` the same failure rule as `fromString`, using C escapes.
An illegal initial escape must return `NONE`.

Inspection of the pinned MLton source shows `basis-library/text/string.sml`
defining `fromCString` through `scanString Char.scanC`; `Reader.list` in
`basis-library/util/reader.sml` returns a successful empty list when the initial
character scanner fails. The minimal `reproducers/c-string-invalid-escape.sml`
checks `String.fromCString "\\q"` and fails if it returns `SOME`.

The discrepancy is retained as a reference-compiler failure, not an accepted
oracle normalization. The minimal program printed `UNEXPECTED SOME ""` and
exited 1 at `_work/program-runs/1790285717950437-3A4F4C-1`. The vector reproducer
confirmed both limits equal 2147483647 at
`_work/program-runs/1790285717981441-3A4F58-1`.

With the portable vector patch, MLton attempt
`_work/attempts/1790285717999481-3A4F62-1` passes List and Vector and still fails
String. An evidence bundle is `_work/mlton-20241230-c-string-failure.tar.gz`.
Rune, Poly/ML and modern SML/NJ passed the corrected subset at
`_work/attempts/1790285717967366-3A4F52-1`,
`_work/attempts/1790285718017794-3A4F6B-1` and
`_work/attempts/1790285718043383-3A4F89-1`. Full compiler changes are outside
this integration fix.

**Rune tests:** `~/rune`'s Basis Library suite covers the same case directly:
`tests/basis/string.sml`'s `String.fromCString/NONE-illegal-escape` (and
`NONE-newline`, `NONE-lone-backslash`). Running
`sh tests/basis/run-matrix.sh --configs native:mlton string` against the same
`mlton-20241230` reproduces them exactly, each recorded as a `HOST-BUG` in
`tests/basis/deviations.txt` ("SOME "" instead of NONE when no character can
be converted"); 0 unexplained failures.

**Upstream status:** reported as
[MLton/mlton#658](https://github.com/MLton/mlton/issues/658) on 2026-09-25
(no existing report was found before that; searched `fromCString`, `escape`,
`invalid escape`, `scanString`). `basis-library/text/string.sml`'s
`fromCString` (current `master`) is still built from `Reader.list`,
documented "never returns NONE" (`basis-library/util/reader.sml`), so the
behavior described above remains present; the issue includes a minimal
reproducer and a suggested fix, also preserved at
`rune/docs/bugreport/mlton/String.fromCString/NONE-illegal-escape/BUGREPORT.md`.
