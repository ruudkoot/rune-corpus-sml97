# rune-corpus-sml97 roadmap

## Purpose and current state

Build a corpus of Standard ML '97 software for checking Rune's
correctness and comparing compile-time and run-time performance with other SML
compilers. The repository owns the recipes, patches, framework, and experiment
definitions needed to rerun experiments and explain their results, including how
every compiler and runtime involved was built. Improve reproducibility through
recorded inputs and repeatable procedures, while recognizing that full
reproducibility is unlikely to be achievable within this roadmap.

M0–M6 are complete for the initial Linux implementation, the validated SML/NJ
2026.2 and legacy 110.99.9, MLton 20241230 and Poly/ML 5.9.2 bootstraps, the
selected correctness suites and the `corpus-stack-1` benchmark adapter.
[Implementation notes](docs/implementation.md) record the acceptance evidence.
Completion includes repeatable failures: the regression profile preserves
investigated MLton and Poly/ML library differences and returns nonzero. It does
not imply that all compilers pass every test or that other operating systems and
arbitrary benchmark formats work. The reference bootstraps use upstream boot
files or an installed compiler of the same family, then rebuild with their own
compilers. Rune runs the harness that drives these builds. Building SML/NJ,
MLton or Poly/ML's compiler sources with Rune remains unimplemented; no full or
reduced-feature Rune-hosted build of those compilers is part of the completed
work. See [build compatibility](docs/compiler-compatibility.md) for the assessed
porting requirements.
Milestones below retain their original completion criteria and dependency order.

## Extension: versioned Rune compilers

The following milestones extend the completed initial roadmap:

- [x] R1: Pin both requested Rune commits, build validated stages 1 and 2,
  and record the installed bootstrap seed and matching runtime/library bundle.
- [x] R2: Select corpus Rune artifacts in suites, programs, experiments and
  harness cross-checks; update profile bindings and the manual.
- [x] R3: Validate both versions alongside the reference compilers, preserve
  results and manual reruns, and record any discovered compatibility failures.

All three extension milestones are complete. Both requested Rune commits passed
bootstrap, self-reproduction, harness cross-checks, shared/expanded suites and
HaMLet. The independent two-version benchmark matrix and failure-handling checks
passed acceptance. The reference regression retains the same three failing
tasks. See [RESULTS.md](RESULTS.md) for exact evidence and current reruns.

Commit after each completed milestone, following `AGENTS.md`.

## Project rules

- **Separate the harness from compiler subjects.** Installed Rune builds and
  runs the framework and remains the preferred initial Rune bootstrap seed.
  Record its compiler, VM and Basis identities. Rune under test is a corpus-built
  compiler, selected by its full source commit hash with its matching VM and
  library. The initial commits are `b5ec8c8833e906cd3fe636a49e20b7c8474596dc`
  and `e840204151663baf1139c8096b566301e9ced37d`. Cross-check the harness with
  these artifacts as well as SML/NJ, MLton and Poly/ML.
- **Keep repository boundaries clear.** `../rune` is a reference and an eventual
  consumer of this corpus. Normal corpus work must not require edits there.
  If a compiler or library bug needs a Rune change, preserve a reproducer and
  request human confirmation before editing `../rune`, where other work may be
  ongoing. Continue independent corpus work while the fix is pending.
- **Write the framework in SML '97.** Put reusable functionality beyond Basis
  in `lib/`, with explicit signatures and separate components for acquisition,
  processes, filesystem operations, metadata, builds, and results. Introduce
  abstractions as milestones need them. Shell scripts should be thin launch or
  framework-build wrappers. External download, archive, patch, and native build
  tools may be called through SML adapters; document and check these dependencies.
- **Commit recipes, not acquired sources.** Keep downloaded archives, extracted
  upstream sources, generated builds, and local results out of version control.
  Commit source identities, checksums, acquisition scripts, minimal patches,
  build and test recipes, and documentation.
- **Pin versions deliberately.** When adding software, find its latest official
  release and prefer an official source tarball. Record the release URL, version,
  checksum and checksum provenance. Document exceptions when a release archive
  is unavailable or an older version is intentionally selected. Normal runs use
  the recorded identity; they never silently resolve to a new release.
