# SML/NJ regression subset

Source: the [official regression repository](https://github.com/smlnj/regression-tests),
commit `95b939dd312452654abf74f9f327842de1a31f62` of 2026-09-02. There are no
published releases, so this deliberately pins a commit archive. Its SHA-256 is
`96bdc83a69cad6f5ba54356c81727adbe6ec93ab4774952b6487ffe69e93cb16`, computed
after downloading the official archive over HTTPS. License: upstream BSD-3-Clause
and retained author attribution in source files.

The archive omits the expected-output and known-bug files described in upstream's
README. This subset instead uses the explicit semantic assertions in Peter
Sestoft's List, Vector and String tests. The committed validators name all 113
test results and require `OK`; they are not outputs captured from a candidate
compiler. Every case requires successful execution and a completion marker.
Failures retain source, validator identity, generated program and raw logs;
the other cases still run.

`list-assertion.patch` fixes upstream test14, which returns the `checkv` function
instead of calling it. Calling it at the original point checks List.app's effects
before later tests change the shared reference. No other assertion is weakened.
`vector-limit.patch` handles the case where `Vector.maxLen = Int.maxInt`:
`maxLen + 1` then raises `Overflow` before `Vector.tabulate` is called. The test
accepts that arithmetic overflow only when the declared limits are equal;
representable over-limit lengths must still raise `Size`. The [Basis Vector
contract](https://smlfamily.github.io/Basis/vector.html) does not require a
representable integer above `maxLen`. This is a portable test-boundary correction.
String's invalid-escape expectations remain unchanged.

Recipes select exact corpus-built compiler artifacts, including Rune commit versions:
SML/NJ 2026.2 and 110.99.9, MLton 20241230, and Poly/ML 5.9.2. Run, for example:

Set `corpus_rune` to the absolute path of a validated Rune stage-2 artifact.

```sh
bin/corpus test packages/smlnj-regressions/95b939d/rune.record amd64-linux "$corpus_rune"
bin/corpus test packages/smlnj-regressions/95b939d/smlnj.record amd64-linux PATH/TO/artifact.record
```

Replace `test` with `doctor`, `fetch`, `patch` or `build` for the other lifecycle
operations. Acquisition, metadata, isolated environments and evidence use the
same contract as compiler packages. `build` prepares suite inputs; `test` compiles
and runs the selected cases. SML/NJ and Poly/ML combine compilation and execution;
these are correctness runs, not compile-time benchmarks.

Both SML/NJ versions, Rune and Poly/ML passed the initial 113 checks. MLton's
stage-2 run exposed the vector test-boundary issue above and a String.fromCString
discrepancy; see [known differences](known-differences.md). Its full subset is
not reported as passing. This subset excludes I/O setup,
architecture-specific arithmetic and the separate compiler-error/module suites;
it is not a claim that the full upstream regression suite passed.

## Expanded selection

The separate [expanded Basis suite](suites/basis-expanded/1/README.md) retains
this quick selection and adds arrays, slices, scanning, substrings and byte
arithmetic: 611 verdicts from ten upstream files. It has its own recipes and
isolated attempts, so it can coexist with the 113-verdict selection.
