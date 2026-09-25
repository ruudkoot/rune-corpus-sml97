# Implementation checkpoint

M0 is complete for the initial Linux adapter. The repository is the working location; do not develop in a
separate temporary checkout. Preserve the user's staged ROADMAP.md and do not
stage or commit unrelated changes automatically.

## Components

- `lib/record.sml`: strict, canonical versioned records.
- `lib/files.sml`: filesystem and record persistence; unique attempt directories.
- `lib/process.sml`: direct argv execution, independent stdout/stderr files,
  deadlines and subprocess-group termination. An external timeout provides a
  bounded fallback when the harness itself is interrupted.
- `lib/digest.sml`: SHA-256 adapter; tools run through the same process recorder.
- `src/provenance.sml`: per-attempt system inventory and installed Rune files.
- `src/artifact.sml`: file manifests, content verification and bootstrap-stage
  selection guards for compiler artifacts.
- `src/doctor.sml`: recipe prerequisite checks.
- `src/recipe.sml`: package metadata and argument substitution.
- `src/lifecycle.sml`: verified acquisition through build/test with failure records.
- `src/report.sml`: attempts, records, and streaming log search.
- `src/harness_test.sml`: Rune-driven cross-check adapters for corpus-built
  SML/NJ, MLton and Poly/ML. These await their validated compiler artifacts.
- `src/main.sml`: command dispatch. `sources.txt` excludes this entry point so
  tests and later reference-compiler adapters can share the same implementation.

## Validation so far

Rune-built core and fixture tests pass from this repository. A full run on
2026-09-23 produced `_work/tests/1790145168709696-3640D7-1`. They checked record
round trips and rejection, literal arguments, failed command statuses, separate
stdout/stderr, timeout versus exit 124, large failing output, retries, SHA-256's
known `abc` vector, acquisition verification, fresh patching, variant isolation,
and a complete Rune compile/run lifecycle, interrupted-harness evidence and
orphan cleanup, missing executable evidence, and stable/distinct specification
IDs. Further edits require rerunning `bin/test`; earlier results do not validate
later edits. Initial historical evidence is in `_work/initial-validation/`.

## Current integration work

- Exercise the prepared cross-check adapters once M1–M3 supply compilers.
  Do not use installed seed compilers for tests.
- Complete stage 2 and upstream/downstream validation for both SML/NJ versions.
- Add recurring-failure grouping and richer result comparison during M4.
- Keep native provenance gaps explicit. File traces and post-execution system
  hashes are available, but full reproducibility is not claimed and builds are
  not reused from cache.

`bin/build && bin/test` also passed from the source-only copy
`_work/clean-validation/m0-20260923-1`, created without existing downloads or
artifacts. Its `build.log` and `test.log` record M0 acceptance validation.

## Release research

SML/NJ 2026.2 (latest official development release) is pinned under
`packages/smlnj/2026.2/`. Its first stage-1 attempt at
`_work/attempts/1790145223628426-365DB5-1` passed its LLVM/runtime build and
smoke test. CMake 3.28.3 is installed. No installed SML seed is used in this route.

This initial attempt predates compiler manifest and command-plan additions. Its
`bootstrap-artifact.record` is a separate, verified post-attempt snapshot produced
by `_work/research/register-initial-smlnj.sml`; the original records are unchanged.
Its initial native build was not traced, and that provenance gap remains explicit.
Stage-2 attempts preserve missing-tool and library-installation failures. The
current modern attempt is `_work/attempts/1790179042892923-3B3B1B-1`.

Legacy **110.99.9** stage 1 passed at
`_work/attempts/1790178643595942-3B2171-1`. Stage 2 initially exposed the upstream
`cmb-make` launcher returning success after a missing `pgraph` dependency. The
recipes now pin that archive and use a driver that propagates a false CMB result.
A fresh stage-2 attempt is `_work/attempts/1790179540943070-3C272F-1`.
Both branches retain their separate compiler family/version/ancestry records.

MLton **20241230** recipes model one explicit bootstrap generation per attempt
with `BOOTSTRAP_STYLE=0`. Stage 1 snapshots `/usr/bin/mlton` and `/usr/lib/mlton`
as an external seed restricted to bootstrap use. Stage 2 accepts the resulting
corpus artifact. Initial failures identified native commands omitted from the
restricted PATH; corrected recipes are running at
`_work/attempts/1790179539827663-3C2640-1`.