- **Allow multiple versions and variants.** Never identify a compiler or package
  solely by its name, and never overwrite one variant with another.
- **Keep compatibility claims explicit.** Support every compiler/version/variant
  combination declared by a recipe. Preserve existing upstream build paths when
  adding Rune support. Unsupported combinations must report a reason rather than
  silently substitute a compiler or change the workload.
- **Expect frequent failures.** Compiler bootstraps, package builds, patches,
  tests, and benchmarks will fail regularly. Capturing, preserving, and analyzing
  their evidence is core framework functionality from M0 onward.
- **Keep the manual current.** [README.md](README.md) explains implemented
  concepts, commands and workflows. Update it with behavior changes, distinguish
  experimental work from validated support, and keep CLI help consistent.

## Harness validation

The harness is built with Rune against Rune's Basis libraries and runs with the
installed `runevm`. Its own test suite must also compile and execute the harness
code with corpus-built SML/NJ, MLton, and Poly/ML to cross-check its behavior.
These reference builds are used for testing the harness; Rune continues to run
corpus orchestration.

Use the same source and controlled fixtures across the four compilers, with
narrow, documented adapters where library or platform interfaces differ. Check
metadata parsing, artifact selection, build plans, child-process handling,
failure classification, correctness verdicts, and report generation. Compare
against hand-reviewed expectations as well as against the other implementations.
Normalize only explicitly identified differences such as timestamps and paths;
retain the original outputs and logs for investigation.

Prepare this test suite in M0 and enable each reference configuration as its
compiler is bootstrapped in M1–M3. This avoids requiring corpus compilers before
the framework can bootstrap them. All three reference configurations must be
active by the end of M3. Cross-checking reduces the risk of a Rune bug affecting
the harness, but agreement alone does not establish correctness.

## Repository and recipe contract

The intended layout is:

```text
bin/                              thin framework launchers
src/                              corpus commands and orchestration
lib/                              reusable SML libraries
packages/<name>/<version>/         metadata, recipes, patches, README
  suites/<suite>/<version>/        separately acquired workload recipes
experiments/                      correctness and benchmark definitions
tests/                            framework tests and small owned fixtures
docs/                             schemas, usage, and contributor guidance
_work/                            ignored downloads, sources, builds, results
```

Variants live in versioned package metadata; create separate recipe directories
only when their contents differ. The framework should expose consistent
`doctor`, `fetch`, `patch`, `build`, `test`, `bench`, and `report` operations.
See [the manual](README.md) for the available interfaces. Lifecycle, report, profile and the initial stack-machine `bench` adapter are
implemented and validated. The benchmark remains a limited experimental adapter;
its measurement boundaries and supported combinations are explicit in the manual.

Every package, including the first three compilers, must provide:

| Deliverable | Required behavior |
| --- | --- |
| Metadata | Identify the upstream release, license, official source, digest, dependencies, variants, and supported build combinations. |
| Download script | Fetch the pinned source and verify its checksum before extraction or use; reuse only verified cached inputs. |
| Doctor script | Check the selected recipe's tools, compiler/runtime identities, native libraries, platform requirements, and bootstrap prerequisites; report missing items with actionable guidance. |
| Patch script | Apply a recorded, ordered set of minimal patches to a fresh work tree; handle repeated invocation predictably and reject unexpected source contents. Explicitly declare when no patch is needed. |
| Build script | Select an exact supported compiler artifact and variant, isolate outputs, record the system artifacts actually used, preserve logs for successful and failed attempts, and identify any produced artifact. |
| Tests | Define a smoke test and relevant upstream correctness tests, including how success is determined and why anything is excluded. |
| README | Explain the version, prerequisites, bootstrap/build steps, supported combinations, each Rune compatibility patch, limitations, and recommended test suites with their purpose and approximate cost. |

These scripts should dispatch to shared SML framework functionality rather than
duplicate orchestration in shell. A separately added suite follows the same
download/doctor/patch/build/documentation contract and records compatible parent
software versions, input identities, and its correctness oracle. For a theorem
prover, recommended suites should include substantial existing formalizations,
not only small startup examples.

## Reproducibility scope and system artifacts

