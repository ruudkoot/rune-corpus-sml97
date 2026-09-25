# Compiler build compatibility

**The corpus can build SML/NJ, MLton and Poly/ML, but none of their compiler
implementations is currently built with Rune.** Rune runs the harness that
invokes their existing bootstrap processes. Rune also compiles the harness,
both pinned Rune compiler versions, HaMLet and selected portable test programs.

In this document, a **Rune-hosted compiler build** means Rune compiles the other
compiler's SML sources. That route is unimplemented for all three reference
implementations. There is no working reduced-feature Rune-hosted build of them
either. The dependencies listed below are porting requirements identified from
the pinned sources, not features switched off in an otherwise working build.
This assessment does not establish that such ports are impossible.

The tested host is native x86-64 Linux. Corpus-managed SML/NJ 2026.2 and legacy
110.99.9 coexist, each with its own sources, installation, manifest and bootstrap
parent. The stage-2 recipes accept only the matching compiler family, version and
target. System SML compilers are excluded from their child PATHs.

| Package | Implemented and validated bootstrap route | Rune-hosted compiler build |
| --- | --- | --- |
| Rune commits `b5ec8c8...` and `e840204...` | Installed Rune seed, followed by same-commit self-hosted stage 2 with a fresh matching VM | Supported; both stages, smoke and self-reproduction passed |
| SML/NJ 2026.2 | Bundled boot files plus GCC/LLVM runtime, then SML/NJ compiles SML/NJ | Not implemented; needs adaptation of CM/CMB, runtime services and the LLVM code-generation interface |
| SML/NJ 110.99.9 | Bundled boot files plus GCC runtime, then SML/NJ compiles SML/NJ | Not implemented; needs adaptation of CM/CMB, MLRISC integration, continuations and runtime services |
| MLton 20241230 | Installed MLton compiles stage 1; that MLton compiles stage 2 | Not implemented; needs a Rune source-list/host-service adapter and Basis coverage validation |
| Poly/ML 5.9.2 | Bundled bootstrap image, then Poly/ML compiles Poly/ML with a fresh native runtime | Not implemented; needs adaptation of the compiler namespace, runtime calls and native export mechanism |

These describe compiler **builds**. Portable programs from the SML/NJ regression
repository do compile and run with Rune; that does not establish that Rune can
build the SML/NJ compiler itself.

The stage-2 recipes enforce these routes: SML/NJ requires a matching SML/NJ
artifact, MLton a matching MLton artifact, and Poly/ML a matching Poly/ML
artifact. A Rune artifact is rejected for each. Harness cross-checks compile
the harness test sources independently with these compilers and compare their
verdicts with Rune's; they do not compile one compiler with another. Basis-suite
failures are separate correctness findings about the resulting compilers.

## SML/NJ assessment

The pinned legacy sources' `base/compiler/TopLevel/interact/evalloop.sml` use
`SMLofNJ.Cont.callcc` and profiling/monitor internals. Its printer uses
`Unsafe.cast` and `Unsafe.Object` to inspect runtime values. Its compiler bootstrap
depends on CM/CMB path anchors, stable libraries, primitive bindings and an SML/NJ
heap image. The development version's `compiler/CodeGen/main/code-gen-fn.sml`
also invokes its LLVM generation layer, backed by the dedicated native runtime.

Rune consumes SML sources and produces Rune bytecode. The
SML/NJ runtime representations, heap exporter and code-generation interface
cannot be provided by changing source ordering alone. A CM-to-source adapter
would help isolate portable front-end modules but would not supply these runtime
services. Replacing unsafe object inspection, continuation-based interaction and
code generation is substantial porting work, so no full Rune port is claimed.

Minimal useful changes are confined to this corpus: invoke CMB through an
explicit success/failure driver, pin CM's `pgraph` dependency for legacy, isolate
native tools, and wrap portable regression modules with semantic validators.
Those changes preserve upstream self-build paths. A future front-end-only Rune
experiment should identify a module boundary and a portable input/output oracle
before attempting a full compiler port. Changes to `../rune` require human
confirmation under the roadmap's repository-boundary rule.

## MLton assessment

The pinned release already supports alternative SML/NJ and Poly/ML bootstraps.
Its `lib/stubs/` tree adapts platform, process, resource-usage, GC, exceptions
and I/O services for those hosts. The generated `mlton/mlton-stubs.mlb` provides
an explicit source order, but starts with MLton's `unsafe.mlb`, `sml-nj.mlb` and
`mlton.mlb` bindings. Rune cannot consume that list unchanged. Compiler
`main/main.fun` uses `MLton.Platform`, `MLton.Rusage` and `MLton.GC`; the existing
alternative-host stubs show where a Rune adapter should begin.

Required work is a recorded source-list/Basis adapter, Rune equivalents or
explicitly justified stubs for those services, and validation of the complete
compiler build. Native runtime/tool builds would still use recorded GCC and
binutils. This assessment does not establish a fundamental obstacle or claim a
full Rune port: the smaller host-adapter route remains unimplemented and untested.
The verified self-bootstrap route is preserved. HaMLet and the portable suites
provide downstream Rune coverage without claiming a Rune-built MLton.

## Poly/ML assessment