Poly/ML **5.9.2** recipes use bundled boot files for stage 1, then a fresh native
runtime and exact stage-1 compiler for stage 2. The latter includes upstream
positive/negative compilation tests. Stage 1 has started; no Poly/ML validation
is claimed yet.

The separately maintained SML/NJ regression sources are pinned for research to
commit `95b939dd312452654abf74f9f327842de1a31f62` (2026-09-02). Its archive lacks
both the expected-output directories and `openbugs` files described by its
README. Do not manufacture reference outputs from the compiler under test.
Use reviewed semantic oracles for selected source tests or locate authoritative
expected outputs before claiming regression validation.

The expanded Rune test suite passed at
`_work/tests/1790145976459997-37A30C-1`, including artifact tampering/selection,
system tracing, blocked dependencies and evidence exports. A preceding run
exposed a fixture race when interrupting before the running record was written;
the fixture now waits for both partial output and the running record.

- https://smlnj.org/
- https://www.mlton.org/Release20241230
- https://www.polyml.org/download.html

## 2026-09-24 checkpoint

Both SML/NJ stage-2 builds and harness cross-checks passed; see
`docs/compiler-compatibility.md` for exact evidence. A fresh modern stage-2 run
with the explicit CMB failure driver is running at
`_work/attempts/1790221321440436-1B95F3-1`. The shared semantic suite passed
113 upstream List/Vector/String checks with both versions and Rune. It keeps
per-case verdicts and generated reproducers, and continues independent cases.

MLton retry `_work/attempts/1790220837785388-1B5DD6-1` builds auxiliary tools with
the newly built compiler, avoiding missing optional libraries in the installed
seed. Poly/ML retry `_work/attempts/1790220838900951-1B5E27-1` fixes the declared
installation manifest root; its preceding native build succeeded but registration
failed because Poly/ML installs headers under lib/polyml, not an include directory.

The current framework adds compiler-family/version/target compatibility guards,
more informative I/O failures, nested suite-log exports and fixed Rune paths
inside isolated environments. `bin/test` is running with semantic-suite failure
fixtures; final reference cross-checks must be repeated after these changes.

## Checkpoint (2026-09-24, about 03:56 UTC)

User requested LSP support: `bin/build` now generates ignored `corpus.mlb` from
`sources.txt`, Basis and main. Build passed and generated file was inspected.
M1 is marked complete. M2 MLton stage 1 is still running at
`_work/attempts/1790220837785388-1B5DD6-1` (session 41475); native build under
strace is slow. Its corrected stage-2 recipe is ready and includes six upstream
regressions, parallel native runtime compilation, and a TMPDIR patch.

Poly/ML stage 2 passed at `_work/attempts/1790221432942235-1B9E51-1`, including
273 upstream verdicts. The harness cross-check passed at
`_work/cross-checks/1790222008700687-1BE06B-1`; the common 113-check suite passed
at `_work/attempts/1790222038149434-1BE489-1`. The full audit and documentation
for M3 still need completion, and MLton remains its final reference dependency.

New `Program` adapter in `src/program.sml` builds owned Program.main applications
with Rune, SML/NJ heap export, MLton or Poly/ML polyc. It compiles and participates
in the passed Poly/ML harness cross-check, but its build paths have not yet been
exercised. `experiments/stackvm/` supplies generator/interpreter sources for
independent builder dimensions; planning/measurement remains unimplemented.