Full reproducibility, including hermetic builds and byte-identical outputs across
machines or over time, is unlikely to be achievable within this roadmap and is
not a milestone completion requirement. System tools, libraries, operating-system
behavior, build nondeterminism, and hardware can affect results. The practical
commitment is to record what was used, make procedures repeatable, and expose
known differences and missing information when comparing results.

For every build attempt, including bootstrap stages and failed builds, record all
system artifacts used. Include the actual GCC or other native compiler version,
assembler and linker, build tools, shell, source-processing tools, system headers,
libraries, SDKs, and runtime dependencies as applicable. Capture resolved paths,
version output or package identities, relevant flags and environment settings,
and content digests where practical. A global doctor inventory is useful, but
each build must identify which tools and dependencies it actually selected.

Record the OS/kernel, architecture, and relevant machine configuration with
builds and runs. Report unidentified dependencies or incomplete provenance
explicitly. Include recorded system dependencies in build specifications and
cache decisions; if required identities cannot be established, rebuild rather
than assume an old artifact is compatible. Identical recorded inputs are not
proof of identical outputs, so retain output digests and separate build attempts.
Rerun instructions must state which external prerequisites need to be recreated.

## Failure capture and analysis

Every lifecycle step must leave evidence even when it fails or is interrupted.
Write records and logs incrementally, so diagnosis does not depend on the command
reaching its final reporting step. Give every attempt and step an ID linked to
its package, variant, compiler, build specification, and experiment.

Capture the executed command and arguments, working directory, relevant declared
environment, selected tool identities, start/end times, exit status or signal,
timeout/resource-limit reason, and stdout/stderr. Keep complete raw build logs
alongside concise summaries. Preserve partial outputs and the information needed
to locate or recreate the failed work directory; retries must create new attempt
records without overwriting earlier evidence. Document retention and cleanup
rules for large logs and failed work trees.

Provide tools to search logs, locate the failing step, group recurring diagnostic
signatures, compare attempts or compiler variants, and export a failure report
with rerun instructions. Summaries and grouping must link back to raw evidence;
an inferred cause must remain distinguishable from the observed failure.

Continue independent work after a failure where possible, mark dependent steps
as blocked, and distinguish infrastructure/build failures from test failures,
unsupported configurations, timeouts, and interruptions. Exercise this behavior
in the harness's own cross-compiler test suite, including large logs and child
processes that fail partway through a build.

## Artifact identity and bootstrap policy

Record build provenance from the first milestone. A compiler artifact must
identify its family, version, source and patch digests, build and target
platforms, word size, configuration, flags, libraries, runtime dependencies,
and the exact compiler artifact that built it. Attach the per-build system
artifact record described above. Give build specifications stable IDs derived
from their recorded inputs; identify produced artifacts by output digests and
retain their build attempts. A human-readable alias must resolve to a complete
record, even when repeated builds of the same specification differ.

For example, “compiler E” may mean a particular 32-bit Windows SML/NJ release
built by a particular MLton artifact. The model must represent that history
without assuming that this illustrative combination is actually supported.

SML/NJ, MLton, and Poly/ML are the preferred bootstrap compilers and the first
packages integrated here. Their verified bootstrap routes are documented in the
package READMEs and compatibility notes. Check the official bootstrap
documentation again before adding a release or a different route.

When an older installed SML compiler is needed, use these stages:

| Stage | Role | Permitted use |
| --- | --- | --- |
| 0 | Existing compiler outside the corpus, with its path and identity recorded | Build the initial stage-1 bootstrap artifact only. |
| 1 | Compiler built from a pinned corpus recipe using stage 0 | Bootstrap stage 2; validate it as needed for that purpose. |
| 2 | Compiler rebuilt from corpus sources using a corpus-built compiler | After validation, serve as a corpus compiler for packages, tests, and benchmarks. |

Stage 2 is mandatory whenever stage 0 is used. Its bootstrap inputs must come
from corpus-managed artifacts; preserve the stage-0 ancestry in provenance.
Record any upstream-required intermediate releases, boot images, or generated
bootstrap inputs explicitly. Do not disguise an external seed as a final corpus
compiler. If a project needs further stages, model and validate them too.

