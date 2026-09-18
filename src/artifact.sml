signature CORPUS_ARTIFACT =
sig
  val snapshot : {steps : string, roots : string list, base : string} -> Record.t
  val verify : {steps : string, record : Record.t} -> unit
  val compiler : {steps : string, path : string, allowBootstrap : bool} -> Record.t
  val externalSeed : {steps : string, path : string, roots : string list,
                      base : string, family : string} -> Record.t
end

structure Artifact :> CORPUS_ARTIFACT =
struct
  fun snapshot {steps, roots, base} =
    let
      val paths = Files.sorted (List.concat (List.map Files.tree roots))
      val hashes = Digest.files {steps = steps, paths = paths}
      val relative = List.map (fn (p, h) =>
        OS.Path.mkRelative {path = p, relativeTo = base} ^ "\t" ^ h) hashes
      val manifest = Record.strings "files" relative
      val hash = Digest.text {steps = steps, value = Record.encode manifest}
    in [("root", base), ("content.sha256", hash)] @ manifest end
  fun verify {steps, record} =
    let
      val base = Record.require record "root"
      val manifest = Record.strings "files" (Record.getStrings record "files")
      val recorded = Record.require record "content.sha256"
      val actual = Digest.text {steps = steps, value = Record.encode manifest}
      val () = if recorded = actual then () else raise Fail "artifact manifest checksum mismatch"
      fun parse line = case String.fields (fn c => c = #"\t") line of
        [path, hash] =>
          if Digest.valid hash then (OS.Path.concat (base, path), hash)
          else raise Fail "invalid artifact file checksum"
      | _ => raise Fail "invalid artifact file entry"
      val expected = List.map parse (Record.getStrings record "files")
      val hashes = Digest.files {steps = steps, paths = List.map #1 expected}
    in if hashes = expected then () else raise Fail "artifact contents have changed" end
  fun compiler {steps, path, allowBootstrap} =
    let
      val r = Files.load path
      val kind = Record.require r "kind"
      val stage = Record.require r "bootstrap.stage"
      val () = if kind = "compiler" andalso stage = "2" orelse
                  allowBootstrap andalso kind = "compiler-bootstrap" andalso stage = "1"
               then () else raise Fail "compiler selection requires a corpus stage-2 artifact (stage 1 is bootstrap-only)"
      val attempt = Files.load (Record.require r "attempt" ^ "/attempt.record")
      val () = if Record.require attempt "status" = "passed" andalso
                  Record.require attempt "phase" = "test"
               then () else raise Fail "compiler artifact has not passed its validation attempt"
      val () = verify {steps = steps, record = r}
    in r end
  fun externalSeed {steps, path, roots, base, family} =
    let val path = Process.resolve path
        val manifest = snapshot {steps = steps, roots = roots, base = base}
        val probe = Process.run {parent = steps, label = "external bootstrap seed identity",
          command = {program = path, args = [], cwd = OS.FileSys.getDir (),
                     env = Process.environment (), timeoutSeconds = 15}}
    in [("kind", "external-compiler-seed"), ("bootstrap.stage", "0"), ("family", family),
        ("path", path), ("sha256", Digest.file {steps = steps, path = path}),
        ("version.output", Process.output probe ^ Files.read (#directory probe ^ "/stderr.log")),
        ("version.status", Process.statusText (#status probe)),
        ("usage", "stage-1 bootstrap only; never a corpus test or workload compiler")] @ manifest end
end
