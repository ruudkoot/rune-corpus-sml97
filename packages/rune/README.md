# Rune compiler artifacts

Rune versions in this corpus are full Git commit hashes, including unreleased
commits. Both selected commits still print `0.3.0`; that banner is not their
corpus version. Sources are pinned official GitHub commit archives with recorded
SHA-256 digests. The main Rune working tree is never used as a source directory.

| Version | Meaning |
| --- | --- |
| `b5ec8c8833e906cd3fe636a49e20b7c8474596dc` | Requested earlier compiler revision |
| `e840204151663baf1139c8096b566301e9ced37d` | Requested middle-end M8 revision |

## Bootstrap and runtime identities

Installed Rune remains the builder and runner of the corpus harness and the
preferred initial Rune bootstrap seed. Its compiler launcher, VM, compiler
payload and complete library tree are hashed in the stage-1 seed record. Keep
that installation fixed until the build finishes; the seed manifest is verified
again after compilation.

Stage 1 compiles the pinned compiler sources with the installed seed's Basis
and executes that compiler on a copied seed VM. Its wrapper selects the pinned
commit's library when compiling other programs. Consequently its **hosting VM**
and its **target VM** can differ: a separately built pinned VM runs the smoke
program. Both are captured in the stage-1 manifest. Stage 1 is bootstrap-only.

Stage 2 uses exactly the same commit's validated stage-1 artifact, a fresh copy
of the pinned sources and a freshly built C VM. Its installation contains the
self-hosted compiler, matching VM and Basis. Validation compiles and runs the
owned smoke and recompiles the compiler, comparing its bytecode with stage 2.
A passing self-reproduction check is local evidence, not a claim of complete
build reproducibility across machines. Neither recipe runs all upstream tests.

`version` and `source.commit` identify the commit. `runtime.path` and
`library.path` identify members of the compiler's verified installation manifest.
The reported `--version` strings remain upstream's unmodified values.

## Build either version

From the corpus root, with installed Rune and matching runevm, GCC and the native
tools listed in the recipes:

```sh
bin/build
corpus_version=b5ec8c8833e906cd3fe636a49e20b7c8474596dc
bin/corpus doctor "packages/rune/$corpus_version/stage1.record" amd64-linux
bin/corpus test "packages/rune/$corpus_version/stage1.record" amd64-linux
```

Set the exact path printed by the passed stage-1 attempt, then run stage 2:

```sh
corpus_stage1="$PWD/_work/attempts/REPLACE_WITH_STAGE1_ID/artifact.record"
bin/corpus test "packages/rune/$corpus_version/stage2.record" amd64-linux "$corpus_stage1"
bin/corpus compilers
```

Repeat with `corpus_version=e840204151663baf1139c8096b566301e9ced37d` and a new
stage-1 artifact. Passing a different commit's stage 1 is rejected. Preserve each
stage-2 artifact and its ancestors. `RUNE`, `RUNEVM` and `CORPUS_RUNE_LIB` select
the external harness/seed installation as documented in the main manual; they
do not identify a corpus Rune version.

Both commits have passed stages 1 and 2, including smoke and self-reproduction
checks. Use a passed stage-2 artifact with `cross-check`, `program`, the Rune suite and
HaMLet recipes, or compiler bindings. These adapters select the artifact's VM;
they never run its bytecode on the installed harness VM. For both versions,
fill `rune-old` and `rune-new` in `profiles/bindings.example.record`, then run:

```sh
bin/corpus profile profiles/rune-versions.record _work/my-bindings.record
bin/corpus bench experiments/stackvm/rune-versions.record _work/my-bindings.record
```

The profile covers harness cross-checks, both Basis selections and HaMLet. The
small benchmark verifies independent generator/runtime version selection. See
`RESULTS.md` and `docs/implementation.md` for dated acceptance evidence.
