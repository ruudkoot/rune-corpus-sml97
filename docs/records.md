# Record format v1

For concepts, commands and complete workflows, start with [the manual](../README.md).

Records start with `corpus-record-v1` and a newline. Every subsequent line is a
key, one tab, an escaped value, and a newline. Keys contain letters, digits,
periods, underscores, or hyphens. Duplicate keys, malformed escapes, NUL bytes,
unknown versions, and incomplete final lines are rejected. Writers sort keys.

Values escape backslash, newline, carriage return, and tab as `\\`, `\n`, `\r`,
and `\t`. Lists use `name.count` followed by `name.0` through `name.N`. Counts
must be nonnegative canonical decimal integers. Numeric quantities are stored
as text so timestamps and digests do not depend on the host's integer width.

## Implemented record kinds

| Kind | Identity and contents |
| --- | --- |
| package | Name/version, variants, pinned URL/checksum, patches, build/test argv, output artifact and test expectations. |
| process | Unique directory per execution; command/argv/cwd/environment, resolved executable and supervisor, PID, times, status, stdout.log and stderr.log. |
| attempt | Unique directory per requested lifecycle run; package/variant/phase, recipe snapshot, outcome, error, timestamps, system inventory and steps. |
| system-inventory | Paths, versions and binary hashes of available tools, complete Rune Basis/payload file hashes, environment description and provenance gaps. This is an inventory, not a claim that every listed tool was used. |
| build-specification | Recipe/source/patch/system/harness fingerprints and selected variant/compiler. Its ID hashes the canonical input record, excluding the ID itself. |
| program | Produced file path and content digest, package/variant, and the specification record of its producing attempt. |
| compiler / compiler-bootstrap | Entry point and complete file manifest under declared installation roots; family/version/target/word size/configuration, bootstrap stage and exact parent artifact, source identity, producing attempt and system inventory. Selection verifies contents and requires a passed test attempt. Stage 1 is accepted only for a declared stage-2 bootstrap. |
| command-plan | Indexed command states: pending, running, passed, failed and blocked. Persisted at command boundaries. |
| observed-system-artifacts | Hashes of readable system paths observed by the Linux trace adapter, unresolved paths and explicit coverage gaps. Full raw traces remain in the step directory. |
| harness-cross-check | Exact reference artifact identity, Rune/reference raw logs, verdict and documented output normalization. |
| semantic-suite | Case names, upstream source paths, owned validator paths and descriptive assertion counts. |
| correctness-suite / suite-case | Selected compiler, individual verdicts, generated reproducer digest and compile/run log paths. Nested under the enclosing lifecycle attempt's build directory. |
| program-build / program-specification | Owned source snapshot, selected builder, native tools and compilation evidence, under `_work/programs/`. This adapter has a separate specification schema from package builds. |
| runnable-program | Output manifest, exact builder, runtime executable/hash, launch arguments, environment and working directory. This is the artifact accepted by `execute`. |
| program-run | Selected runnable artifact, process status and raw log path, under `_work/program-runs/`. A zero exit is not a semantic oracle. |
| failure-groups | Groups of similar observed diagnostics, method description and member attempt paths. These are investigation aids, not established root causes. |
| profile | An ordered `tasks` list. Each task declares `.kind` (harness, recipe, cross-check or benchmark), `.timeout` and the relevant recipe/variant, compiler-binding name or experiment. Recipe/experiment paths resolve from the repository root. |
| profile-result / profile-task | Overall and per-task verdicts, selected profile and bindings, orchestrator bytecode digest, times and child process log locations. Independent tasks continue after failure. |
| stackvm-experiment / compiler-bindings | Independent generator/runtime alias lists, owned source paths, workload sizes, iterations, warmups, sample count and execution limits. Bindings resolve aliases to exact compiler artifacts (or installed Rune), with optional `ALIAS.arguments` lists for Rune/MLton program compilation. |
| experiment-plan / experiment-node-result | Ordered dependencies and recorded input identities, exclusions, shared builds, produced bytecode and run/result references. Sharing is confined to one experiment. |
| benchmark-result / benchmark-configuration / benchmark-sample | Overall validity, configuration correctness and individual samples. Units are seconds and KiB; invalid configurations retain logs but are excluded from timing summaries. |

