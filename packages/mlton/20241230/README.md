# MLton 20241230

The recipe builds compiler, runtime, Basis and libraries with the declared seed,
then builds auxiliary tools with `SELF_COMPILE=true` using that new compiler and
its bundled libraries. An earlier attempt built the compiler successfully but
failed when auxiliary tools selected a library omitted from the installed seed.
The corrected route keeps the full toolset and needs no additional system SML
package. Native compiler temporary files are retained under the attempt's build
directory through `TMPDIR`.

[20241230 is the latest official release](https://www.mlton.org/Release20241230),
verified on 2026-09-23. The recipe uses the project's release source asset,
not a development branch. The checksum was computed from the HTTPS download;
the GitHub asset API did not provide a separately published digest.

The source `README.adoc`, `Makefile` and `Makefile.config` document the supported
bootstrap routes. Upstream recommends an existing MLton; SML/NJ, Poly/ML and
MLKit routes are also available. This recipe uses `/usr/bin/mlton` and its
`/usr/lib/mlton` installation strictly as stage 0, preserving a full manifest
and version output. This initial seed layout is specific to the tested Debian/
Ubuntu environment. Native prerequisites include GCC supporting GNU C11, GNU
Make/Bash/binutils and the GMP development headers/library.

Stage 1 and stage 2 use fresh source trees and `BOOTSTRAP_STYLE=0`, the documented
single-generation build, with `OLD_MLTON` set to the exact selected compiler.
Stage 2 selects the verified stage-1 artifact. It does not include an installed
SML compiler in its PATH. These explicit stages avoid conflating upstream's
default multiple-generation build with the corpus provenance model.

Both recipes preserve native file/process traces and system-file hashes.
The only current source patch is the regression TMPDIR adjustment described
below. Smoke validation compiles and runs a small arithmetic/array/IntInf program.
Stages 1 and 2, the selected upstream subset, harness cross-check and recorded
seed-independence audit have passed. The separate shared suite retains an
investigated String.fromCString failure; see the
[compatibility notes](../../../docs/compiler-compatibility.md). Recommended
larger suites are the upstream correctness regressions and benchmark programs;
their measured costs will be recorded during M2.

The wrapper commands currently address stage 1. Stage 2 uses
`bin/corpus test packages/mlton/20241230/stage2.record amd64-linux
PATH/TO/STAGE1/artifact.record`. A successful stage-1 result is bootstrap-only.

Rune compatibility is not claimed. A direct Rune build needs an MLB adapter and
a host-service adapter based on the existing alternative-host stubs and verified
Basis coverage. The compatibility notes identify those requirements; that adapter
is not implemented. The upstream build paths remain intact.

Stage 2 additionally runs upstream `bin/regression` on array, list, vector,
string, int-inf.0 and int-inf.bitops. Each has a pinned `.ok` oracle, and none
is in the upstream whitelist. Nonzero compilation or output differences fail
the attempt. The full negative-test mode is excluded because its exit flag is
updated in a subshell; accepting its exit status would miss unexpected accepts.
`regression-tmpdir.patch` makes upstream's temporary-output location honor the
recorded TMPDIR. It changes no test expectation. Native runtime compilation uses
four jobs; compiler/Basis/tool phases stay ordered.