`bootstrap/Stage6.sml` invokes `PolyML.make`, builds a compiler global environment
and uses `MLCompiler.useIntoEnv` to construct the Basis and export the next stage.
`basis/InitialPolyML.ML` implements native export through
`RunCall.rtsCallFull2 "PolyExport"`; `mlsource/MLCompiler/INITIALISE_.ML`
installs runtime primitives including `unsafeCast` into the compiler environment.
Changing source order cannot supply those runtime representations and services.
A Rune-hosted Poly/ML compiler/export route therefore needs a separate runtime
and compiler adapter project. No small source patch or completed Rune port is
claimed. HaMLet is a validated downstream application on both systems; Isabelle
and its formalizations remain a larger future integration requiring separate pins.

## Validation evidence

SML/NJ 2026.2 stage 2 passed at `_work/attempts/1790179042892923-3B3B1B-1`.
Legacy stage 2 passed at `_work/attempts/1790179540943070-3C272F-1`.
Harness cross-checks passed at `_work/cross-checks/1790179799992411-3C9180-1`
and `_work/cross-checks/1790220962463541-1B708D-1`, respectively. Later harness
changes require fresh cross-checks; these paths document the versions tested.

The 113 reviewed upstream List/Vector/String checks passed with modern SML/NJ at
`_work/attempts/1790221128425402-1B8A36-1`, legacy at
`_work/attempts/1790221152023480-1B8D7B-1`, and installed Rune at
`_work/attempts/1790221236856536-1B912A-1`. Each program is generated, compiled
and executed through the shared suite adapter. The three generated programs also
exercise downstream compilation without system SML seed selection.

Modern's first stage-1 native build predates file tracing. Its separate verified
bootstrap manifest explicitly records that gap; original evidence is retained.
Later builds trace system-file use, but even these do not establish hermetic or
byte-identical reproducibility. Self-builds took approximately 11–12 minutes on
this host after the modern LLVM bootstrap; regression subsets took seconds.
These are observed correctness-run costs, not controlled benchmark results.

The current modern recipe, including its explicit CMB failure driver, passed a
fresh stage-2 build at `_work/attempts/1790221321440436-1B95F3-1`. Updated harness
cross-checks passed at `_work/cross-checks/1790221819842637-1BCF05-1` (modern)
and `_work/cross-checks/1790221821016065-1BCF2E-1` (legacy). M1 is complete.

Poly/ML stage 2 passed at `_work/attempts/1790221432942235-1B9E51-1`, reporting
273 upstream test passes. Its retained runner treats `NotApplicable` as success,
so this count is the upstream verdict count. Stage 2's make step did not repeat
bootstrap stages 1–5: the exact stage-1 compiler ran stages 6–7 against fresh
sources and a newly built native runtime, then make linked that exported object.

MLton stage 1 passed at `_work/attempts/1790220837785388-1B5DD6-1`; stage 2 at
`_work/attempts/1790261891601556-2AF41F-1` passed its smoke program and the six
selected upstream regressions. The latter took about 30 minutes including
provenance tracing and inventories on this host. The harness cross-check passed
at `_work/cross-checks/1790264092098356-2B5747-1`; Poly/ML's updated cross-check
passed at `_work/cross-checks/1790264092116371-2B575F-1`. Modern and legacy SML/NJ
passed at `_work/cross-checks/1790263874724469-2B3F2B-1` and
`_work/cross-checks/1790263874741855-2B3F34-1`. These validate the graph/experiment
modules as part of the harness source; later changes require further checks.

The stage-2 trace audit for all four artifacts found no executed `/usr/bin/sml`,
`/usr/bin/mlton` or `/usr/bin/poly`, and no accesses under `/usr/lib/smlnj` or
`/usr/lib/mlton`. Compiler recipes constrain family/version/target, restrict PATH
and supply exact parent artifacts. This is evidence within the recorded trace
coverage, not a filesystem sandbox. Shared selection, process, inventory and
manifest code remains in the framework; bootstrap-specific commands stay in recipes.

The common subset finds an actual MLton `String.fromCString` discrepancy and
initially found a vector-test range assumption. See the
[investigated differences](../packages/smlnj-regressions/95b939d/known-differences.md).
MLton's complete subset is deliberately reported as failed; neither its successful
bootstrap nor its harness cross-check overrides that result.

## Original acceptance profile harness cross-checks (2026-09-25)

All four reference selections passed that acceptance run's harness fixtures, including
experiment sharing/flag identity and the corrected bounded orphan-timeout check:

| Selection | Cross-check directory under `_work/cross-checks/` |
| --- | --- |
| SML/NJ 2026.2 | `1790295975519293-BCBFD-1` |
| SML/NJ 110.99.9 | `1790296068656486-BF17D-1` |
| MLton 20241230 | `1790296118447098-BFA36-1` |
| Poly/ML 5.9.2 | `1790296175545172-C041E-1` |

These compare ordered fixture verdicts and require the completion marker from
both Rune and the reference. They are distinct from downstream Basis conformance:
the expanded Basis suite retains documented MLton and Poly/ML differences.
Later cross-checks covering both corpus Rune commits and all four reference
selections are in [versioned Rune results](../RESULTS.md#versioned-rune-results).