After bootstrap, remove stage-0 tools from compiler selection and verify normal
work with those tools unavailable. Native prerequisites remain allowed and
recorded. Installed Rune remains the harness compiler/runtime and initial Rune
seed; Rune subjects use corpus artifacts and their own VMs. Validate bootstrap
outputs with upstream checks and representative
programs; compare binaries byte-for-byte only where the build supports it.

## Milestones

| Milestone | Outcome | Depends on |
| --- | --- | --- |
| M0 | Working Rune-built framework, traceable recipe lifecycle, and failure capture | Installed Rune and required host tools |
| M1 | Validated SML/NJ bootstrap inside the corpus | M0 |
| M2 | Validated MLton bootstrap inside the corpus | M0; M1 if its verified bootstrap route needs it |
| M3 | Validated Poly/ML bootstrap inside the corpus | M0; M1/M2 if its verified bootstrap route needs them |
| M4 | Correctness comparisons and explicit Rune compatibility coverage | M0 and at least one validated reference compiler; all three for completion |
| M5 | Benchmarks with recorded provenance and independently selected build and runtime artifacts | M4 and the required artifacts |
| M6 | Larger workloads and a stable interface for Rune-driven runs | M5 |

The intended package order is SML/NJ, MLton, then Poly/ML. Adjust it if upstream
bootstrap requirements demand another order, and record the reason. Correctness
work can begin as soon as one reference compiler is available.

### M0 — Framework foundation

- [x] Establish the directory layout, ignored work directories, source ordering,
  and a documented way to compile the framework with installed Rune.
- [x] Define package, variant, artifact, bootstrap-stage, and result records.
  Include per-build system artifacts, attempt/step identities, and provenance
  gaps. Choose a versioned serialization format and document its required fields.
- [x] Implement the SML command dispatcher and the first reusable `lib/`
  components for process execution, diagnostics, paths, metadata, and digests.
- [x] Implement global and per-recipe doctor checks, verified fetching,
  isolated extraction and patching, explicit compiler selection, build logging,
  and a basic test runner. Capture statuses, timeouts, and failures consistently.
- [x] Implement incremental raw-log capture, failure summaries, log search,
  rerun instructions, and preservation of failed/interrupted attempts. Ensure
  retries do not overwrite evidence and failed dependencies block only their
  dependent work.
- [x] Establish the harness test suite with hand-reviewed fixtures and compiler
  adapters for cross-checking. Run it with Rune now; enable corpus-built SML/NJ,
  MLton, and Poly/ML as they become available in M1–M3.
- [x] Exercise the complete lifecycle with a small owned fixture before
  attempting a compiler bootstrap. Include a corrupt download, missing tool,
  repeated patch invocation, failed/interrupted build with partial and large
  logs, a retry, and conflicting variant identities.

**Complete when:** a clean checkout can build the framework with installed Rune,
diagnose prerequisites, and fetch, verify, patch, build, and test the fixture.
A repeated run safely reuses verified inputs, distinct variants cannot collide,
and every attempt has recorded system dependencies, an outcome, and useful logs.
The harness tests run with Rune, are ready for reference-compiler cross-checking,
and demonstrate that failures remain diagnosable after interruption and retry.

**Validation:** `bin/build && bin/test` passed in the working repository and in
an isolated source-only copy at `_work/clean-validation/m0-20260923-1`, with no
existing `_work` cache or artifacts. Its `test.log` contains the completion
marker and individual fixture verdicts. Coverage includes interrupted/failed
processes, artifact tampering and stage guards, blocked dependencies, raw-log
exports, system-file tracing and running with system SML seeds absent from PATH.
Native provenance retains explicit gaps; build artifacts are not cached.

### M1 — SML/NJ

- Integrate both development **2026.2** and legacy **110.99.9** (latest official
  releases verified on 2026-09-23). The legacy codebase is an additional required
  package version, requested by the user; neither version replaces the other.
  Keep the same `smlnj` family with distinct versions, bootstrap ancestry,
  installation manifests and test results.
- [x] Demonstrate both SML/NJ versions coexisting and selectable without output
  collisions. Run the harness cross-check under each validated version and retain
  their separate results. This brings the multiple-version acceptance test
  forward from M6.
- [x] Select and pin the latest official release at integration time. Cite its
  official source and bootstrap instructions in the package README.
