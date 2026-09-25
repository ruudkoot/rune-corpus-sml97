# HaMLet 2.0.1

HaMLet is an interpreter for Standard ML. It exercises parsing, elaboration,
modules, evaluation and an interpreted Basis, making it a substantial downstream
application beyond the bootstrap compilers and small harness fixtures.

The [official release page](https://people.mpi-sws.org/~rossberg/hamlet/) lists
2.0.1, released 2025-07-27; checked 2026-09-24. Recipes pin the official source
tarball, including generated parser sources, at SHA-256
`819f3c90bf253df54a23ec074caf6859162004331a713f754393e25f87917b67`.
The digest was computed from the HTTPS download; no separate published checksum
was found. See upstream `LICENSE.txt` and the bundled library's license.

## Build paths

`polyml.record` uses upstream `make with-poly` with an exact corpus-built Poly/ML
5.9.2. `rune.record` uses upstream `make hamlet-bundle.sml`, then the selected corpus Rune compiler
compiles that bundle. Both preserve the upstream paths without source patches.
Make is explicitly given Bash because upstream commands use Bash-compatible
condition syntax. Native tools, command environments and file traces are recorded.
The generated parsers are supplied by the pinned archive; no system SML seed
or unpinned generator is selected.

Set `corpus_rune` to the absolute path of a validated Rune stage-2 artifact.

```sh
bin/corpus doctor packages/hamlet/2.0.1/rune.record amd64-linux
bin/corpus test packages/hamlet/2.0.1/rune.record amd64-linux "$corpus_rune"
bin/corpus test packages/hamlet/2.0.1/polyml.record amd64-linux PATH/TO/STAGE2/artifact.record
```

Use `fetch`, `patch` or `build` to stop earlier, following the normal lifecycle.
Only the initial x86-64 Linux paths are being validated. The upstream MLton and
SML/NJ build paths remain available in source, but have no corpus recipe here yet.

## Tests and interpretation

The owned smoke program checks factorial 10 and a list fold with explicit
expected values. Its initial version incorrectly assumed the interpreted Basis
provided `IntInf`; both builds rejected that test. The corrected smoke uses
portable `int` arithmetic. This changes the owned test contract, not HaMLet's
implementation or upstream assertions. Failed attempts are retained.

Six upstream conformance cases then run separately: `id`, `overloading`,
`flexrecord`, `fun-infix`, `withtype` and `where`. They cover identifiers,
overloading, flexible records, infix function clauses and module type constraints.
Upstream `test/CONFORMANCE.txt` classifies these as accepted programs that should
execute without an exception. Its compiler/version comparison is historical,
not a claim about current reference releases. Ambiguous, warning-only and
known problematic cases are excluded from this initial selection.

HaMLet can report an interpreted error while returning process status zero.
Each upstream case is followed by an owned completion-marker file in the same
invocation. Its file-processing loop stops after an error, so the marker and a
successful process exit are both required. The smoke prints its own marker only
after its assertions pass. Compilation success alone is never package validation.

These seven checks are an initial correctness selection, not a large complete
conformance suite. Fresh Rune and Poly/ML builds both passed all seven checks
after the smoke correction. Build commands have a 900-second timeout;
individual tests have 600 seconds. Measured costs and passed attempt identities
will be recorded in [implementation notes](../../../docs/implementation.md).
