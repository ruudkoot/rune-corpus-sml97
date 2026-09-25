# SML/NJ legacy 110.99.9

**These recipes bootstrap from SML/NJ's upstream boot files and rebuild with
SML/NJ.** Rune runs the corpus harness that orchestrates the build. There is no
implemented Rune-hosted SML/NJ build, including a reduced-feature one.

This is the latest official **legacy** release, verified on 2026-09-23. It is
included alongside development version 2026.2 at the user's request. Both use
family `smlnj`, with distinct version, recipe, installation and result identities.
The legacy compiler retains its MLRISC backend; it does not share the newer
version's LLVM build.

- [Official release](https://smlnj.org/dist/working/110.99.9/)
- [Installation instructions](https://smlnj.org/dist/working/110.99.9/install.html)
- [Legacy source repository](https://github.com/smlnj/legacy)
- License: upstream BSD-style license and bundled component licenses.

The official distribution consists of separate archives. `stage1.record` pins
the configuration archive, AMD64 boot image and all 16 source/documentation
components used by the selected targets. SHA-256 values were computed from the
official HTTPS downloads; no separately published upstream digests were found.
All are verified before use. The standard installer's download fallback is
disabled using its supported `URLGETTER` setting, so a missing component fails
instead of introducing an unpinned download.

The initial variant is `amd64-linux`: native x86-64 Linux, 64-bit words and the
upstream default targets. Required tools are listed and fingerprinted in the
recipe. Native commands run with a PATH containing only declared tools, with
strace recording system files opened by the build. No system SML compiler is
selected. `compiler-sources.patch` requests compiler, CM and system sources
individually so stage 2 has its inputs. Upstream's broader `src-smlnj` option
fetches every optional component. The patch changes no compiler code. The dependency graph reader (`pgraph`) is
also pinned for the CM self-build. `bootstrap.sml` invokes the same CMB entry
point as upstream but turns a false result into a failing exit status; upstream
`cmb-make` can return success after a compilation error.

`doctor`, `fetch`, `patch`, `build` and `test` are thin Rune harness launchers.
They accept an optional variant. `stage1.record` invokes upstream
`config/install.sh -default 64` and performs the shared semantic smoke checks.
This produces a bootstrap artifact only. Stage 2, downstream validation,
reference harness cross-checks and coexistence with 2026.2 have passed.

Compiling this compiler's sources with Rune needs a port. Its CM bootstrap
machinery, MLRISC integration and dedicated runtime need adaptation; the source
assessment is recorded in the compatibility notes below.
Recommended larger checks are the upstream compiler regressions,
SML/NJ library tests and compiler self-build. Measured costs and Rune blockers
are recorded in those notes.

Both versions now have validated stage-2 artifacts and passed harness
cross-checks. The separately acquired regression subset passed 113 semantic
checks under each version. See [compatibility and evidence](../../../docs/compiler-compatibility.md)
for exact attempt identities, tested routes, observed costs and Rune blockers.