- [x] Document supported host/target combinations, native prerequisites,
  implementation-specific dependencies, and the actual bootstrap route.
- [x] Supply the full recipe contract and complete stage 1 and stage 2 where
  an installed seed is needed. Register the validated final artifact explicitly.
- [x] Run upstream bootstrap checks and a representative regression subset.
  Prove the final compiler can build and run a small downstream SML program.
- [x] Add corpus-built SML/NJ to the harness's own cross-checking test suite and
  investigate differences from Rune and the fixtures' expected behavior.
- [x] Assess what is required to build SML/NJ with Rune, including build-system
  adapters and language/runtime dependencies. Record blockers and minimal patch
  candidates; do not assume self-bootstrap implies Rune compatibility.

**Complete when:** a clean recipe run produces a validated corpus-managed
SML/NJ compiler with complete bootstrap provenance, and downstream compilation
works with the external seed unavailable. The README documents its tested
variants, Rune compatibility status, and recommended larger suites. Harness
cross-checks pass with SML/NJ, with any permitted differences explicitly defined.

**Validation:** Both versions passed stage-2 bootstraps, harness cross-checks and
the 113-assertion upstream semantic subset. Exact evidence, provenance gaps and
Rune build blockers are in [compiler compatibility](docs/compiler-compatibility.md).

### M2 — MLton

- [x] Select and pin the latest official release and verify its documented
  bootstrap requirements, supported seeds, native dependencies, and targets.
- [x] Implement the full recipe contract, reusing the framework and extending
  shared abstractions only where the MLton integration needs them.
- [x] Complete the required bootstrap stages and validate the final compiler
  with upstream checks and a downstream SML program.
- [x] Add corpus-built MLton to the harness's own cross-checking test suite.
- [x] Record Rune build requirements, minimal compatibility patches or blockers,
  and a recommended selection of upstream regressions and larger workloads.

**Complete when:** MLton meets the same acquisition, provenance, validation, and
seed-independence criteria as SML/NJ. Both packages use the common lifecycle,
with compiler-specific behavior confined to their recipes/adapters. Harness
cross-checks pass with MLton as well as SML/NJ and Rune.

### M3 — Poly/ML

- [x] Select and pin the latest official release and verify its documented
  bootstrap route, native runtime build, dependencies, and supported variants.
- [x] Implement the full recipe contract and all required bootstrap stages.
- [x] Validate the final compiler with upstream checks and downstream programs;
  record compiler and runtime build identities separately where applicable.
- [x] Add corpus-built Poly/ML to the harness's own cross-checking test suite
  and run all four configurations, including failure capture and analysis cases.
- [x] Document Rune compatibility patches or blockers, and recommend larger
  suites or downstream applications suitable for subsequent integration.
- [x] Audit all three integrations for accidental selection of external seeds
  and extract duplicated reusable logic into `lib/` or shared framework modules.

**Complete when:** all three reference compilers can be rebuilt and used through
the common framework without external SML seeds after bootstrap. Versions and
variants coexist, and their actual support matrices are documented. The harness
test suite passes with Rune and all three blessed reference compilers; Rune
remains the harness runner.

### M4 — Correctness and Rune compatibility

- [x] Run a common portable SML '97 suite through installed Rune and each of the
  three corpus-built reference compilers, using the libraries selected and
  recorded for each configuration.
- [x] Add minimal Rune adapters and patches for supported package builds.
  Validate that the existing supported compiler builds still work after patching.
  Track full compiler ports separately when extensions, FFI, or runtime coupling
  prevent a small compatibility change; keep those builds visibly blocked.
- [x] Define expected output, exit status, or domain-specific oracles for every
  test. Use cross-compiler agreement as evidence alongside those oracles; allow
  only documented normalization or implementation-dependent expectations.
- [x] Distinguish passed, failed, unsupported, blocked, timed out, and not run.
  Attach reasons and reproduction steps to exclusions and known failures.
- [x] Preserve small reproducers for Rune failures and follow the confirmation
  rule before any fixes in `../rune`.
- [x] Extend failure analysis to group recurring failures and compare logs across
  compiler variants, with exportable reports linked to complete raw evidence.

