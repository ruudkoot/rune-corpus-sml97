# rune-corpus-sml97

A corpus of Standard ML '97 software for checking Rune's correctness and
comparing SML compilers. The harness is written in SML, built by installed Rune,
and executed by `runevm`. Pinned recipes build reference compilers and downstream
programs, run correctness suites, and retain the evidence behind each result.

Rune, SML/NJ, MLton and Poly/ML provide corpus-built compiler artifacts. Rune
versions use full Git commit hashes; installed Rune still builds and runs the
harness and bootstraps Rune. Each result
records its sources, selected compiler, native tools, commands and logs, so you
can investigate both successful runs and failures. Experimental benchmarks
compose independently built programs and runtimes. Full reproducibility is not
promised; known gaps remain visible in the records.

Rune bootstrap recipes now cover `b5ec8c8833e906cd3fe636a49e20b7c8474596dc`
and `e840204151663baf1139c8096b566301e9ced37d`; see [Rune builds](packages/rune/README.md).
Workloads select exact Rune artifacts; the installed harness compiler is independent
of those selections.

## Quick start

On Linux with installed `rune`, `runevm`, GCC/G++, GNU make/binutils, curl, tar,
patch, sha256sum, strace and GNU timeout available, run from the repository root:

```sh
bin/build
bin/corpus doctor
bin/test
```

