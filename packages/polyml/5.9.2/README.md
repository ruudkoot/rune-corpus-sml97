# Poly/ML 5.9.2

**These recipes bootstrap from Poly/ML's upstream image and rebuild with
Poly/ML.** Rune runs the corpus harness that orchestrates the build. There is no
implemented Rune-hosted Poly/ML build, including a reduced-feature one.

Pinned to the latest official release checked on 2026-09-23. The
[release](https://github.com/polyml/polyml/releases/tag/v5.9.2) and
[installation instructions](https://www.polyml.org/download.html) describe the
native runtime and bundled bootstrap route. The official tagged source archive
has SHA-256 `5cf5f77767568c25cf880acc2d0a32ee3d399e935475ab1626e8192fc3b07390`,
computed after downloading over HTTPS. See upstream `COPYING` for LGPL terms.

The initial variant is `amd64-linux`, using GCC/G++, GMP and a static Poly/ML
runtime library. Installation stays inside the attempt's source tree. The
recipe declares its native tools and traces their system-file use. Other
platforms and optional X/Motif bindings are not declared supported.

`stage1.record` configures and builds the native runtime, imports the bundled
`bootstrap64.txt`, and runs upstream bootstrap stages 1–7. It needs no installed
SML compiler. The resulting compiler is restricted to bootstrap use.

`stage2.record` starts from fresh sources and builds a fresh native runtime and
`polyimport`. The exact stage-1 compiler then runs `bootstrap/Stage6.sml`, which
rebuilds the compiler and Basis and exports `polyexport.o`. Make links and
installs that object. Building `polyimport` before exporting the object avoids
Make falling back to the distributed boot image. The final compiler runs a
semantic smoke test and upstream `Tests/RunTests.sml`, including positive and
negative compilation tests. The upstream runner's `NotApplicable` behavior is
retained; it is not a claim that every platform-specific case ran.

Use the thin `doctor`, `fetch`, `patch`, `build`, and `test` launchers for stage 1.
For stage 2, run `bin/corpus test packages/polyml/5.9.2/stage2.record amd64-linux
PATH/TO/STAGE1/artifact.record`. Both stages have passed. Stage 2 reported 273
upstream verdicts, subject to the runner's applicability behavior above; the
harness cross-check and shared 113 semantic assertions have also passed.
Exact evidence is recorded in [implementation notes](../../../docs/implementation.md).

There are no source patches. Compiling Poly/ML's sources with Rune needs a port:
Poly/ML's compiler and Basis depend on its compiler namespace, runtime calls,
export mechanism and platform backends. The
[compatibility assessment](../../../docs/compiler-compatibility.md) identifies
the concrete entry points. A full port is a separate project.
Recommended larger workloads are the full regression suite, compiler self-build,
and Isabelle formalizations; each needs explicit version and dependency pins.