**Complete when:** the common suite has repeatable results for installed Rune
and all three reference compilers; every declared Rune-supported package build
passes its selected checks; and remaining compatibility gaps are explicit tasks
with reproducers or documented requirements. An unsupported build is never
reported as passing or treated as a completed Rune port.

**Validation:** the 113-verdict common suite passed with installed Rune, both
SML/NJ versions and Poly/ML; MLton 20241230 consistently fails the C-string
invalid-escape oracle. All reference harness cross-checks passed after the
orphan-timeout fixture correction. HaMLet 2.0.1 builds with Rune and Poly/ML
passed the smoke and six selected upstream checks. The common suite package
records the small reproducer, normative expectation and exported raw evidence.
Full Rune compiler ports remain explicitly scoped in the compatibility notes.

### M5 — Composable benchmark experiments

- [x] Represent experiments as dependency graphs of source, patch, compiler,
  runtime, program, workload, and result artifacts. Keep the compiler that built
  a runtime independent from the compiler that produced a program's bytecode.
- [x] Support selecting versions, variants, platforms, builders, runtimes,
  workloads, and flags as matrix dimensions. Expand only compatible combinations;
  provide a dry run listing selected builds/runs, exclusions, and dependencies.
- [x] Reuse shared build dependencies by recorded input identity and invalidate
  them when recorded sources, recipes, patches, compilers, system artifacts,
  libraries, flags, or runtime inputs change. Make provenance gaps visible and
  follow the conservative cache policy above. Never count a cached build as a
  fresh compile-time measurement.
- [x] Separate acquisition, preparation, compilation, linking, startup, and
  workload execution where measurable. Define measurement boundaries and record
  whether a number measures a phase or the whole command. Exclude downloads and
  patching from compiler timings.
- [x] Define warmups, repetitions, workload sizes, timeouts, memory limits,
  machine/environment metadata, and execution order. Avoid competing timed jobs
  by default; retain individual samples and report variation with summaries.
- [x] Require correctness for each measured configuration before including it
  in performance comparisons. Retain failed and invalid runs in the report.
- [x] Export versioned machine-readable results and a readable comparison with
  commands, identities, system artifacts, provenance gaps, logs, units, sample
  counts, and rerun instructions. Flag environment differences that limit a
  comparison, and retain failed attempts alongside successful measurements.

**Complete when:** a demonstrated experiment runs suite A against software B on
runtime C built by compiler D, with B's bytecode produced by compiler E. At least
two choices on independent dimensions yield multiple valid measured
configurations. The report resolves D and E to their complete build histories,
including recorded system artifacts and known provenance gaps. A saved
specification can be rerun with the recorded prerequisites and measurement
procedure; changes or missing prerequisites are reported. Full environmental
reproduction, byte-identical outputs, and identical timings are not required.

**Validation:** the long profile produced eight valid configurations in
`_work/experiments/1790296971043505-D74A1-1`, with independent Rune/Poly/ML
instruction generators and Poly/ML/SML/NJ runtime builders, two workload sizes,
one warmup and five measured samples each. Both generators emitted identical
bytes for each size. The graph resolves each builder's artifact and ancestry;
compiler commands were fresh, shared by input identity within the experiment.
Separate acceptance runs verified compiler-option bindings, missing-binding
exclusions, rejection of a zero-exit wrong answer, and timeout invalidation
before measured samples. High timing variation limits performance conclusions;
it is retained in the report rather than hidden by a ranking.

### M6 — Larger workloads and Rune-driven automation

- [x] Introduce a user manual organized by concepts, command operations and
  complete workflows, with a repository rule to update it alongside changes.
- [x] Add a substantial downstream SML application and a representative large
  suite using the same recipe contract. Select them from the package READMEs'
  recommendations and document why they provide useful coverage.
- [x] Demonstrate coexisting versions or variants of a package and its suites,
  with isolated sources, patches, builds, and results.
- [x] Define a small correctness profile, a broader regression profile, and an
  opt-in long benchmark profile. Document prerequisites and measured costs.
- [x] Stabilize invocation, exit statuses, configuration, and result schemas so
  Rune's own automation can install Rune and invoke this repository. Document
  that contract here; changes to the Rune repository require confirmation.