This builds and checks the harness; reference compiler bootstraps are separate
workflows with package-specific prerequisites. `bin/build` also generates
`corpus.mlb` for the LSP. Downloads, builds and results stay under the ignored
`_work/` directory. See [commands](#2-commands) for setup details and
[workflows](#3-workflows) for your first suite or compiler build.

This README is also the user manual. Read the concepts first if the system is
new to you, use the command reference to look things up, and follow the workflows
for complete tasks. It describes implemented behavior; [ROADMAP.md](ROADMAP.md)
records the completed initial milestones and their scope.
[RESULTS.md](RESULTS.md) gives the dated cross-check and benchmark results,
known failures, manual rerun commands and remaining work. The
[implementation notes](docs/implementation.md) retain validation evidence and
historical progress. Update this manual alongside
behavior changes, following the maintenance rule in [AGENTS.md](AGENTS.md).

## Contents

- [1. Concepts](#1-concepts)
- [2. Commands](#2-commands)
- [3. Workflows](#3-workflows)
- [4. Reading results and keeping evidence](#4-reading-results-and-keeping-evidence)
- [5. Current boundaries](#5-current-boundaries)

## 1. Concepts

### The checkout and its work area

The **checkout** contains the instructions and framework: SML source, package
recipes, patches, test validators and documentation. These belong in version
control. Acquired upstream sources and generated outputs live under the ignored
**work area**, `_work/`.

| Location | What it contains |
| --- | --- |
| `bin/` | Launchers for building and running the harness. |
| `lib/`, `src/` | Shared SML components and corpus operations. |
| `packages/NAME/VERSION/` | Pinned recipes, owned inputs, patches and package documentation. |
| `experiments/` | Experiment specifications, binding examples and owned workloads; currently the stack-machine fixture. |
| `tests/` | Tests of the harness itself. |
| `_work/downloads/` | Source archives stored by checksum. |
| `_work/attempts/` | Separate package lifecycle executions and their evidence. |
| `_work/programs/`, `_work/program-runs/` | Owned program builds and executions. |
| `_work/cross-checks/`, `_work/reports/` | Harness comparisons and generated failure groups. |
| `profiles/`, `_work/profiles/` | Committed run selections and their recorded executions. |

A version-control checkout and its history are a useful starting analogy: the
checked-in recipe tells you what to do, while an attempt records what actually
happened. There is no corpus branch or merge operation. Git manages changes to
the instructions; the corpus manages executions and their resulting artifacts.

A fresh Git checkout has recipes, but no built reference compilers. Copying an
`artifact.record` alone does not copy the compiler it describes.

### Packages, versions, variants and recipes

A **package** is software to acquire and build, such as SML/NJ. A **version** pins
a particular upstream source. A **variant** names a supported configuration, such
as `amd64-linux`. These are separate parts of its identity: SML/NJ 2026.2 and
110.99.9 coexist, and one version never implicitly replaces the other.

A **recipe** is a `.record` file describing the procedure. It declares the source
URL and SHA-256 digest, patches, required tools, compiler selection, commands,
timeouts, output artifact and test expectations. One package can have several
recipes: `stage1.record` and `stage2.record` describe different bootstrap stages;
the regression package has separate recipes for Rune and each reference family.

The positional variant argument must match a variant listed in that recipe.
It is not an arbitrary output label. Recipe arguments are passed as argument
lists; substitutions such as `{source}` and `{compiler}` resolve to the selected
attempt's locations. Shell expansion happens only when a recipe explicitly runs
a shell or an upstream shell script.

### Attempts and steps

An **attempt** is one invocation of a package lifecycle operation. It has a
unique directory, a recipe snapshot, status, source/build directories and logs.
An invocation with the same recipe and variant creates a new attempt.

A **step** is one recorded child process within that attempt: downloading an
archive, probing GCC, applying a patch, compiling, or running a test. Each step
keeps its arguments, environment, working directory, status, stdout and stderr.
A long bootstrap can be silent at the terminal while its step logs grow.

The lifecycle is cumulative within an invocation:

```text
prerequisite checks and identity records
    -> fetch and verify
    -> extract into a fresh tree and patch
    -> build and record the artifact
    -> test the artifact
```

`fetch`, `patch`, `build` and `test` choose where that invocation stops.
**`build` followed by `test` means two builds in two attempts.** `test` does not
resume the earlier build. Normally, ask for `test` directly when you want a
validated output. Use earlier stopping points to investigate acquisition,
patches, or compilation.

Verified download archives are reused. Extracted trees and builds are currently
always fresh. A failed command blocks later commands in that attempt; a separate
attempt can proceed independently. The semantic-suite adapter also continues
its independent test cases after a case fails.

### Specifications and artifacts: three different identities

A **build specification** records the selected recipe, source, patches, owned
inputs, variant, compiler, harness sources, tools and environment. Its digest
identifies those recorded inputs. An **artifact** describes an output and points
back to its producing attempt and specification.

| Identity | The question it answers |
| --- | --- |
| Attempt ID | Which particular execution was this? |
| Specification ID | Which recorded inputs and configuration were selected? |
| Output digest or manifest digest | Which file contents were produced? |

Two attempts can have the same specification ID and different outputs. Matching
specifications do not prove deterministic builds or complete environmental
reproduction. They are useful evidence when explaining a difference.

Artifacts have different kinds. A normal package output may be a single file.
A compiler artifact includes a manifest of its installation files, version,
target, configuration and bootstrap parent. A `runnable-program` artifact also
records how to launch its output. `execute` accepts that last kind; it cannot
launch an arbitrary package's `artifact.record`.

Records and manifests are local evidence, not signed or tamper-proof history.
Keep produced compiler installations and their evidence intact. Selection checks
the recorded files and validation status; editing or removing them can make
dependent operations fail.

### Compiler selection and bootstrap ancestry

The **harness runner** and the **compiler selected for a workload** are different
roles. Rune remains the harness runner even when the selected compiler is Poly/ML.
`cross-check` deliberately compiles and runs the harness tests with a reference
compiler, then compares their verdicts with Rune's.

Reference selection uses an exact artifact path, for example
`_work/attempts/AN_ATTEMPT/artifact.record`. There is no implicit “latest MLton”
selection. A recipe can constrain the permitted family, version and target.
The selector verifies the installation manifest and the producing test attempt.

Bootstrap ancestry explains how a reference compiler came to exist:

| Stage | Role in this corpus |
| --- | --- |
| 0 | An external installed SML compiler, allowed only as an initial bootstrap seed. |
| 1 | A corpus-built bootstrap compiler, usable to produce stage 2. |
| 2 | A rebuilt compiler eligible for normal corpus work after its test attempt passes. |

The current MLton route uses an external stage-0 MLton. SML/NJ and Poly/ML start
from pinned upstream boot files and native builds. Both still have explicit
stage-1 and stage-2 recipes. Stage-1 artifacts cannot serve as ordinary workload
or harness cross-check compilers. A successful `build` attempt alone also does
not qualify a compiler: its producing invocation must be a passed `test`.

Native tools such as GCC remain system dependencies at every stage. Installed
Rune builds and runs the harness and supplies the preferred external Rune seed.
Rune workloads instead select a corpus stage-2 artifact by full source commit
hash. Its compiler, matching VM and Basis are verified together. Two commits
can therefore coexist even when both print the same upstream release banner.
Stage 1 runs its compiler on a copied seed VM; stage 2 uses the selected commit's
freshly built VM. See [Rune bootstrap details](packages/rune/README.md).

### Correctness suites and oracles

A **suite** is a collection of test cases with defined inputs and expectations.
An **oracle** says what counts as correct. A zero exit status is necessary for
normal lifecycle tests, but their expected stdout must also match. A recipe may
choose exact output or an explicit nonempty completion marker.

The separately acquired SML/NJ regression subset uses reviewed validators for
113 List, Vector and String assertions. The separately versioned
[expanded Basis selection](packages/smlnj-regressions/95b939d/suites/basis-expanded/1/README.md)
checks 611 verdicts from ten upstream files, including arrays, slices, scanning,
substrings and byte arithmetic. The validator runs after its source
test; a completion marker is printed only after validation succeeds. Candidate
compiler output was not used to invent those expectations.

There are three distinct checks:

| Check | What is being tested |
| --- | --- |
| `bin/test` | The harness, using Rune and controlled fixtures. |
| `bin/corpus cross-check ARTIFACT` | The same harness tests under Rune and a reference compiler. |
| `bin/corpus test RECIPE VARIANT ...` | The package or suite described by that recipe. |

Passing one does not imply passing the others. Agreement between compilers is
additional evidence; explicit expectations still matter.

The harness fixtures create a local source archive, patch and compile it with
Rune, and exercise malformed records, corrupt downloads, literal arguments,
large/partial failing logs, timeouts, retries and variant isolation. They do not
select installed reference compilers as workload compilers.
Some fixtures deliberately create failed lifecycle attempts and verify their
evidence. Those failures remain visible in `report`; the harness or profile
verdict tells you whether the expected failure behavior passed its test.

### Provenance and the host system

**Provenance** is the evidence connecting an output to its inputs and procedure.
Inventories record tool paths, hashes and version output, including GCC, the
installed Rune payload and Basis files. Per-attempt selected-tool records say
which declared tools were selected. Traced build/test steps retain raw process
and file-access logs and hashes for observed readable system files.

This is useful for diagnosing “the same source behaved differently on this
machine.” It does not make the build hermetic. PATH isolation limits the tools
upstream scripts discover; it is not a filesystem sandbox. File tracing and
post-execution hashing have coverage gaps, which remain part of the evidence.
Full reproducibility is unlikely within this roadmap.

### Experiments, bindings and dependency graphs

An **experiment specification** describes a workload and its measurement
procedure. A separate **bindings record** maps local names to exact compiler
artifacts. This separates “compare these builder roles” from machine-specific
artifact paths. The current adapter supports the owned stack-machine format.

Its generator and interpreter can be built by independent compilers. The planner
expands generator choices × interpreter choices × workload sizes. Each combination
becomes a configuration with a correctness check and, if valid, measured samples.
Compiler versions, target and build configuration come from the selected artifacts.

A **dependency graph** records what must exist before each operation can run:

```text
generator source + compiler E -> generator -> instruction stream
runtime source   + compiler D -> interpreter       |
                                      |           |
workload size and repetitions ---------+-----------+-> checked run -> result
```

Shared build dependencies are reused within one experiment by their recorded
input identity. Another experiment makes fresh builds; there is no cross-run
build cache. Compiler artifacts retain their own source, patch and bootstrap
history. A missing or incompatible compiler binding is an explicit exclusion,
and a failed build blocks its dependent configurations.

## 2. Commands

### Invocation rules and setup

Run examples from the repository root. The launchers change their working
directory to that root, so relative arguments to `bin/corpus` are interpreted
there even if you invoked the launcher from another directory. Use absolute
paths for inputs elsewhere. In the syntax below, uppercase names are placeholders
to replace; the square brackets describe optional arguments and are not typed.

```sh
bin/build
bin/corpus --help
bin/corpus doctor
bin/test
```

`bin/build` compiles the harness to `_work/bin/corpus.rbc` and generates
`corpus.mlb` for the LSP from `sources.txt`, Basis and `src/main.sml`. Rebuild
after changing harness sources, source order or the installed Rune. The launcher
does not rebuild automatically. `corpus.mlb` is generated and ignored; edit
`sources.txt` to change its source list.

The current adapter requires Linux, Rune/`runevm`, and the native tools declared
by the selected recipe. The general inventory includes GCC/G++, make/binutils,
curl, tar, patch, sha256sum, timeout, strace and uname. Compiler builds have further
requirements: for example CMake/autoconf for modern SML/NJ, and development
headers/libraries for GMP and, where configured, libffi. Read the package README
and run its doctor before starting a long build.

| Environment setting | Effect |
| --- | --- |
| `RUNE` | Selects the installed Rune compiler, including in `bin/build` and tests. Use an absolute executable path when overriding it. |
| `RUNEVM` | Selects the matching installed VM used by the launchers. |
| `CORPUS_RUNE_LIB` | Identifies the installed Rune Basis/payload for inventory and the external Rune seed. Stage-1 Rune builds pass this library explicitly to the seed compiler. It does not change the harness build's library search; identify the library that its compiler actually uses. |
| Native build settings | Selected values such as `CC`, `CXX`, `CFLAGS`, `LDFLAGS` and `MAKEFLAGS` are inherited and recorded; a recipe's explicit settings can override them. |

Child environments use `LC_ALL=C`, `LANG=C` and `TZ=UTC` and an explicit allowlist
of inherited variables. See [Process.environment](lib/process.sml) for that list.
Do not rely on an arbitrary interactive-shell variable reaching a build.

### Package lifecycle

| Command | Action |
| --- | --- |
| `bin/corpus doctor` | Writes a general system inventory and reports missing inventory items. |
| `bin/corpus doctor RECIPE VARIANT` | Checks that recipe's tools, declared minimum versions and host constraint. |
| `bin/corpus fetch RECIPE VARIANT [COMPILER_ARTIFACT]` | Checks prerequisites and selection, then acquires and verifies pinned archives. |
| `bin/corpus patch RECIPE VARIANT [COMPILER_ARTIFACT]` | Also extracts and applies patches to a fresh tree. |
| `bin/corpus build RECIPE VARIANT [COMPILER_ARTIFACT]` | Also executes build commands and records the output artifact. |
| `bin/corpus test RECIPE VARIANT [COMPILER_ARTIFACT]` | Also executes the recipe's tests against that new build. |

Recipes with `compiler.kind=corpus` require the exact compiler-artifact argument,
including for `fetch` and `patch`. Recipes selecting the harness Rune fixture, an external
bootstrap seed or native boot files do not accept that argument. Recipe doctor
has no compiler-artifact argument and does not validate the selected compiler
or prove that all development headers and libraries are present. Those checks
also occur during actual selection and upstream configuration/build steps.

Successful lifecycle commands print `attempt: PATH`. Failures print an error and,
once an attempt exists, its path. Invalid recipe syntax or an unsupported variant
can fail before an attempt is created. Package-local `doctor`, `fetch`, `patch`,
`build` and `test` wrappers, where present, currently select **stage 1**; use the
explicit stage-2 recipe with `bin/corpus` for the next stage.

### Selection and inspection

| Command | Action |
| --- | --- |
| `bin/corpus compilers` | Lists compiler records from passed lifecycle attempts, including their stages and paths. Inspect the stage and producing test before selecting one. This listing itself does not reverify files. |
| `bin/corpus report` | Lists package lifecycle attempts, requested phases and statuses. |
| `bin/corpus report ATTEMPT_DIRECTORY` | Shows the attempt and unsuccessful/unfinished top-level process steps, with log locations. |
| `bin/corpus show RECORD` | Decodes any record for reading. |
| `bin/corpus logs PATH TEXT` | Recursively searches `.log` files for a case-sensitive literal substring. Quote text containing spaces. |
| `bin/corpus compare LEFT_ATTEMPT RIGHT_ATTEMPT` | Prints differing attempt and specification fields and points to raw evidence. It does not perform a line-by-line log diff. |
| `bin/corpus failures` | Groups failed lifecycle attempts by similar observed diagnostics and writes `_work/reports/ID/groups.record`. |
| `bin/corpus export ATTEMPT_DIRECTORY NEW_ARCHIVE.tar.gz` | Exports a completed lifecycle attempt's records, logs and rerun guidance. The destination must not exist. |

Failure grouping uses package, failure class, operation and an observed diagnostic
line, with limited path/number normalization. Similarity is a way to find related
evidence; it is not an established root cause. Output-oracle failures can occur
after a process exits successfully, so also inspect the attempt error and command
plan when `report` shows no unsuccessful process step.

`report`, `compilers`, `failures` and `export` operate on package lifecycle
attempts. Program builds/runs and harness cross-checks have separate directories;
inspect their records with `show` and their logs with `logs`.

### Harness cross-checks

```text
bin/corpus cross-check COMPILER_ARTIFACT
```

The command verifies a validated stage-2 compiler, compiles/runs the harness tests
with installed Rune, and runs the same sources through that reference compiler's
adapter. It requires the completion marker and identical ordered `PASS` lines.
Compiler banners and other raw output remain in the logs. Results live under
`_work/cross-checks/ID/`, with a `comparison.record` once comparison is reached.
An earlier compilation/execution failure can leave only partial step evidence.

### Owned program builds and execution

```text
bin/corpus program SOURCE.sml COMPILER_ARTIFACT
bin/corpus execute PROGRAM_ARTIFACT [ARG ...]
```

`program` takes a single owned SML file exposing:

```sml
structure Program =
struct
  fun main (name : string, args : string list) : OS.Process.status =
    (print "hello\n"; OS.Process.success)
end
```

Use an exact validated stage-2 artifact path, including for Rune. The old
`installed-rune` workload selector is rejected; rebuild historical programs with
a selected corpus Rune artifact. Existing evidence remains readable.
The adapter supplies the entry point and compilation/export convention for Rune,
MLton, Poly/ML or SML/NJ. It snapshots the input, creates a fresh build under
`_work/programs/`, and prints `program artifact: PATH`. This is a small owned
program adapter; use a package recipe for a substantial upstream build system.

`execute` verifies the program manifest, launch executable and applicable parent
compiler, then runs it with the recorded environment and working directory.
It prints captured stdout and the log location. The current timeout is 120
seconds, without a CLI override. Relative file arguments are interpreted **inside
the program artifact's working directory**, so use absolute paths for external
input/output files. There is no correctness oracle in `execute`; success means
the process exited zero. Validate its output yourself or through a suite.

These commands are also the building blocks used by the benchmark adapter below.
An individual `execute` invocation does not schedule samples or produce statistics.

### Benchmark planning and measurement

```text
bin/corpus bench --dry-run EXPERIMENT_RECORD BINDINGS_RECORD
bin/corpus bench EXPERIMENT_RECORD BINDINGS_RECORD
```

The first benchmark adapter is experimental and restricted to the owned
`corpus-stack-1` workload. Dry run snapshots inputs, checks exact compiler
artifacts, inventories tools and writes a dependency plan. It prints selected
configurations, exclusions and dependencies without compiling or timing them.
Source paths in an experiment resolve relative to its specification file;
compiler paths in bindings resolve relative to the bindings file. These differ
from the CLI's repository-relative argument paths. Absolute compiler paths are
convenient for local bindings.

A real run prepares fresh shared program builds, generates instruction streams,
checks each runnable configuration, performs warmups and collects samples in
serial rounds with a rotated configuration order. A failed correctness check,
warmup or sample removes that configuration from the reported timing comparison.
Independent configurations continue, and failures remain in the result.

| Specification setting | Meaning |
| --- | --- |
| `generator.source`, `runtime.source` | Owned SML source files exposing `Program.main`. |
| `generators`, `runtimes` | Independent lists of compiler-binding names. |
| `sizes` | Instruction-stream sizes, from 1 through 20000. |
| `iterations` | Workload repetitions within each interpreter invocation. |
| `warmups`, `samples` | Untimed-for-comparison warmup count and measured sample count per configuration. |
| `timeout.seconds` | Deadline for each generator or interpreter invocation. |
| `memory.mib` | Virtual-address-space limit for each generator or interpreter process, enforced by `prlimit`. |

The checked-in `demo.record` selects two generator builders, two interpreter
builders and two sizes: eight configurations. Lists use the record format's
`.count` and indexed fields. Compiler build settings come from the selected
artifacts; a binding can additionally supply an `ALIAS.arguments` list for
compiling the owned program. Extra arguments are supported for Rune and MLton;
nonempty lists for Poly/ML or SML/NJ are explicitly unsupported.

For example, two aliases can point to the same Rune artifact, with one declaring
`arguments.0=--basis`, `arguments.1=all`, and `arguments.count=2` under its alias
prefix. Put both aliases in the generator list to compare the flag choices.
The actual record separator is a tab, as in the binding examples. Arguments
enter the build identity, so the two builds are kept separate. The adapter
supplies its own source/output arguments; use extra arguments for compiler
options, not alternative output paths or early-exit modes.

Runtime measurements use the installed external `time` utility: wall, user and
system seconds, plus maximum RSS in KiB. The boundary includes startup, instruction
parsing and workload execution. The time utility's wall-clock output has limited
resolution; increase workload size/repetitions if samples are too close to zero.
Fresh compilation reports wall time for compiler commands, including linking or
export where the adapter combines them, with one observation per distinct build.
Acquisition, inventories and preparation are outside that compilation boundary.
Program compilation retains its adapter's 600-second deadline; the experiment's
memory limit applies to generator/interpreter execution, not compilation.

A lock prevents two benchmark executions in this checkout from overlapping.
The runner also refuses to begin timing while it detects active corpus lifecycle
work. Wait for that work to finish and rerun. This does not prevent another
process from starting later or control unrelated machine activity. CPU frequency,
host load and caches remain uncontrolled; machine snapshots and provenance gaps
are retained. Timed commands are untraced to avoid tracing overhead.

Results live in `_work/experiments/ID/`: `plan.record`, `result.record`,
`REPORT.md`, `nodes/`, `configurations/`, `samples/`, `steps/` and machine/tool
records. Every individual sample has a record and raw logs. The readable report
shows median and min–max wall times for fully valid configurations. Early failures
can leave partial evidence. After an interrupted benchmark, inspect
`_work/benchmark.lock/owner.record` and verify its process is no longer active
before manually removing a stale lock directory.

### Profiles for repeated and automated runs

```text
bin/corpus profile PROFILE_RECORD [BINDINGS_RECORD]
```

A profile is a committed list of existing harness, recipe, cross-check or
benchmark operations. Tasks execute serially and keep separate process logs;
independent tasks continue after a failure. The overall exit status is nonzero
if any task fails, times out or cannot select its required configuration.
Results live under `_work/profiles/ID/`, including `result.record`, per-task
records, the profile/bindings snapshots, system inventory and child logs. Profile
results also record the orchestrator bytecode digest.

| Profile | Intended use and prerequisites |
| --- | --- |
| `profiles/quick.record` | Rune harness fixtures and the shared Rune correctness subset. Requires the `rune` binding to a corpus Rune artifact, plus installed Rune for the harness. |
| `profiles/regression.record` | Shared and expanded Basis suites, all four reference-artifact cross-checks including legacy SML/NJ, and Rune/Poly/ML HaMLet builds. Requires `rune`, `smlnj`, `legacy`, `mlton` and `poly` bindings. |
| `profiles/rune-versions.record` | Cross-check, shared/expanded suites and HaMLet for each of `rune-old` and `rune-new`; eight independent tasks. |
| `profiles/long.record` | Opt-in benchmark matrix; requires the demo's `rune`, `poly` and `smlnj` bindings and no competing corpus builds. |

The original three profiles completed integrated validation before versioned Rune
selection was introduced. Those historical runs used installed Rune for workloads;
the current profiles require corpus Rune artifacts. See [RESULTS.md](RESULTS.md)
for the separately recorded versioned-Rune results. The quick profile
passed from a clean source-only checkout, and the long profile passed its
eight-configuration matrix. The regression profile completed all 16 tasks, with
13 passes and three failing tasks. It retains the investigated MLton String.fromCString failure in both
suite selections and Poly/ML Substring/Word8 failures in the expanded selection.
Expect a nonzero result with these compiler versions. See the
[expanded suite differences](packages/smlnj-regressions/95b939d/suites/basis-expanded/1/known-differences.md)
for exact observations and reproducers. Independent tasks still run, and known
failures are never silently suppressed.
Observed whole-profile costs on the development WSL2 host were about 86 seconds
for quick, 15 minutes for regression and 151 seconds for long. These include
profile setup and fresh workload builds but exclude reference compiler bootstraps.
The quick run had no acquisition cache. Costs vary with Rune and host load;
profile records keep start/end times and individual task logs.

### Internal adapter and exit status

Recipes for semantic suites call:

```text
bin/corpus run-suite METADATA SOURCE_DIRECTORY BUILD_DIRECTORY COMPILER_ARTIFACT
```

This is an internal adapter for already prepared source and build directories.
Prefer `test` on the package's suite recipe: it records acquisition, patches and
the surrounding provenance. Direct use bypasses that lifecycle. Per-case results,
generated SML reproducers and logs are placed under `BUILD_DIRECTORY/suites/`.

CLI success returns status 0; errors return a nonzero status (currently 1 for
normal handled errors on Linux). A failed child's exit number is retained in
its step record rather than propagated as the CLI's exit number. Read records
to distinguish build errors, oracle failures and timeouts. Inspection commands
return success when inspection succeeds even if they display failed attempts.
There is no resume, cleanup or automatic artifact selection command in the
current CLI. Named profiles still require explicit reference artifact bindings.

## 3. Workflows

### Run a standard profile

After `bin/build`, `bin/test` checks the harness without corpus compiler artifacts.
For the quick profile, bootstrap one Rune commit first; broader profiles also need
their reference compilers. Copy the binding example and replace the required
placeholders with absolute paths to validated stage-2 artifacts. `rune` selects
the Rune subject for quick/regression/long; `rune-old` and `rune-new` select the
two subjects for the version-comparison profile:

```sh
cp profiles/bindings.example.record _work/my-profile-bindings.record
```

After editing those values, run the broader checks or explicitly opt into timing:

```sh
bin/corpus profile profiles/quick.record _work/my-profile-bindings.record
bin/corpus profile profiles/regression.record _work/my-profile-bindings.record
bin/corpus profile profiles/rune-versions.record _work/my-profile-bindings.record
bin/corpus profile profiles/long.record _work/my-profile-bindings.record
```

These are separate invocations; wait for the regression run to finish before
starting timings. Inspect the printed profile directory's `result.record` and
`tasks/` records. Child stdout/stderr contains the underlying lifecycle attempt,
cross-check or benchmark paths. For automation, build with the supplied installed
Rune, invoke a profile, use its exit status for the job verdict, and retain its
records together with the referenced child evidence. No Rune repository changes
are needed.

The caller owns Rune installation and native prerequisites. Set `RUNE` and
`RUNEVM` to matching absolute executable paths if they are not the defaults.
Keep that installation fixed for the invocation, and rebuild the harness after
replacing it: a reused version string does not guarantee compatible bytecode.
`CORPUS_RUNE_LIB`, when needed, must identify the Basis/payload actually used by
that compiler. Read machine records by their named fields and `kind`, allow
additive fields, and reject unsupported serialization versions. Console progress
is intended for people; use exit status and the saved records for job decisions.
Retain the matching corpus checkout, since changes to recipes and validators
are part of the evidence and rerun requirements.

### Get a first correctness result

After [bootstrapping Rune](packages/rune/README.md), select its stage-2 artifact
and run the portable subset:

```sh
corpus_rune="$PWD/_work/attempts/REPLACE_WITH_RUNE_STAGE2_ID/artifact.record"
bin/corpus doctor packages/smlnj-regressions/95b939d/rune.record amd64-linux
bin/corpus test packages/smlnj-regressions/95b939d/rune.record amd64-linux "$corpus_rune"
bin/corpus report
```

Copy the printed attempt path, then inspect it:

```sh
corpus_attempt=_work/attempts/REPLACE_WITH_PRINTED_ID
bin/corpus report "$corpus_attempt"
bin/corpus show "$corpus_attempt/test-plan.record"
bin/corpus logs "$corpus_attempt" CORPUS_SUITE_PASS
```

Look for a passed attempt and the suite's per-case results under
`build/suites/`. This recipe has three cases containing 113 assertions; it is
a selected subset, not the full upstream regression repository. The package
[README](packages/smlnj-regressions/95b939d/README.md) explains the oracle and
exclusions.

### Bootstrap a reference compiler and use it

Poly/ML is a concrete example with no installed SML seed requirement. Its native
prerequisites still need to be installed. First acquire, build and validate stage 1:

```sh
bin/corpus doctor packages/polyml/5.9.2/stage1.record amd64-linux
bin/corpus test packages/polyml/5.9.2/stage1.record amd64-linux
```

Set the following path from that successful invocation, then build stage 2:

```sh
corpus_stage1=_work/attempts/REPLACE_WITH_STAGE1_ID/artifact.record
bin/corpus test packages/polyml/5.9.2/stage2.record amd64-linux "$corpus_stage1"
```

Set the stage-2 path from the second successful invocation:

```sh
corpus_poly=_work/attempts/REPLACE_WITH_STAGE2_ID/artifact.record
bin/corpus show "$corpus_poly"
bin/corpus cross-check "$corpus_poly"
bin/corpus test packages/smlnj-regressions/95b939d/polyml.record amd64-linux "$corpus_poly"
```

This establishes separate evidence for bootstrapping, harness behavior and the
portable semantic suite. Keep both stage installations and their attempt records:
the second compiler's history refers to the first. Bootstraps can take minutes
to tens of minutes or longer, particularly with file tracing. Use step logs to
follow progress rather than launching an unnecessary retry.

### Compare two versions or compiler families

Use `compilers` to locate candidates and inspect their records. For example,
choose validated SML/NJ 2026.2 and 110.99.9 artifacts explicitly:

```sh
corpus_modern=_work/attempts/REPLACE_WITH_MODERN_ID/artifact.record
corpus_legacy=_work/attempts/REPLACE_WITH_LEGACY_ID/artifact.record
bin/corpus test packages/smlnj-regressions/95b939d/smlnj.record amd64-linux "$corpus_modern"
bin/corpus test packages/smlnj-regressions/95b939d/smlnj.record amd64-linux "$corpus_legacy"
```

Compare the two **suite attempts** printed by those commands:

```sh
bin/corpus compare _work/attempts/FIRST_SUITE_ID _work/attempts/SECOND_SUITE_ID
```

Check case verdicts alongside specification differences and raw output. For
another family, select its corresponding recipe (`mlton.record` or
`polyml.record`) and exact artifact. Passing tests support correctness claims
for those cases. Durations from these traced correctness runs are not a
controlled performance comparison.

### Diagnose a failed build and retry it

Start with the attempt path from the error:

```sh
bin/corpus report _work/attempts/FAILED_ID
bin/corpus logs _work/attempts/FAILED_ID error
bin/corpus show _work/attempts/FAILED_ID/build-plan.record
bin/corpus failures
```

The plan exists once that phase has been planned. Open the failing step's
`stdout.log`, `stderr.log` and `step.record`. A missing tool, compiler rejection,
timeout and failed expectation require different fixes. An upstream compiler
can print an error yet exit zero; completion markers and validators are there
to catch this situation.

Correct the recipe, owned input or prerequisite that caused the failure, then
repeat the original `test` command with the same intended compiler selection.
It creates a new attempt and reapplies patches to clean sources. Compare old and
new attempts to explain what changed; retain the failed attempt as evidence.
Do not fix a generated tree and assume that the recipe now reproduces the fix.

If a download checksum fails, inspect the retained archive and source identity.
The corpus will not silently replace a corrupt cached archive or accept a new
upstream digest. Preserve evidence, investigate the discrepancy, then move the
bad cache entry aside if a fresh acquisition is appropriate. A deliberate release
update requires a reviewed new pin.

For an interrupted attempt, first determine whether its recorded processes are
still alive. Its `running` status means incomplete evidence, not a diagnosed
failure. PIDs in records use hexadecimal text. Partial logs survive; the process
supervisor bounds child lifetime if the harness dies. Retry as a new attempt
after confirming the old work is no longer active.

The current process adapter uses SML Basis POSIX interfaces and GNU timeout as
a fallback when the harness is killed. The harness enforces normal deadlines
itself, preserving the distinction between a timeout and ordinary exit 124.
Windows would require a separate process adapter and validation.

### Build a generator and interpreter independently

The [stack-machine fixture](experiments/stackvm/README.md) demonstrates two
independent builders. Rune can build its bytecode generator while a validated
Poly/ML builds its interpreter. Set `corpus_rune` and `corpus_poly` to their
validated stage-2 artifacts as in the bootstrap workflows, then run:

```sh
bin/corpus program experiments/stackvm/codegen.sml "$corpus_rune"
bin/corpus program experiments/stackvm/runtime.sml "$corpus_poly"
```

Use the two printed program artifact paths. From the repository root:

```sh
corpus_generator=_work/programs/REPLACE_WITH_GENERATOR_ID/artifact.record
corpus_interpreter=_work/programs/REPLACE_WITH_INTERPRETER_ID/artifact.record
mkdir -p _work/manual-example
corpus_code_file="$PWD/_work/manual-example/squares.code"
bin/corpus execute "$corpus_generator" "$corpus_code_file" 100
bin/corpus execute "$corpus_interpreter" "$corpus_code_file" 3
```

The generator should print `CORPUS_STACK_CODE 100`. The interpreter should print
`CORPUS_STACK_RESULT 1015050`: the sum of squares from 1 through 100, repeated
three times. A different reference compiler can build the interpreter without
changing the generator choice. Each program artifact resolves to its own builder.

The shared instruction stream is this fixture's format, not Rune bytecode.
This example demonstrates composition and a mathematical correctness check.
Use the next workflow to schedule warmups, limits and measured samples.

### Run a measured matrix

Create local bindings from the example:

```sh
cp experiments/stackvm/bindings.example.record _work/my-bindings.record
```

Edit `rune.compiler`, `poly.compiler` and `smlnj.compiler` in that file to absolute
paths of validated stage-2 artifacts found with `compilers`. Preserve the tab
separating each key and value. Then preview:

```sh
bin/corpus bench --dry-run experiments/stackvm/demo.record _work/my-bindings.record
```

Read the selected configurations and any exclusions. Stop other corpus builds
and tests before collecting measurements. When the inputs and plan are right:

```sh
bin/corpus bench experiments/stackvm/demo.record _work/my-bindings.record
```

Open the printed `REPORT.md` and inspect `result.record`. Follow a configuration
to its samples, runtime/generator build nodes and compiler histories. An excluded
or invalid configuration causes the overall command to fail while retaining the
successful configurations' evidence. Change the local specification for a longer
or smaller experiment; relative source paths must still resolve from that file.

Reruns create a fresh experiment and fresh program builds. Keep the result
directory and referenced program/compiler installations. Lifecycle `export`
does not package experiments; archive their result directories separately,
retaining the path context and prerequisites described in `REPORT.md`.

For a small acceptance matrix that crosses the two Rune versions, fill the
`rune-old` and `rune-new` bindings and run:

```sh
bin/corpus bench experiments/stackvm/rune-versions.record _work/my-bindings.record
```

It has two generator builders, two interpreter builders, sizes 3/9, ten
iterations, one warmup and two samples. These tiny runs test independent version
selection and VM pairing; they are not a useful performance ranking.

### Preserve and rerun a result

For a completed lifecycle attempt:

```sh
bin/corpus export _work/attempts/REPLACE_WITH_ID _work/failure-report.tar.gz
```

Choose a new archive name for every export. The bundle contains top-level records,
raw step logs and `RERUN.md`. Semantic-suite evidence also includes its nested
records, logs and generated SML reproducers. It excludes downloaded archives,
upstream source trees and compiler installations. Preserve those separately for
offline work or direct artifact reuse.

To rerun, use the matching corpus checkout and restore the recorded installed
Rune, native tools and selected compiler artifact. Follow the saved `RERUN.md`,
using the snapshot `recipe.record`, recorded variant and compiler argument.
Patches and owned inputs still come from the matching checkout; the recipe
snapshot alone is not a self-contained source distribution. The new attempt
records any differences in its specification. Absolute artifact paths mean
moving a work area is not automatically supported.

### Add or update a package

Start from the closest package recipe and its README. A contributor's sequence is:

1. Establish the official release and source archive. Pin its URL and digest,
   record checksum provenance and license, and explain any commit/archive exception.
2. Declare versions, variants, host constraints, native tools and supported
   compiler families/versions/targets. Preserve existing upstream build routes.
3. Add minimal ordered patches and declare every owned input used by the recipe,
   including smoke tests and validators, so their hashes enter the specification.
4. Define build commands, artifact paths and tests. Give each test an explicit
   oracle and timeout. Explain exclusions and upstream exit-status limitations.
5. Run doctor, then a complete `test`; exercise fresh retries and each claimed
   compiler combination. Add a reference harness cross-check when changing a
   shared adapter rather than only package data.
6. Document the tested recipe, costs, limitations and evidence. Update this manual
   if the command behavior, concepts, supported operations or workflows changed.

Records are versioned tab-separated data, not shell scripts. Use
[docs/records.md](docs/records.md) and existing recipes for field syntax. Helpers
in `lib/record.sml` encode lists and escapes. For a release update, add the new
version directory and keep the old one usable; do not repoint its source URL
and checksum to different software.

A Rune compiler, VM or Basis bug needs a reproducer. Preserve it in the corpus
and obtain human confirmation before editing `../rune`, where other work may be
ongoing. Continue independent corpus work while that fix is pending.

## 4. Reading results and keeping evidence

An attempt directory commonly contains:

| File or directory | Use |
| --- | --- |
| `attempt.record` | Requested operation, package, variant, parent selection and overall outcome. |
| `recipe.record` | Snapshot of the selected recipe. |
| `doctor.record` | Prerequisite-check result. |
| `specification.record` | Recorded build inputs and specification ID. |
| `system.record`, `selected-tools.record` | General inventory and selected native tool identities. |
| `compiler-input.record` | Snapshot of a selected parent compiler, when applicable. |
| `build-plan.record`, `test-plan.record` | Pending/running/passed/failed/blocked command states. |
| `artifact.record` | Produced output identity; may exist even if later tests failed. |
| `steps/ID/` | Process record, stdout/stderr and, where enabled, file traces and system-artifact records. |
| `source/`, `build/` | Acquired/patched sources, upstream outputs and suite evidence. |

Earlier failures leave only the files reached so far. A failed oracle may have
`exit:0` in the process record but `failed` in the test plan and attempt. A
compiler artifact's existence therefore does not establish its eligibility.

Status vocabulary has distinct levels:

| Level | Current values and interpretation |
| --- | --- |
| Lifecycle attempt | `running`, `passed`, `failed`. A failed record also gives `operation`, `error` and `failure.class`. |
| Failure class | Infrastructure, build, test, timeout or unsupported selection, according to where the failure was detected. The field is diagnostic; inspect the underlying error. |
| Command plan | `pending`, `running`, `passed`, `failed`, `blocked`. A command blocked by an earlier failure did not run. |
| Process | Transient preparation/running states, then `exit:N`, `signal:N`, `timeout` or `infrastructure-failure`. An ordinary child exit 124 remains `exit:124`. |
| Semantic case | `passed`, `compile-failure`, `test-failure`, `timeout`; SML/NJ/Poly/ML combine compilation and execution. |
| Benchmark result | `planned`, `running`, `passed`, `invalid` or `failed`. Configurations additionally distinguish `unsupported` and `blocked`; sample records retain process status. |
| Profile | Overall `running`, `passed` or `failed`; individual tasks additionally distinguish `timeout`, `unsupported` and `infrastructure-failure`. |

The roadmap's broader vocabulary is not a single implemented status enum.
For example, an incompatible compiler selection is currently a failed attempt
with `failure.class=unsupported`; it is not a passing exclusion. Early setup
failures can also prevent a final suite/cross-check summary from being written.

There is no automatic cleanup or dependency-aware garbage collector. Keep
referenced compiler installations, their ancestors and attempt records. Keep
failed/interrupted logs until the diagnosis and any reproducer are recorded.
Export completed evidence before manually removing large, unreferenced trees.
Removing trees can invalidate artifact paths; never remove a live build's files.
See [evidence and reruns](docs/evidence.md) for the retention policy.

## 5. Current boundaries

The following combines historical acceptance with current adapter support.
Versioned Rune downstream validation and the original acceptance data are
recorded separately in [RESULTS.md](RESULTS.md).
Local build progress and exact evidence paths belong in
[implementation notes](docs/implementation.md); use records for the outcome of
any particular run.

| Area | Available behavior and remaining work |
| --- | --- |
| Rune | Both requested commit versions passed stages 1 and 2, smoke and self-reproduction, 61-verdict harness cross-checks, all 611 expanded Basis verdicts and seven HaMLet checks. Workloads select their explicit artifacts and matching VMs. |
| SML/NJ | Development 2026.2 and legacy 110.99.9 have passed stage-2 validation, harness cross-checks and the shared 113 assertions. |
| Poly/ML | 5.9.2 has passed stage-2 validation, the selected upstream runner, the harness cross-check, the shared 113 assertions and the recorded seed-independence audit. |
| MLton | 20241230 stages 1 and 2, selected upstream regressions and the harness cross-check have passed. The shared subset retains an investigated String.fromCString failure; see [known differences](packages/smlnj-regressions/95b939d/known-differences.md). |
| HaMLet | 2.0.1 builds with both corpus Rune commits and Poly/ML 5.9.2 passed the corrected smoke test and six upstream conformance cases. |
| Expanded Basis suite | Both Rune commits and both SML/NJ versions passed all 611 verdicts; MLton retains the String failure and Poly/ML retains Substring/Word8 differences, with documented reproducers. |
| Owned programs | Build/export adapters exist for all four compiler families. Rune, Poly/ML and modern SML/NJ paths have been exercised with the stack-machine fixture. |
| Benchmarks | The two-Rune acceptance matrix passed eight configurations; its 16 samples rounded to zero and do not measure comparative performance. The earlier main matrix completed eight configurations with five measured samples each. Wrong-output, missing-binding and timeout acceptance checks passed, as did a compiler-option binding. Large timing variation prevents a reliable compiler ranking. General workloads and extra flags for Poly/ML/SML/NJ remain unsupported. |
| Profiles | The versioned Rune profile passed all eight tasks. Regression with corpus Rune completed 16 tasks with 13 passes and the same three documented reference failures. Quick and long retain their earlier acceptance evidence. |

The validated host is x86-64 Linux. Other targets and complete Rune ports of the
reference compilers are not implied by the available adapters. See
[compiler compatibility](docs/compiler-compatibility.md) for the assessed blockers.

Reproduction remains partial. Transitive dependencies can be unobserved, native
tools and system files can drift, and current specifications fingerprint harness
sources rather than proving that the running harness bytecode matches them.
Rebuild after source changes and retain provenance gaps alongside results.
Do not treat traced build duration as a controlled benchmark measurement.