Attempt IDs are generated using time, process ID and a local sequence; directory
creation reserves the ID. They are distinct from specification IDs and output
hashes. Equal recorded specifications are not proof of deterministic builds.

## Initial recipe fields

`kind=package`, `name`, `version`, `source.url`, `source.sha256`, `variants`,
`patches`, `tools`, `artifact`, `build.count`, and `test.count` are required. Here `=`
illustrates a mapping; the on-disk separator is a tab. Each command has
`PHASE.N.program`, `.args.count` and indexed arguments, `.cwd`, and `.timeout`
in seconds. Each test also has `.stdout`, the exact expected output. An explicit
`.stdout.mode=contains` permits a nonempty marker for interactive compilers;
the process must also exit successfully. This is weaker than an exact oracle.

The substitutions `{root}`, `{source}`, `{build}`, `{variant}`, `{tools}`, `{rune}` and
`{runevm}` are expanded in command fields and artifact paths. Patch paths accept
`{root}`. Substitution results are argv elements, never shell source. Explicit
upstream shell scripts remain possible using a selected shell program.

Acquisition accepts HTTPS and local file URLs, verifies SHA-256 before use, and
keeps the archive by digest. Extraction defaults to stripping one archive path
component; `source.strip-components` can override this with a nonnegative integer.
Optional `archives` list entries name supplementary archives, each with
`archive.NAME.url` and `.sha256`; they are verified and copied into the fresh
source directory under the declared name for the upstream installer to consume.
Patches are applied in listed order to that fresh
tree. Build and test commands execute sequentially; a failed step stops its
dependent steps. Independent attempts can be invoked separately.

`inputs` optionally lists owned input files whose hashes enter the specification.
`host` optionally requires an exact `uname -m`/`uname -s` pair, such as
`x86_64-Linux`. `minimum.TOOL` requests a dotted numeric minimum version check.
Tools declared in `tools` are fingerprinted separately from the global inventory.

`compiler.kind` selects `installed-rune`, `native-boot-files`, `corpus`, or
`external-seed`. The last is permitted only for stage-1 recipes and declares
`compiler.external.path`, `.root` and `.roots`; its snapshot records stage 0.
The current default is `installed-rune`; package recipes should state the kind
explicitly. Corpus selection requires a fourth lifecycle argument naming the
exact compiler artifact record. Its manifest and producing validation attempt
are checked, then `{compiler}`, `{compiler.root}`, `{compiler.bin}` and `{compiler.record}` become
available. The full parent record and its digest are preserved in the attempt.
Optional lists `compiler.families`, `compiler.versions` and `compiler.targets`
constrain selection; a mismatch records an unsupported configuration. Compiler
stage-2 recipes declare these explicitly.

`environment.isolated=true` restricts child PATH to the declared tool links in
`{tools}`. An optional `environment.path.prefix` can prepend a corpus compiler
directory; include the trailing colon. No system SML seed is linked unless a
recipe explicitly declares it. This is PATH isolation, not a filesystem sandbox.
`environment.set` optionally declares a list of `NAME=VALUE` settings with recipe
substitutions. Isolated recipes also receive absolute selected `RUNE` and `RUNEVM`
paths, preserving installed wrapper behavior. Other allowed environment values
remain recorded. `trace.files=true` requires
strace and retains per-step Linux file/process traces and system-file hashes.
This tracing adds overhead and is intended for provenance, not benchmark timing.

Compiler-producing recipes also declare `artifact.kind`, `artifact.roots`,
`bootstrap.stage`, `bootstrap.seed`, `target`, `word.size` and `configuration`.
Installation manifests include file contents; they do not promise reproducible
metadata or byte-identical output. Builds are always fresh at present.

The record header versions the serialization format. Readers reject unsupported
format versions. Record kinds above describe the implemented interfaces;
additive fields can be introduced without changing that header. Automation
should select by kind, use named fields, tolerate extra fields, and retain the
matching corpus checkout for a rerun. A future incompatible field or command
change must document migration rather than silently reinterpreting old records.