The next larger downstream candidate is HaMLet 2.0.1 (official release 2025-07-27,
verified 2026-09-24 at https://people.mpi-sws.org/~rossberg/hamlet/). It supports
all three reference compilers and offers a substantial SML interpreter workload.
Archive acquisition, recipe and Rune compatibility work remain to be done.

`Report` now supports failures grouping and attempt comparison; bundles include
nested suite results/logs/generated SML. `_work/rune-suite-launcher-failure.tar.gz`
was exported and inspected. Record encoding uses merge sort and indexed-list
reading uses a single collection pass to avoid quadratic artifact-manifest work.
`bin/test` passed after those changes. Modern and legacy cross-checks also passed
at `_work/cross-checks/1790221819842637-1BCF05-1` and
`_work/cross-checks/1790221821016065-1BCF2E-1`.

## Checkpoint (2026-09-24, manual introduction)

[The user manual](../README.md) now explains concepts, every implemented command and
complete workflows. Repository instructions require updates alongside behavior
changes. CLI help now includes `program`, `execute` and the internal `run-suite`
adapter. Earlier checkpoints above describe historical states.

MLton stage 1 passed at `_work/attempts/1790220837785388-1B5DD6-1`.
Stage 2 is running at `_work/attempts/1790261891601556-2AF41F-1`; it has completed
native runtime preparation and is compiling the compiler. No final stage-2
validation or MLton harness cross-check is claimed yet. The fresh modern SML/NJ
stage-2 attempt `_work/attempts/1790221321440436-1B95F3-1` also passed.

Owned program build paths were exercised: the Rune-built stack generator
`_work/programs/1790222240982325-1BEDAD-1/artifact.record` produced input consumed
by both Poly/ML-built `_work/programs/1790222267534657-1BEF1A-1/artifact.record`
and SML/NJ-built `_work/programs/1790222268702590-1BEF81-1/artifact.record`
interpreters. Both produced the mathematical result 1015050 for N=100, repeated
three times. Planner and timing work remain unfinished.

HaMLet 2.0.1 recipes and source pin are present. Initial Poly/ML attempt
`_work/attempts/1790262132626175-2B003B-1` and Rune attempt
`_work/attempts/1790262133749985-2B00A9-1` built their outputs but failed the smoke
oracle: HaMLet's interpreted Basis does not provide the `IntInf.int` used by
the owned smoke program. This is a test-contract issue to investigate; no
validated HaMLet support is claimed. Both failures and full logs are preserved.

Manual validation: the rebuilt harness and expanded CLI help passed. All local
manual links, twelve shell examples' syntax and documentation of seventeen
implemented command forms were checked. The first-run Rune suite example passed
at `_work/attempts/1790263049856920-2B1D57-1`; the generator/interpreter example
again produced 1015050, with runtime evidence at
`_work/program-runs/1790263124962942-2B1F3A-1`.

HaMLet correction validated: Poly/ML attempt
`_work/attempts/1790263229049107-2B20D9-1` and Rune attempt
`_work/attempts/1790263229038501-2B20D5-1` both passed the smoke and six upstream
conformance cases. The Poly/ML attempt took about 37 seconds on the current
host with other builds active; these traced durations are not benchmark samples.
The owned smoke now uses factorial 10 within the portable integer range.

`Graph` is linked into the harness and its tests. Rune's full harness suite
passed with graph ordering, shared dependencies, cycles, missing nodes and
conflicting identities checked; evidence `_work/tests/1790263357203497-2B2C0E-1`.
The experiment planner source was initially implemented separately; subsequent
validation and the now-available CLI are recorded below.

## Checkpoint (2026-09-25, profiles and expanded coverage)

M0–M3 are complete for the initial Linux adapter. MLton stage 2 passed at
`_work/attempts/1790261891601556-2AF41F-1`; the final compiler identities and
reference cross-checks are in `docs/compiler-compatibility.md`. Earlier entries
above describe historical progress, not current support.

At the user's request, `MANUAL.md` became `README.md`, with a project introduction
and quick start for GitHub. The old README's historical evidence location is
preserved in `docs/evidence.md`; setup, process and storage guidance remain in
the manual. Repository instructions and CLI help now name README.md.

The installed Rune/VM were replaced externally on September 24 while still
reporting version 0.3.0. The previous harness bytecode failed with an unsupported
bytecode version. It was retained at
`_work/harness-history/f42b5e76549d7f33c62b5fcd8f8ea4901bc09f5a413599669948125eaebfec3d.rbc`,
and `bin/build` regenerated the harness with the current installation. This is
why recorded content identities matter in addition to a version string. No
changes were made to the Rune repository.

The common suite now handles the unrepresentable `Vector.maxLen + 1` case.
Fresh results passed for Rune, both SML/NJ versions and Poly/ML; MLton retains a
real `String.fromCString` failure. Its standalone reproducer and exported logs
are described in the regression package's `known-differences.md`.

The first benchmark matrix completed eight configurations at
`_work/experiments/1790264092134613-2B5768-1`. It demonstrates independent Rune/
Poly/ML generator builders and Poly/ML/SML/NJ runtime builders, shared dependencies,
correctness gates and five retained samples per configuration. The very short
samples and possible competing work make it functional validation only. The
demo now requests 5,000 workload repetitions per runtime invocation; a separate
validation of longer timings follows. Extra compiler argument bindings are
supported for Rune and MLton, with explicit exclusions for other adapters.
Harness tests cover sharing, source invalidation, flag identity and exclusions.

The quick profile passed from the source-only copy
`_work/clean-validation/m6-quick-20260924-1`, with no existing caches or reference
artifacts. Result:
`_work/clean-validation/m6-quick-20260924-1/_work/profiles/1790286640847256-3BA8AB-1/result.record`.
The first regression profile at `_work/profiles/1790286599044504-3B9847-1`
retained the MLton failure and an orphan-process fixture timing failure under
Poly/ML. Its raw log shows the timeout helper eventually signaled the orphan,
just after the fixture's fixed sleep. The fixture now polls that observable
signal with a 15-second real-time deadline. A full regression retry is running.

The expanded Basis suite is independently versioned under
`packages/smlnj-regressions/95b939d/suites/basis-expanded/1/`. It reviews 611
verdicts in ten upstream source files. Rune passed at
`_work/attempts/1790295268514161-AD692-1`; SML/NJ 2026.2 passed at
`_work/attempts/1790295268598622-AD6B2-1`. MLton attempt
`_work/attempts/1790295268662436-AD6BB-1` passed all cases except the already known
String failure. Poly/ML attempt `_work/attempts/1790295268570277-AD6AA-1`
retains failures for extreme Substring bounds and hexadecimal Word8 scanning.
Reduced reproducers are being validated; no expected failure is normalized into
a pass. Array length and two inconsistent upstream Word8 expectations have
minimal documented corrections based on the Basis contract.

Expanded legacy SML/NJ validation also passed all 611 verdicts at
`_work/attempts/1790295470716002-B2BC3-1`. Poly/ML's reduced programs were built
at `_work/programs/1790295488561264-B3250-1` (substring bounds) and
`_work/programs/1790295489808079-B331A-1` (word prefix). Runs
`_work/program-runs/1790295565394354-B4FD7-1` and
`_work/program-runs/1790295565428817-B4FEE-1` reproduced both failures with exit 1.
The exported suite bundle `_work/polyml-592-expanded-basis-failures.tar.gz` keeps
the generated full-case reproducers and raw logs.

The updated quick profile passed in a second source-only copy,
`_work/clean-validation/m6-final-20260925-1`, at profile
`1790295717536721-B8CB9-1`. Its recorded duration was about 86 seconds on this
host while another correctness run was active. The copy had no reference
artifacts or acquired source cache; it built the harness and generated
`corpus.mlb` using the installed Rune, then fetched and passed the portable suite.
The final 16-task regression validation is at
`_work/profiles/1790295957978059-BC833-1`; its expected non-passing tasks are
MLton's two suite selections and Poly/ML's expanded suite.

## Final acceptance (2026-09-25)

M0–M6 are complete for the initial Linux implementation and documented adapter
scope. This records completion of the framework and repeatable outcomes, not
universal compiler conformance or reproducible performance rankings.

| Profile | Outcome | Observed duration | Evidence |
| --- | --- | --- | --- |
| quick | passed | 86 seconds | `_work/clean-validation/m6-final-20260925-1/_work/profiles/1790295717536721-B8CB9-1` |
| regression | 13 tasks passed; 3 documented failures | 914 seconds | `_work/profiles/1790295957978059-BC833-1` |
| long | passed | 151 seconds | `_work/profiles/1790296968590004-D73F7-1` |

The quick run used a fresh source-only copy without acquired archives or reference
artifacts. The regression and long profiles used the exact compiler bindings in
`_work/research/profile-bindings.record`. Compiler bootstraps are excluded from
these durations. The benchmark ran after the preceding corpus work finished.

| Regression task | Outcome | Child attempt or cross-check |
| --- | --- | --- |
| hamlet-poly | passed | `_work/attempts/1790296532919200-CA5D0-1` |
| hamlet-rune | passed | `_work/attempts/1790296293407717-C15A3-1` |
| legacy-expanded | passed | `_work/attempts/1790296624964153-CBB05-1` |
| legacy-harness | passed | `_work/cross-checks/1790296068656486-BF17D-1` |
| legacy-suite | passed | `_work/attempts/1790296238950240-C0F39-1` |
| mlton-expanded | failed | `_work/attempts/1790296657868178-CC502-1` |
| mlton-harness | passed | `_work/cross-checks/1790296118447098-BFA36-1` |
| mlton-suite | failed | `_work/attempts/1790296247064375-C10B6-1` |
| modern-expanded | passed | `_work/attempts/1790296586013171-CAB0B-1` |
| modern-harness | passed | `_work/cross-checks/1790295975519293-BCBFD-1` |
| modern-suite | passed | `_work/attempts/1790296228036360-C0D59-1` |
| poly-expanded | failed | `_work/attempts/1790296852987909-D0EE2-1` |
| poly-harness | passed | `_work/cross-checks/1790296175545172-C041E-1` |
| poly-suite | passed | `_work/attempts/1790296288957253-C148A-1` |
| rune-expanded | passed | `_work/attempts/1790296569194943-CA960-1` |
| rune-suite | passed | `_work/attempts/1790295960338196-BC8B6-1` |

Each harness cross-check matched 57 ordered PASS verdicts between Rune and its
reference and required both completion markers. The three failing tasks contain
exactly the investigated String case for MLton and Substring/Word8 cases for
Poly/ML; all other cases passed. The profile retained their nonzero outcomes
and continued every independent task.

Benchmark acceptance also passed:

- Compiler-option binding: `_work/experiments/1790296872991917-D239E-1`.
- Wrong answer with exit zero and missing binding: `_work/experiments/1790296917710101-D4D64-1`; invalid/unsupported, no measured samples or timing summary.
- Runtime timeout: `_work/experiments/1790296943226936-D6D8B-1`; invalid before measured samples, process status `timeout`.
- Long matrix: `_work/experiments/1790296971043505-D74A1-1`; eight valid configurations, 40 measured samples, eight correctness gates and eight warmups.

The two generator builders emitted identical instruction bytes for each size.
All 56 runtime records passed their mathematical oracle. The report retains
individual wall/user/system times and maximum RSS, four fresh program-build
observations, machine snapshots, exact compiler histories and rerun instructions.
The large within-configuration timing ranges and high recorded host load limit
interpretation; these records do not isolate the cause of the variation. No
compiler performance ranking is claimed. The earlier short matrix and this longer run
exercise fresh experiments with the same independently bound builder roles.

Known follow-ups are the documented reference-library differences, full Rune
compiler ports, additional platform/experiment adapters, stronger environment
control and broader application coverage. They remain explicit boundaries of
the completed initial roadmap. No files in the Rune repository were changed.

[RESULTS.md](../RESULTS.md) collects this acceptance snapshot, individual timing
samples, exact compiler selections, manual rerun instructions and prioritized
follow-ups. It distinguishes the main matrix's generator builders from its
interpreter builders: that matrix has no Rune interpreter row.

## R1: commit-versioned Rune bootstraps (2026-09-25)

Both requested Rune commits passed stages 1 and 2. Installed Rune remains the
harness builder/runner and preferred external bootstrap seed. Stage 1 retains
its complete seed compiler/VM/library manifest and a copied hosting VM; stage 2
uses the pinned commit's freshly built VM. Both stages pass the owned smoke.
Each stage 2 also recompiles itself to byte-identical compiler bytecode. No
upstream source patches or edits in the main Rune checkout were needed.

| Stage | Attempt ID under `_work/attempts/` | Whole attempt time |
| --- | --- | --- |
| b5.stage1 | `1790321872605236-276806-1` | 35.36 s |
| b5.stage2 | `1790321939792559-276E2F-1` | 43.51 s |
| e8.stage1 | `1790321939806686-276E37-1` | 41.68 s |
| e8.stage2 | `1790321998750242-2779D1-1` | 53.84 s |

The harness passed 59 fixture verdicts, including selection of a VM from
its Rune artifact and rejection of an outside runtime. The current workload
adapters still need migration to the new artifacts (R2); these bootstrap
results do not yet claim downstream or full upstream-suite validation.
