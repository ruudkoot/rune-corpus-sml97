# Expanded Basis suite, revision 1

This separately acquired suite uses the same pinned SML/NJ regression commit
`95b939dd312452654abf74f9f327842de1a31f62` as the
[portable subset](../../../README.md). It adds a representative larger Basis
workload: ten source files, 2,318 upstream lines, 436 named test declarations
and 611 checked verdicts. Some verdicts contain range checks over thousands of
inputs; those predicates are not counted as separate verdicts.

The selection follows the SML/NJ package's recommendation to exercise its
upstream regressions. It covers mutable identity, overlapping array copies,
slices and bounds, evaluation order, scanning through both strings and file
streams, substring boundaries, byte vectors and modular arithmetic. HaMLet
provides the separate substantial application workload. This suite is broader
than the quick subset, but is not the complete SML/NJ regression collection.

## Inputs and supported selections

Recipes acquire the official GitHub commit archive and verify SHA-256
`96bdc83a69cad6f5ba54356c81727adbe6ec93ab4774952b6487ffe69e93cb16` before use.
It is a commit pin because upstream has no release archive. The checksum was
computed over the official HTTPS download on 2026-09-23. Upstream's BSD license
and source attribution remain in the acquired tree; no upstream source copy is
committed here. Revision 1 identifies this suite selection and its validators,
not a new upstream release.

Use an exact validated corpus compiler, including a Rune commit artifact: SML/NJ 2026.2 or
110.99.9, MLton 20241230, or Poly/ML 5.9.2. The initial platform is x86-64 Linux.
Reference support means the adapter runs the checks and records their verdicts;
it does not imply that every compiler passes them. Validation results and
investigated differences are recorded below as they become available.

Set `corpus_rune` to the absolute path of a validated Rune stage-2 artifact.

```sh
bin/corpus doctor packages/smlnj-regressions/95b939d/suites/basis-expanded/1/rune.record amd64-linux
bin/corpus test packages/smlnj-regressions/95b939d/suites/basis-expanded/1/rune.record amd64-linux "$corpus_rune"
bin/corpus test packages/smlnj-regressions/95b939d/suites/basis-expanded/1/polyml.record amd64-linux PATH/TO/STAGE2/artifact.record
```

Use `smlnj.record` or `mlton.record` for the other reference families. `fetch`,
`patch` and `build` retain their normal lifecycle meanings; the build phase
registers the prepared suite inputs and compilation happens per case during
`test`. Prerequisites are the normal Linux acquisition, tracing and patch tools,
installed harness Rune/VM, and the selected corpus compiler artifact (including
its matching VM for a Rune subject).
Each attempt has fresh source/build directories and per-case logs and generated
reproducers under `build/suites/`. The quick and expanded selections share only
the verified archive cache and unchanged oracle inputs, not mutable work trees.

## Oracles and patches

| Source | Checked verdicts | Coverage |
| --- | ---: | --- |
| List | 41 | Traversals, ordering, exceptions and folds |
| Vector | 32 | Immutable values, slices, bounds and map order |
| String | 40 | Operations, scanning and escaping |
| Array | 78 | Mutable identity, copying, indexed folds and updates |
| ListPair | 13 | Unequal lengths, traversal order and folds |
| StringCvt | 10 | Padding, scanning, backtracking and file streams |
| Substring | 68 | Slicing, extreme bounds, spans and tokenization |
| Word8Array | 44 | Byte array identity, slices and overlapping copies |
| Word8Vector | 32 | Byte vectors, slices and indexed maps |
| Word8 | 253 | Conversions, bit shifts, modular arithmetic and radix scanning |

Every active `test...` declaration has an explicit validator. Each must return
`OK`; list-valued Word8 tests must also have the reviewed number of elements.
`WRONG`, `EXN`, a compiler/runtime error, timeout or absent completion marker
fails the case. No output from a candidate compiler establishes the expectation.
Commented-out upstream tests remain excluded and are not counted.

Four ordered patches are recorded:

1. The shared List patch calls the previously unapplied test assertion.
2. The shared Vector patch handles `maxLen + 1` when it cannot be represented.
3. `array-limits.patch` makes the same correction for Array, Word8Array and
   Word8Vector: accept `Overflow` only when `Int.maxInt = SOME maxLen`.
   Otherwise a length above `maxLen` must still raise `Size`. See the
   [Array contract](https://smlfamily.github.io/Basis/array.html) and
   [monomorphic array contract](https://smlfamily.github.io/Basis/mono-array.html).
4. `word8-hex-prefix.patch` corrects two inconsistent upstream expectations for
   `"0w1"` in hexadecimal scanning: the valid prefix is `"0"`, so the value is
   zero. A hexadecimal word prefix requires an `x` or `X` after `0` or `0w`.
   Decimal, octal and binary scanning still accept `0w1` as one. See the
   [Word scanning grammar](https://smlfamily.github.io/Basis/word.html).

The remaining 21 upstream Basis files are excluded from this selection: they
include platform-specific filesystem/path behavior, clock-dependent tests,
fixed integer/word widths, floating-point assumptions, interactive or diagnostic
output, and optional structures. Their assertions need a separate oracle and
portability review. This is an explicit selection, not a claim that those tests
are unsupported by all compilers.

## Results and cost

The first full selection passed with installed Rune and both SML/NJ versions.
MLton passed nine cases and retained the known String failure. Poly/ML passed
eight cases and failed extreme Substring bounds and hexadecimal Word8 scanning.
See [investigated differences and reproducers](known-differences.md). These
failures remain visible; no compiler-specific expectation is weakened.

Each case has a 120-second
process deadline and the suite command has a 1,500-second deadline. Traced
lifecycle duration includes setup, artifact verification and compilation; it is
not a compiler benchmark. Exact attempts, outcomes and observed costs belong
in the repository's implementation notes.

Initial traced whole-attempt costs on the development WSL2 host were about
45 seconds for Rune, 57 seconds for modern SML/NJ, 31 seconds for legacy SML/NJ,
192 seconds for MLton and 22 seconds for Poly/ML. Other validation was active
for some runs; these are planning estimates, not performance comparisons.

Both corpus Rune commits `b5ec8c8833e906cd3fe636a49e20b7c8474596dc` and
`e840204151663baf1139c8096b566301e9ced37d` passed their selected downstream
checks on 2026-09-25. See [versioned Rune results](../../../../../../RESULTS.md#versioned-rune-results)
for the exact artifacts, suite outcomes and manual reruns.
