# Results and manual reruns

This is the acceptance-results snapshot for **2026-09-25**, based on retained
records in this checkout. It covers the four reference compiler selections,
harness cross-checks, shared and expanded Basis suites, HaMLet, and the completed
benchmark experiments. It summarizes validated runs rather than every intermediate
attempt. [README.md](README.md) is the operating manual;
[docs/implementation.md](docs/implementation.md) preserves the development history.

**The harness cross-checks pass. The full regression profile remains nonzero
because it detects documented reference-library differences. The benchmark
workflow passes its acceptance checks, but these timings do not establish a
reliable compiler performance ranking.**

Paths under `_work/` identify local evidence, not files included in Git. They
will be absent in a fresh clone. Reruns create new IDs and preserve earlier
attempts. The instructions below cover both reusing this checkout's compiler
artifacts and rebuilding them elsewhere.

## Contents

- [Overall outcomes](#overall-outcomes)
- [Environment and exact compiler selections](#environment-and-exact-compiler-selections)
- [Harness cross-checks](#harness-cross-checks)
- [Basis correctness results](#basis-correctness-results)
- [HaMLet application results](#hamlet-application-results)
- [Benchmark results](#benchmark-results)
- [How to rerun by hand](#how-to-rerun-by-hand)
- [What remains to do](#what-remains-to-do)

## Overall outcomes

| Profile | Outcome | CLI exit | Whole-profile elapsed time | Evidence directory |
| --- | --- | --- | --- | --- |
| Quick | Passed: harness and shared Rune suite | 0 | 85.59 s | `_work/clean-validation/m6-final-20260925-1/_work/profiles/1790295717536721-B8CB9-1` |
| Regression | 13 tasks passed; 3 tasks failed | 1 | 913.78 s | `_work/profiles/1790295957978059-BC833-1` |
| Long benchmark | 8 configurations passed | 0 | 150.78 s | `_work/profiles/1790296968590004-D73F7-1` |

The quick profile ran in a source-only copy with no existing download cache or
reference compiler artifacts. The other two profiles reused validated stage-2
compilers but rebuilt their workloads. These durations include inventories,
verification, preparation and tests; reference compiler bootstraps are excluded.
They are planning estimates, not isolated compiler-speed measurements.

The three failing regression tasks are `mlton-suite`, `mlton-expanded` and
`poly-expanded`. The first two encounter the same MLton String discrepancy;
the third encounters two Poly/ML discrepancies. Independent tasks still run.
No known failure is silently converted to a pass.

## Environment and exact compiler selections

The long benchmark's `system.record`, `timing-tools.record` and `machine/`
contain the recorded environment. Selected values are:

| Property | Recorded value |
| --- | --- |
| Host | x86-64 Linux under WSL2; kernel `6.18.33.2-microsoft-standard-WSL2` |
| CPU | Intel Xeon E5-1680 v3 @ 3.20 GHz; 8 cores / 16 logical processors reported |
| Memory | 32,812,684 KiB reported by `/proc/meminfo` (about 31.3 GiB) |
| Load at benchmark setup | 1/5/15-minute load averages: **17.85 / 18.02 / 16.73** |
| Rune and runeVM | Both reported `0.3.0`; content identities below distinguish the installation |
| GCC / G++ | 13.3.0, Ubuntu package `13.3.0-6ubuntu2~24.04.1` |
| Make / binutils / strace | GNU Make 4.3 / GNU binutils 2.42 / strace 6.8 |
| Timing and limits | `/usr/bin/time` reported `GNU Time UNKNOWN`; its binary digest is retained. `prlimit` is from util-linux 2.39.3 |
| Child locale and timezone | `LC_ALL=C`, `LANG=C`, `TZ=UTC`; declared inherited variables are recorded |

The host was busy at the recorded snapshot. Our preceding corpus builds had
finished before timed execution; that does not establish an idle WSL host or
exclude unrelated work. CPU frequency, affinity and caches were not controlled.

Recorded SHA-256 identities:

```text
Harness bytecode (regression and long profiles):
  c60d7fec530fbc1fccb7fce8a9fad1b61c7851131a4961704ea0aec06e0fe3db
Rune launcher executable:
  21b81bbe689484f934d9d84a31260b8bda133e8645b3acc86ac0b289bd483289
runeVM executable:
  2004753cd6c7214bd4f2c4e63fa2c5caa61a3cc0135dcfbd1684f81ccf3ef8fd
Rune Basis/payload installation inventory digest:
  0cd451134bfe46507e65a6de201dfdd35744f7ae3a0e7001c15553d31ee7d3c4
```

The installation digest covers the recorded path/content inventory; it is not
a portable release identifier. Rune was replaced during development while its
version string stayed `0.3.0`, so version strings alone cannot reproduce this
snapshot. Keep one matching compiler/VM installation fixed during each run.

The four reference selections all passed their producing stage-2 test attempts.
Their artifact records contain installation manifests, source/patch identities,
configuration, native-tool records and exact bootstrap parents:

| Binding | Reference | Stage-2 artifact record | Exact stage-1 parent |
| --- | --- | --- | --- |
| `smlnj` | SML/NJ 2026.2 | `_work/attempts/1790221321440436-1B95F3-1/artifact.record` | `_work/attempts/1790145223628426-365DB5-1/bootstrap-artifact.record` |
| `legacy` | SML/NJ 110.99.9 | `_work/attempts/1790179540943070-3C272F-1/artifact.record` | `_work/attempts/1790178643595942-3B2171-1/artifact.record` |
| `mlton` | MLton 20241230 | `_work/attempts/1790261891601556-2AF41F-1/artifact.record` | `_work/attempts/1790220837785388-1B5DD6-1/artifact.record` |
| `poly` | Poly/ML 5.9.2 | `_work/attempts/1790221432942235-1B9E51-1/artifact.record` | `_work/attempts/1790220838900951-1B5E27-1/artifact.record` |

SML/NJ and Poly/ML begin from pinned upstream boot inputs plus native tools;
MLton stage 1 uses the recorded external MLton seed, then stage 2 uses its
corpus-built parent. The original modern SML/NJ stage-1 build predates file
tracing; its separately verified bootstrap manifest records that gap. The
stage-2 trace audit found no use of the system SML seeds within its coverage.
This is recorded provenance and PATH isolation, not a hermetic sandbox.

MLton stage 2 passed its smoke test and six selected upstream regressions.
Poly/ML's upstream runner reported 273 passing verdicts, including its treatment
of `NotApplicable` as success. These bootstrap checks are separate from the
cross-checks and Basis results below. See
[compiler compatibility](docs/compiler-compatibility.md) and the package READMEs
for exact build routes and full Rune-port limitations.

## Harness cross-checks

Each `cross-check` compiles and runs the same current fixture sources first with
installed Rune and then with one exact reference compiler. It compares the
**ordered 57 `PASS` lines** and requires the completion marker from both runs.
Raw output, including banners and compiler diagnostics, remains available;
raw outputs are not required to match byte for byte.

| Reference | Rune / reference PASS lines | Comparison | Whole task time | Evidence directory |
| --- | --- | --- | --- | --- |
| SML/NJ 2026.2 | 57 / 57 | Passed | 93.12 s | `_work/cross-checks/1790295975519293-BCBFD-1` |
| SML/NJ 110.99.9 | 57 / 57 | Passed | 49.76 s | `_work/cross-checks/1790296068656486-BF17D-1` |
| MLton 20241230 | 57 / 57 | Passed | 57.07 s | `_work/cross-checks/1790296118447098-BFA36-1` |
| Poly/ML 5.9.2 | 57 / 57 | Passed | 52.45 s | `_work/cross-checks/1790296175545172-C041E-1` |

These fixtures exercise record parsing and rejection, artifact eligibility and
integrity, process arguments and exit statuses, large/partial logs, timeouts,
interruption/retry evidence, system-file tracing, lifecycle oracles, variant
isolation, graph validation, shared experiment builds, source invalidation and
compiler-option identities. They include intentionally failing child commands.
Those fixture failures may appear in `bin/corpus report`; the enclosing fixture
verdict determines whether the harness handled them correctly.

An earlier Poly/ML cross-check failed the orphan-timeout fixture's fixed sleep:
the timeout helper's signal was logged after that wait expired. The fixture now
polls the observable action with a bounded real-time deadline, and all four
final comparisons above passed. See the development history for earlier attempts.
Agreement on these 57 fixtures is evidence about the harness, not proof of every
framework path or the complete SML language/Basis.

## Basis correctness results

The pinned upstream source is SML/NJ regression commit
`95b939dd312452654abf74f9f327842de1a31f62`. The shared selection checks 113
List/Vector/String verdicts. Expanded selection revision 1 includes those checks
and adds seven files: **611 verdicts, 436 named declarations, ten files and
2,318 upstream source lines**. These are nested selections; 113 + 611 is not
724 independent tests.

Explicit validators require `OK`, checked list lengths where applicable, a
successful process and the completion marker. Cross-compiler agreement did not
supply the expected answers. A failed file's validator stops at its first bad
verdict, so the tables report whole-case outcomes rather than inventing a total
number of passed assertions inside that file.

| Expanded case | Verdicts | Rune | SML/NJ 2026.2 | SML/NJ legacy | MLton | Poly/ML |
| --- | --- | --- | --- | --- | --- | --- |
| list | 41 | Pass | Pass | Pass | Pass | Pass |
| vector | 32 | Pass | Pass | Pass | Pass | Pass |
| string | 40 | Pass | Pass | Pass | **Fail** | Pass |
| array | 78 | Pass | Pass | Pass | Pass | Pass |
| listpair | 13 | Pass | Pass | Pass | Pass | Pass |
| stringcvt | 10 | Pass | Pass | Pass | Pass | Pass |
| substring | 68 | Pass | Pass | Pass | Pass | **Fail** |
| word8array | 44 | Pass | Pass | Pass | Pass | Pass |
| word8vector | 32 | Pass | Pass | Pass | Pass | Pass |
| word8 | 253 | Pass | Pass | Pass | Pass | **Fail** |

| Selection | Shared suite | Expanded suite |
| --- | --- | --- |
| Rune | 3/3 cases passed; all 113 verdicts | 10/10 cases passed; all 611 verdicts |
| SML/NJ 2026.2 | 3/3 cases passed; all 113 verdicts | 10/10 cases passed; all 611 verdicts |
| SML/NJ 110.99.9 | 3/3 cases passed; all 113 verdicts | 10/10 cases passed; all 611 verdicts |
| MLton 20241230 | List/Vector passed; String failed | 9/10 cases passed; String failed |
| Poly/ML 5.9.2 | 3/3 cases passed; all 113 verdicts | 8/10 cases passed; Substring and Word8 failed |

### Investigated differences and oracle corrections

- **MLton String:** `String.fromCString "\\q"` returned `SOME ""`; the oracle
  requires `NONE`. The first suite failure is `string.test24`. Its standalone
  reproducer also exited unsuccessfully. See
  [String investigation](packages/smlnj-regressions/95b939d/known-differences.md).
- **Poly/ML Substring:** `Substring.substring` on the empty string with both
  index and length equal to `valOf Int.maxInt` raised `Overflow`; the required
  bounds exception is `Subscript`. The first suite failure is `substring.test30f`.
- **Poly/ML Word8:** `Word8.fromString "0w21"` and hexadecimal `Word8.scan`
  returned the word `0wx21`; the specified valid initial hexadecimal substring
  is `"0"`, giving `SOME 0w0`. The first suite failure is `word8.test13a[5]`.
  See [expanded-suite investigations and normative references](packages/smlnj-regressions/95b939d/suites/basis-expanded/1/known-differences.md)
  for both Poly/ML cases and the reduced programs.

These remain failures. A successful bootstrap or harness comparison does not
override a failed downstream oracle. No reference compiler library was patched
to obtain these results.

The suite itself has reviewed corrections: a List assertion is actually invoked;
`maxLen + 1` accepts arithmetic `Overflow` only when that integer is
unrepresentable; and two inconsistent upstream Word8 hexadecimal-prefix
expectations are corrected. These are documented, ordered input patches used
across the compiler selections. See the
[expanded suite README](packages/smlnj-regressions/95b939d/suites/basis-expanded/1/README.md).
The remaining upstream files require separate selection/oracle review; this is
not a complete Basis conformance claim.

### Suite evidence

Times below are complete traced task durations, including setup and compilation;
use them to estimate rerun cost, not to rank compilers.

| Task | Outcome | Elapsed | Attempt directory |
| --- | --- | --- | --- |
| rune-suite | passed | 15.10 s | `_work/attempts/1790295960338196-BC8B6-1` |
| modern-suite | passed | 10.88 s | `_work/attempts/1790296228036360-C0D59-1` |
| legacy-suite | passed | 8.08 s | `_work/attempts/1790296238950240-C0F39-1` |
| mlton-suite | failed | 41.85 s | `_work/attempts/1790296247064375-C10B6-1` |
| poly-suite | passed | 4.42 s | `_work/attempts/1790296288957253-C148A-1` |
| rune-expanded | passed | 16.78 s | `_work/attempts/1790296569194943-CA960-1` |
| modern-expanded | passed | 38.79 s | `_work/attempts/1790296586013171-CAB0B-1` |
| legacy-expanded | passed | 32.93 s | `_work/attempts/1790296624964153-CBB05-1` |
| mlton-expanded | failed | 194.94 s | `_work/attempts/1790296657868178-CC502-1` |
| poly-expanded | failed | 18.79 s | `_work/attempts/1790296852987909-D0EE2-1` |

## HaMLet application results

HaMLet 2.0.1 exercises a substantial SML interpreter: parsing, elaboration,
modules, evaluation and an interpreted Basis. Both supported corpus recipes
built the application and passed **seven selected checks**: the owned factorial/
list-fold smoke test plus upstream `id`, `overloading`, `flexrecord`, `fun-infix`,
`withtype` and `where` programs. Each requires its completion marker and process
success. This is a selected application suite, not all HaMLet conformance tests.

| Builder | Outcome | Whole traced task time | Attempt directory |
| --- | --- | --- | --- |
| Rune 0.3.0 | 7/7 checks passed | 239.48 s | `_work/attempts/1790296293407717-C15A3-1` |
| Poly/ML 5.9.2 | 7/7 checks passed | 36.24 s | `_work/attempts/1790296532919200-CA5D0-1` |

The original owned smoke incorrectly assumed HaMLet's interpreted Basis supplied
`IntInf`; it was corrected to portable integer arithmetic. The upstream source
was not changed. These task times combine build and tests and are not isolated
HaMLet runtime benchmarks. SML/NJ and MLton HaMLet paths have no corpus recipe
or result here. See [the package documentation](packages/hamlet/2.0.1/README.md).

## Benchmark results

### What was measured

The experiment uses the owned `corpus-stack-1` instruction format. Compiler E
builds an instruction generator; compiler D independently builds its interpreter.
The generator emits a sum-of-squares program, which the interpreter executes.
The oracle is `N * (N + 1) * (2 * N + 1) / 6 * iterations`.

**This main matrix does not measure a Rune-built interpreter against all three
reference families.** Rune is one generator builder. Its generated instruction
stream is interpreted by Poly/ML- or SML/NJ-built runtimes. MLton, legacy SML/NJ
and Rune are absent from the main runtime dimension. A small separate acceptance
case uses a Rune-built runtime, but is not a performance comparison.

The long profile's experiment is
`_work/experiments/1790296971043505-D74A1-1`. Its saved specification and binding
records, rather than a subsequently edited demo, define these results.

| Setting | Value |
| --- | --- |
| Generator builders E | Installed Rune 0.3.0 and corpus Poly/ML 5.9.2 |
| Interpreter builders D | Corpus Poly/ML 5.9.2 and SML/NJ 2026.2 |
| Workload sizes N | 1,000 and 5,000 |
| Iterations per invocation | 5,000 |
| Per configuration | One correctness gate, one warmup, five measured samples |
| Scheduling | Serial commands; configuration order rotates between rounds |
| Limits | 120 seconds and 4,096 MiB virtual address space per generator/interpreter invocation |
| Runtime boundary | Whole command, including startup, instruction parsing and workload |
| Compile boundary | Fresh compiler commands, including linking/export where combined; one observation per distinct build |
| Excluded from compile timing | Acquisition, input preparation, inventories and artifact verification |
| Totals | 8 valid configurations; 40 measured samples; 8 gates and 8 warmups; 4 distinct fresh program builds |

The two generators emitted identical bytes for each N. The corresponding
interpreter artifact is shared across generator choices, so differences between
those rows are not evidence of better generated instructions. Every gate,
warmup and sample matched the oracle: `1669167500000` for N=1,000 and
`208395837500000` for N=5,000 (printed with `CORPUS_STACK_RESULT`).

Timing uses GNU `time`, recording wall/user/system seconds and maximum resident
set size in KiB. Timed commands are untraced. The memory limit is virtual address
space, not RSS; program compilation instead uses the adapter's 600-second
process deadline and has no experiment-imposed memory cap.

### All measured wall-clock samples

Seconds; the five samples are shown in sample-index order. Gates and warmups
are excluded from these summaries.

| Generator builder E | Interpreter builder D | N | Five wall samples (s) | Median (s) | Min–max (s) |
| --- | --- | --- | --- | --- | --- |
| Rune 0.3.0 | Poly/ML 5.9.2 | 1000 | 0.19, 0.15, 0.38, 0.37, 0.30 | 0.30 | 0.15–0.38 |
| Rune 0.3.0 | Poly/ML 5.9.2 | 5000 | 0.84, 0.84, 1.61, 2.69, 3.50 | 1.61 | 0.84–3.50 |
| Rune 0.3.0 | SML/NJ 2026.2 | 1000 | 0.38, 0.34, 0.35, 0.60, 0.74 | 0.38 | 0.34–0.74 |
| Rune 0.3.0 | SML/NJ 2026.2 | 5000 | 1.78, 1.56, 1.52, 5.60, 4.35 | 1.78 | 1.52–5.60 |
| Poly/ML 5.9.2 | Poly/ML 5.9.2 | 1000 | 0.18, 0.22, 0.15, 0.41, 0.48 | 0.22 | 0.15–0.48 |
| Poly/ML 5.9.2 | Poly/ML 5.9.2 | 5000 | 0.91, 0.66, 0.71, 2.17, 1.66 | 0.91 | 0.66–2.17 |
| Poly/ML 5.9.2 | SML/NJ 2026.2 | 1000 | 0.40, 0.30, 0.36, 0.77, 0.36 | 0.36 | 0.30–0.77 |
| Poly/ML 5.9.2 | SML/NJ 2026.2 | 5000 | 1.87, 1.52, 2.43, 3.77, 2.06 | 2.06 | 1.52–3.77 |

### CPU and memory observations

CPU columns are medians of the same five individual samples, calculated for
this report. RSS is the range of per-command maximum RSS; it is not a measurement
of total memory consumed across the experiment. CPU time and elapsed wall time
are different quantities and are retained without normalization.

| Generator | Interpreter | N | User median (s) | System median (s) | Maximum RSS range (KiB) |
| --- | --- | --- | --- | --- | --- |
| rune | poly | 1000 | 0.20 | 0.05 | 15,224–29,664 |
| rune | poly | 5000 | 1.12 | 0.40 | 19,180–54,060 |
| rune | smlnj | 1000 | 0.40 | 0.01 | 50,012–50,092 |
| rune | smlnj | 5000 | 1.92 | 0.02 | 54,488–54,708 |
| poly | poly | 1000 | 0.19 | 0.05 | 13,108–23,932 |
| poly | poly | 5000 | 0.82 | 0.15 | 28,316–36,668 |
| poly | smlnj | 1000 | 0.38 | 0.01 | 49,932–50,092 |
| poly | smlnj | 5000 | 2.20 | 0.02 | 54,524–54,652 |

### Fresh compilation observations

These are single whole-compiler-command wall observations, not repeated timing
samples or compilation regressions. Different builders have different output
formats and startup/link/export boundaries. No compiler ranking follows from
these four numbers.

| Program | Builder | Compiler-command wall time (s) | Observations | Produced program artifact |
| --- | --- | --- | --- | --- |
| generator | Rune 0.3.0 | 5.112 | 1 | `_work/programs/1790296984401695-D74A1-308/artifact.record` |
| generator | Poly/ML 5.9.2 | 0.232 | 1 | `_work/programs/1790296995402875-D74A1-785/artifact.record` |
| interpreter | Poly/ML 5.9.2 | 0.467 | 1 | `_work/programs/1790296999656173-D74A1-1273/artifact.record` |
| interpreter | SML/NJ 2026.2 | 0.635 | 1 | `_work/programs/1790297007632366-D74A1-1761/artifact.record` |

### Pilot and acceptance experiments

The earlier pilot at `_work/experiments/1790264092134613-2B5768-1` passed the
same eight role/size combinations with only 100 iterations per invocation.
Its wall medians were 0.01–0.05 seconds and at least one sample rounded to zero.
It established functional plumbing only and is not pooled with the longer run.
It also predates the recorded Rune installation replacement.

Separate acceptance experiments exercise failure handling:

| Experiment directory under `_work/experiments/` | Test | Recorded outcome |
| --- | --- | --- |
| `1790296872991917-D239E-1` | Rune generator compiled with `--basis all`; Rune interpreter; N=3, iterations=2 | Passed; one gate, one warmup, two samples |
| `1790296917710101-D4D64-1` | Runtime exits zero but prints `WRONG`; second runtime binding is absent | Invalid / unsupported configurations; no warmups, measured samples or timing summaries |
| `1790296943226936-D6D8B-1` | Runtime sleeps beyond its one-second deadline | Invalid at correctness gate; process status `timeout`; no measured samples |

Passing these acceptance checks means the framework rejects the bad cases.
Their benchmark commands correctly return a nonzero exit status for invalid
results. Their tiny timings are not performance measurements.

### Interpretation and limits

All eight main configurations passed correctness, but individual timings varied
substantially: for example, the Rune-generator/SML/NJ-interpreter N=5,000 row
ranges from 1.52 to 5.60 seconds. The high recorded host load and variable samples
are consistent with environmental/runtime variability; these records do not
isolate its cause. Do not infer speedups from the medians, combine the pilot with
the longer run, or treat generator-builder rows as different bytecode quality.

Only one small owned interpreter workload and one machine were measured. There
are five runtime samples per configuration, one fresh compile observation per
build, and no confidence intervals or controlled cold/warm-cache protocol.
Additional measured workloads and a quieter, controlled host are needed for
credible comparative performance conclusions. System identities improve
traceability; full environmental or byte-identical reproducibility is not claimed.

## How to rerun by hand

### 1. Prepare the checkout and installed Rune

Use the current checkout path below, or substitute your clone's location. Run
commands from its root and keep the chosen Rune compiler/VM fixed. Check the
[manual's prerequisites](README.md#invocation-rules-and-setup) and each compiler
package README. Native prerequisites include GCC/G++, make/binutils, curl, tar,
patch, sha256sum, strace and GNU timeout; benchmarks also need GNU time and
`prlimit`. Bootstrap-specific tools/libraries include CMake, autoconf, GMP and
libffi as described by the selected recipes. `doctor` checks declared tools,
versions and host constraints; some native-library/header checks occur only in
upstream configure/build steps.

```sh
cd /home/ruud/rune-corpus-sml97
bin/build
bin/corpus doctor
bin/corpus --help
```

When selecting another installed Rune, set absolute `RUNE` and matching `RUNEVM`
paths before building. Set `CORPUS_RUNE_LIB` if the default inventory location
is inappropriate; this variable identifies the actual Basis/payload for records,
and does not change the compiler's library search. Rebuild after replacing Rune.
`bin/build` regenerates `corpus.mlb` for the LSP.

For the self-contained quick check:

```sh
bin/corpus profile profiles/quick.record
```

Expected baseline outcome: status 0, two passed tasks. To run its constituent
checks individually instead:

```sh
bin/test
bin/corpus test packages/smlnj-regressions/95b939d/rune.record amd64-linux
```

A rerun tests the installation actually supplied now. Matching the historical
version string alone is not an exact replay of the recorded installation.

### 2. Select reference artifacts

For this existing checkout, these are the exact artifacts used above:

```sh
corpus_modern="$PWD/_work/attempts/1790221321440436-1B95F3-1/artifact.record"
corpus_legacy="$PWD/_work/attempts/1790179540943070-3C272F-1/artifact.record"
corpus_mlton="$PWD/_work/attempts/1790261891601556-2AF41F-1/artifact.record"
corpus_poly="$PWD/_work/attempts/1790221432942235-1B9E51-1/artifact.record"
bin/corpus compilers
bin/corpus show "$corpus_poly"
```

These variables remain available only in that shell. Selection verifies the
recorded installation and producing test outcome when the artifact is used.
If the installations were moved, deleted or changed, a record copy alone will
not restore them. Build fresh artifacts using the next subsection and set these
four variables to their new absolute paths.

#### Fresh reference builds

For each compiler, run `doctor` and `test` on its stage-1 recipe, then `test` on
stage 2 using the artifact path printed by the successful stage-1 attempt.
The same procedure applies to these four recipe directories:

| Compiler | Recipe directory | Initial seed |
| --- | --- | --- |
| SML/NJ 2026.2 | `packages/smlnj/2026.2` | Pinned boot files; native tools including CMake/autoconf |
| SML/NJ legacy | `packages/smlnj/110.99.9` | Pinned boot files and supplemental archives; native tools |
| MLton | `packages/mlton/20241230` | Recorded external `/usr/bin/mlton` and `/usr/lib/mlton` for stage 1 only |
| Poly/ML | `packages/polyml/5.9.2` | Pinned bootstrap image; native tools/libraries |

For example, start with Poly/ML, then repeat with each other recipe directory:

```sh
corpus_recipe=packages/polyml/5.9.2
bin/corpus doctor "$corpus_recipe/stage1.record" amd64-linux
bin/corpus test "$corpus_recipe/stage1.record" amd64-linux
```

Wait for a successful `attempt:` result and substitute its ID below:

```sh
corpus_stage1="$PWD/_work/attempts/REPLACE_WITH_STAGE1_ID/artifact.record"
bin/corpus test "$corpus_recipe/stage2.record" amd64-linux "$corpus_stage1"
```

After that passes, set `corpus_poly` (or the corresponding family variable) to
`$PWD/_work/attempts/REPLACE_WITH_STAGE2_ID/artifact.record`. Stage 1 is not eligible
for ordinary cross-checks or workloads. Keep both stages and their ancestors.
Modern SML/NJ's historical `bootstrap-artifact.record` is a recorded exception
for that old attempt, not the filename to guess for a new build.

These operations can take minutes to tens of minutes or longer. The recorded
MLton stage-2 attempt alone took about 30 minutes. Follow step logs rather than
starting duplicate builds. If the required MLton seed is elsewhere, explicitly
review and update the stage-1 seed metadata; do not substitute an unrecorded seed.

### 3. Create local bindings and run the full profile

After setting all four absolute artifact variables, this writes the tab-separated
binding record used by the profile and benchmark commands:

```sh
mkdir -p _work
printf 'corpus-record-v1\nkind\tcompiler-bindings\nrune.compiler\tinstalled-rune\nsmlnj.compiler\t%s\nlegacy.compiler\t%s\nmlton.compiler\t%s\npoly.compiler\t%s\n' \
  "$corpus_modern" "$corpus_legacy" "$corpus_mlton" "$corpus_poly" \
  > _work/results-bindings.record
bin/corpus show _work/results-bindings.record
```

Alternatively, copy `profiles/bindings.example.record` and replace every placeholder
with the corresponding absolute artifact path. Preserve actual tab separators.
Compiler paths in bindings resolve relative to the binding file, not the checkout.

Run the full correctness selection and retain its exit status:

```sh
if bin/corpus profile profiles/regression.record _work/results-bindings.record; then
  printf 'Regression profile passed\n'
else
  corpus_status=$?
  printf 'Regression profile returned %s; inspect its task records\n' "$corpus_status"
fi
```

For the recorded compiler installations and inputs, expect 13 passed tasks and
three failed tasks, with profile status 1. The conditional only lets you inspect
a nonzero result; it does not establish that any new failure is acceptable.
Always check the actual failed cases against the observations above.

### 4. Run individual cross-checks and suites

These are the operations behind the profile, useful for a focused manual rerun:

```sh
bin/corpus cross-check "$corpus_modern"
bin/corpus cross-check "$corpus_legacy"
bin/corpus cross-check "$corpus_mlton"
bin/corpus cross-check "$corpus_poly"
```

Each should print `cross-check passed:` with a new directory. Read its
`comparison.record` for the raw Rune/reference log locations.

Run the shared suite under each reference:

```sh
bin/corpus test packages/smlnj-regressions/95b939d/smlnj.record amd64-linux "$corpus_modern"
bin/corpus test packages/smlnj-regressions/95b939d/smlnj.record amd64-linux "$corpus_legacy"
bin/corpus test packages/smlnj-regressions/95b939d/mlton.record amd64-linux "$corpus_mlton"
bin/corpus test packages/smlnj-regressions/95b939d/polyml.record amd64-linux "$corpus_poly"
```

Run these individually in an interactive shell: the MLton command is expected
to return nonzero for the recorded discrepancy. In scripts using `set -e` or
`&&`, that result would stop later commands. Do not skip their independent runs.

For the expanded selection:

```sh
corpus_suite=packages/smlnj-regressions/95b939d/suites/basis-expanded/1
bin/corpus test "$corpus_suite/rune.record" amd64-linux
bin/corpus test "$corpus_suite/smlnj.record" amd64-linux "$corpus_modern"
bin/corpus test "$corpus_suite/smlnj.record" amd64-linux "$corpus_legacy"
bin/corpus test "$corpus_suite/mlton.record" amd64-linux "$corpus_mlton"
bin/corpus test "$corpus_suite/polyml.record" amd64-linux "$corpus_poly"
```

Expect the MLton and Poly/ML commands to return nonzero for the cases above.
Each invocation retains its new attempt and generated case programs. To rerun
the application checks:

```sh
bin/corpus test packages/hamlet/2.0.1/rune.record amd64-linux
bin/corpus test packages/hamlet/2.0.1/polyml.record amd64-linux "$corpus_poly"
```

Both should pass their selected seven checks.

### 5. Reproduce a library discrepancy in isolation

Build the reduced MLton program:

```sh
bin/corpus program packages/smlnj-regressions/95b939d/reproducers/c-string-invalid-escape.sml "$corpus_mlton"
```

Set the artifact path from `program artifact:` and run it:

```sh
corpus_reproducer=_work/programs/REPLACE_WITH_PRINTED_ID/artifact.record
bin/corpus execute "$corpus_reproducer"
```

The recorded MLton prints `UNEXPECTED SOME ""` and the command returns 1.
Repeat the build/execute pair separately for each Poly/ML reduced program:

```sh
corpus_reproducers=packages/smlnj-regressions/95b939d/suites/basis-expanded/1/reproducers
bin/corpus program "$corpus_reproducers/substring-extreme-bounds.sml" "$corpus_poly"
bin/corpus program "$corpus_reproducers/word8-hex-prefix.sml" "$corpus_poly"
```

Each prints its own program artifact; execute each path individually. Recorded
outputs are `maximum: UNEXPECTED Overflow` / `minimum: Subscript` for the first,
and `UNEXPECTED SOME 21` for both scanning APIs for the second. The latter prints
words in hexadecimal. Both return 1. Building these sources with another eligible
compiler is a separate observation; inspect its own output and result.

### 6. Rerun the benchmark

Finish the correctness/build work first. Inspect the selected matrix without
executing it:

```sh
bin/corpus bench --dry-run experiments/stackvm/demo.record _work/results-bindings.record
```

A dry run still inventories and verifies inputs and writes a new plan, but has
no measured samples. Then run **one** of these equivalent entry points:

```sh
bin/corpus bench experiments/stackvm/demo.record _work/results-bindings.record
```

Or run the profile wrapper:

```sh
bin/corpus profile profiles/long.record _work/results-bindings.record
```

Do not launch both together. The baseline is eight passed configurations with
five measured samples each, not a promise of identical times. Each experiment
builds fresh programs and shares identical dependencies only within that run.
The runner checks for active corpus lifecycle work and locks out a second
benchmark in the checkout; unrelated work and later-started jobs can still compete.

For a different local procedure, copy the demo under `_work/` and edit it before
running. Update `generator.source` and `runtime.source` to absolute source paths
or correct paths relative to the copied specification; copying the file alone
changes its relative-path context. Increase workload size/iterations when timings
are near the timer resolution. Changes define a new experiment and must not be
silently pooled with these observations.

To repeat the small option/wrong-output/timeout acceptance experiments using
this checkout's retained development fixtures:

```sh
bin/corpus bench _work/research/benchmark-validation/flags.record _work/research/benchmark-validation/bindings.record
bin/corpus bench _work/research/benchmark-validation/wrong.record _work/research/benchmark-validation/bindings.record
bin/corpus bench _work/research/benchmark-validation/timeout.record _work/research/benchmark-validation/bindings.record
```

Run them individually: expected command statuses are 0, 1 and 1, respectively.
Those fixture files are local development evidence, not currently tracked test
assets; a clean clone lacks them. Their exact saved specifications/bindings and
source snapshots remain in the three experiment directories listed above.
The following commands recreate equivalent inputs in a fresh checkout using only
installed Rune. Run from the repository root; this writes local fixtures beneath
`_work/results-acceptance/`:

```sh
corpus_acceptance="$PWD/_work/results-acceptance"
mkdir -p "$corpus_acceptance"
cat > "$corpus_acceptance/wrong.sml" <<'SML'
structure Program = struct
  fun main _ = (print "WRONG\n"; OS.Process.success)
end
SML
cat > "$corpus_acceptance/timeout.sml" <<'SML'
structure Program = struct
  fun main _ =
    (OS.Process.sleep (Time.fromSeconds 10);
     print "CORPUS_STACK_RESULT 28\n"; OS.Process.success)
end
SML
printf 'corpus-record-v1\nkind\tcompiler-bindings\nall.compiler\tinstalled-rune\nall.arguments.count\t2\nall.arguments.0\t--basis\nall.arguments.1\tall\nrune.compiler\tinstalled-rune\n' \
  > "$corpus_acceptance/bindings.record"

# Arguments: runtime source, deadline seconds, number of runtime choices, output.
corpus_acceptance_spec() {
  printf 'corpus-record-v1\nkind\tstackvm-experiment\nformat\tcorpus-stack-1\ngenerator.source\t%s\nruntime.source\t%s\ngenerators.count\t1\ngenerators.0\tall\nruntimes.count\t%s\nruntimes.0\trune\nsizes.count\t1\nsizes.0\t3\niterations\t2\nwarmups\t1\nsamples\t2\ntimeout.seconds\t%s\nmemory.mib\t512\n' \
    "$PWD/experiments/stackvm/codegen.sml" "$1" "$3" "$2" > "$4"
}
corpus_acceptance_spec "$PWD/experiments/stackvm/runtime.sml" 15 1 "$corpus_acceptance/flags.record"
corpus_acceptance_spec "$corpus_acceptance/wrong.sml" 15 2 "$corpus_acceptance/wrong.record"
printf 'runtimes.1\tmissing\n' >> "$corpus_acceptance/wrong.record"
corpus_acceptance_spec "$corpus_acceptance/timeout.sml" 1 1 "$corpus_acceptance/timeout.record"
```

Run each command separately and inspect its new experiment's `result.record`,
`configurations/` and `samples/`:

```sh
bin/corpus bench "$corpus_acceptance/flags.record" "$corpus_acceptance/bindings.record"
bin/corpus bench "$corpus_acceptance/wrong.record" "$corpus_acceptance/bindings.record"
bin/corpus bench "$corpus_acceptance/timeout.record" "$corpus_acceptance/bindings.record"
```

The expected statuses are again 0, 1 and 1. Check the configuration outcomes and
absence of measured samples in the invalid runs, as described in the acceptance
table; a nonzero command alone is not enough to verify failure handling.
Promoting these manual checks to a committed automated test target is a follow-up.

### 7. Inspect and retain the new evidence

For a lifecycle attempt, substitute the path printed by your run:

```sh
corpus_attempt=_work/attempts/REPLACE_WITH_PRINTED_ID
bin/corpus report "$corpus_attempt"
bin/corpus show "$corpus_attempt/test-plan.record"
bin/corpus logs "$corpus_attempt" WRONG
bin/corpus export "$corpus_attempt" _work/CHOOSE_A_NEW_FAILURE_BUNDLE.tar.gz
```

Choose a new export filename. `build/suites/ID/CASE/result.record` points to the
case logs; `program.sml` is its generated reproducer. `report` can itself return
success while displaying failed attempts. The existing failure bundles are
`_work/mlton-20241230-c-string-failure.tar.gz` and
`_work/polyml-592-expanded-basis-failures.tar.gz`.

For a cross-check or profile, use `show` on `comparison.record` or `result.record`
and follow their log/task references. For the recorded benchmark:

```sh
corpus_experiment=_work/experiments/1790296971043505-D74A1-1
bin/corpus show "$corpus_experiment/result.record"
bin/corpus show "$corpus_experiment/configurations/4-rune-5-smlnj-5000.record"
bin/corpus show "$corpus_experiment/samples/4-rune-5-smlnj-5000-sample-0.record"
```

Open `REPORT.md` for the compact table. `nodes/` resolves fresh program artifacts;
`plan.record` records their dependencies; `samples/` and `steps/` hold every
sample and command; `system.record`, `timing-tools.record` and `machine/` identify
the host and tools. `compiler-ALIAS.record` snapshots the selected compilers,
whose artifact/attempt records lead to their bootstrap histories.

Lifecycle `export` does not bundle whole experiments. Preserve the experiment
and profile directories, matching corpus sources/recipes, referenced program
and compiler installations, their ancestors and any needed archives separately.
Relative source paths and absolute artifact paths must retain their recorded
context. A result-directory copy alone is not a self-contained reproduction kit.

## What remains to do

The initial Linux roadmap's implementation and acceptance criteria have been
marked complete. That does not make the corpus finished, all reference suites
green, or the performance comparison conclusive. The most useful next work is:

| Priority | Follow-up | Why / completion evidence |
| --- | --- | --- |
| 1 | Resolve or report the three investigated reference-library differences | Review the reduced MLton/Poly/ML cases against their linked specifications; use a new versioned compiler build or justified patch and rerun. Preserve the original failures. No upstream report or vendor fix is claimed here. |
| 1 | Run a representative Rune performance comparison | Add Rune, MLton and legacy SML/NJ runtime choices and meaningful SML applications. The current main matrix has no Rune runtime row and measures only the owned stack workload. |
| 1 | Improve measurement conditions and coverage | Use a quieter host, longer workloads, documented CPU/cache policy and repeated fresh compilations. Collect enough independent runs to assess uncertainty before reporting speedups. |
| 2 | Make the negative benchmark acceptance checks a committed test target | Their current inputs and driver are retained only under ignored `_work/research`; preserve the wrong-answer, timeout, option and unsupported-binding assertions for future checkouts. |
| 2 | Integrate scheduled/CI runs and durable result retention | The caller contract exists; automatic Rune-repository invocation, uploaded artifacts and retention management have not been installed. Editing `../rune` requires human confirmation. |
| 2 | Broaden language/library and application coverage | Review the other upstream Basis files, more HaMLet conformance cases, and HaMLet builds under MLton/SML/NJ; add additional substantial applications with explicit oracles. |
| Later | Add full Rune compiler ports and new adapters | MLton needs a Rune host/Basis/source-list adapter; SML/NJ and Poly/ML require substantial runtime/compiler services. General benchmark formats, other operating systems, and extra flags for SML/NJ/Poly/ML are not implemented. |
| Ongoing | Strengthen provenance and evidence portability | Transitive tracing gaps, compiler-command timing boundaries, untraced timed runs, absolute paths, manual cleanup and the absence of a self-contained experiment export remain limitations. |
| Housekeeping | Review and commit the accepted changes; preserve local evidence | The working changes are not committed by this task. Git ignores `_work`, so archive the evidence/artifacts you need independently. |

No new major prerequisite problem or Rune-source change is required to use the
validated workflows now. Future compatibility work should keep unsupported
configurations explicit, preserve failure evidence, and update the manual and
this dated results snapshot when new accepted results supersede these claims.