- [x] Provide contributor instructions for adding/updating a package or suite,
  refreshing pinned releases, diagnosing failures, retaining or exporting logs,
  and rerunning a report with its recorded system prerequisites.

**Complete when:** a caller can supply one installed Rune version and run a
documented profile from a clean checkout, obtaining actionable correctness
results and traceable benchmark data. A large downstream workload exercises the
same framework as the initial compiler packages, and another contributor can
add a package without duplicating framework logic.

**Validation:** HaMLet 2.0.1 passed its smoke and six upstream checks with both
Rune and Poly/ML. The separately versioned expanded Basis selection exercises
611 verdicts from ten upstream files; Rune and both SML/NJ versions passed it,
and MLton/Poly/ML differences have reduced reproducers and exported logs.
The final quick profile passed from a source-only copy without cached archives
or reference artifacts. The full regression profile completed 16 tasks in about
15 minutes, retaining the three documented failing tasks; the opt-in long
profile passed in about 2.5 minutes. The README documents the caller contract,
prerequisites, measured costs, contributor workflows and evidence retention.
No changes to the Rune repository were needed.

## Progress tracking and continuation

The initial roadmap is complete. Preserve its acceptance evidence when adding
new packages, platforms, compiler versions or experiment adapters. Improvements
beyond the demonstrated scope should have their own completion criteria.

As work lands, check off tasks and record the recipe/configuration, validation
command, and evidence for each completed milestone. Turn discoveries into
specific follow-up tasks with affected variants and unblock conditions. A
compiler bug, unavailable seed, or unsupported platform blocks the affected
configuration; it must remain visible while independent work proceeds.

## Strengths, weaknesses, and risks

### Strengths

- Recursive compiler/runtime provenance can explain complex comparisons,
  including the compiler that built another compiler or virtual machine.
- Shared SML recipes, pinned releases, explicit variants, and minimal patches
  provide consistent ways to acquire, build, and test substantial software.
- Rune exercises its own ecosystem by running the harness, while the harness's
  tests use three independent reference compiler implementations for cross-checks.
- Correctness gates, explicit unsupported states, and preserved failure evidence
  keep incomplete work and unreliable performance results visible.

### Weaknesses

- System dependencies are recorded but not fully controlled. Missing identities,
  unavailable old tools, and environmental differences can limit reproducibility
  and the strength of comparisons even when source inputs are pinned.
- The framework and three compiler bootstraps require substantial infrastructure
  before the broader corpus is available. The initial workload selection is
  compiler-heavy and does not yet represent the full range of SML applications.
- Cross-compiler harness tests do not prove correctness: shared source bugs,
  incorrect expectations, and untested platform adapters can affect all builds.
- The benchmark methodology still needs validation on real workloads and machines;
  repeated timings alone do not establish a meaningful performance difference.

### Risks and responses

| Risk | Response within this roadmap |
| --- | --- |
| A Rune compiler, VM, or Basis bug affects harness decisions or reporting. | Cross-check the harness with SML/NJ, MLton, and Poly/ML against reviewed expectations; preserve raw evidence and obtain confirmation before fixing `../rune`. |
| Frequent build failures, long bootstraps, or interrupted runs make diagnosis expensive. | Capture logs and metadata incrementally, preserve separate attempts, group recurring diagnostics, and support focused reruns while independent work continues. |
| Toolchain drift or an undeclared system dependency changes an artifact or measurement. | Record actual tools and libraries per build, including GCC versions, flag provenance gaps, invalidate incompatible cached builds, and qualify affected comparisons. |
| Language extensions, FFI, or runtime coupling turn a small Rune patch into a major port. | Assess compatibility early, preserve upstream build paths, and track full ports as explicit blocked work rather than reporting success. |
| Variants and composed experiments multiply build cost and log/storage volume. | Preview compatible combinations, reuse validated artifacts, allow targeted runs, and document retention/export policies for evidence. |
| Machine noise or workload differences produce misleading performance claims. | Record measurement boundaries and environment settings, retain raw samples and correctness outcomes, and investigate variation before treating a difference as a regression. |
| Upstream releases, source archives, or required system tools become unavailable. | Preserve verified acquisition caches and provenance where practical, document external prerequisites, and report the exact missing inputs when a rerun cannot be completed. |
