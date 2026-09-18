# SML/NJ 2026.2

Pinned on 2026-09-23 to the latest official release, **2026.2**, from the
development channel. The older stable channel is 110.99.9. This choice follows
the roadmap's latest-release policy; it does not imply production stability.

- [Release and source archive](https://smlnj.org/dist/working/2026.2/)
- [Official installation instructions](https://smlnj.org/dist/working/2026.2/install.html)
- Bootstrap instructions: `README.md`, `build.sh`, and `system/README` in the
  pinned source archive. The archive includes its custom LLVM 21 sources and
  `boot.amd64-unix.tgz`; these are inputs, not independently validated compilers.
- License: upstream BSD-style license, plus licenses of bundled components.
- SHA-256: `7155fb359f985fc814c4a846fb19e10da163371355b98e37b2bf59e8c9f5284d`.
  Computed from the official HTTPS archive; the release page did not provide a
  separately published digest.

The initial supported variant is `amd64-linux`, a native x86-64 Linux build.
It requires a C/C++17 compiler, GNU Make, CMake >= 3.23, autoconf >= 2.71,
and the common corpus acquisition tools. `doctor` checks executable availability;
the currently tested host has GCC 13.3.0, CMake 3.28.3 and autoconf 2.71.
Other host/target combinations are not declared supported.

`./doctor`, `./fetch`, `./patch`, `./build`, and `./test` dispatch through the
Rune harness; they accept an optional variant. Run `bin/build` at the repository
root first. Every invocation is a fresh attempt and retains its logs. No source
patches are currently required. The LLVM build uses four parallel jobs to keep
memory use bounded on the development machine.

## Bootstrap status

`stage1.record` builds LLVM and the native runtime, then links the distributed
boot files using upstream `build.sh`. The resulting artifact is explicitly a
`compiler-bootstrap` at stage 1. It must not be selected for corpus workloads
or harness cross-checks. Its smoke test exercises recursive functions, lists,
arbitrary precision integers, exceptions and arrays, and requires both a zero
exit status and a success marker.

`stage2.record` uses fresh sources and copies the stage-1 installation, preserving
the original. It invokes the CMB entry point with the exact stage-1 compiler, then
`makeml` and `installml -clean -boot`, and rebuilds libraries using `build.sh`.
Run it with `bin/corpus test packages/smlnj/2026.2/stage2.record amd64-linux
PATH/TO/STAGE1/artifact.record`. Stage-2 validation has passed. There is no dependency
on system-installed SML/NJ in this route.

`bootstrap.sml` follows upstream `system/cmb-make` but explicitly turns a false
`CMB.make` result into a failing exit status. This prevents interactive compiler
errors being mistaken for a successful self-build.

## Validation and Rune compatibility

Bootstrap validation, a shared upstream subset, downstream compilation and
the harness cross-check have passed. Recommended broader suites are the upstream
compiler regression tests and SML/NJ library tests, followed by the full compiler
self-build as a larger workload. Recorded costs are in the compatibility notes.

Building SML/NJ directly with Rune is not claimed. Its compiler uses CM, compiler
internals, generated boot files and a dedicated native runtime. A source-level
compatibility assessment is recorded in the compatibility notes below.

Both versions now have validated stage-2 artifacts and passed harness
cross-checks. The separately acquired regression subset passed 113 semantic
checks under each version. See [compatibility and evidence](../../../docs/compiler-compatibility.md)
for exact attempt identities, tested routes, observed costs and Rune blockers.
