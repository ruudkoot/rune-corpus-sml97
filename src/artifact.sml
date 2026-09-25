signature CORPUS_ARTIFACT =
sig
  val snapshot : {steps : string, roots : string list, base : string} -> Record.t
  val verify : {steps : string, record : Record.t} -> unit
  val compiler : {steps : string, path : string, allowBootstrap : bool} -> Record.t
  val runeRuntime : Record.t -> string
  val externalSeed : {steps : string, path : string, roots : string list,
                      base : string, family : string} -> Record.t
  val externalRuneSeed : {steps : string} -> Record.t
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
  fun contained record path =
    let val root = Record.require record "root"
        val absolute = OS.Path.mkCanonical (OS.Path.mkAbsolute {path = path, relativeTo = root})
    in List.exists (fn line => case String.fields (fn c => c = #"\t") line of
         [file, _] => OS.Path.mkCanonical (OS.Path.concat (root, file)) = absolute
       | _ => false) (Record.getStrings record "files") end
  fun runeRuntime record =
    let val path = Record.require record "runtime.path"
    in if Record.require record "family" = "rune" andalso contained record path then path
       else raise Fail "Rune runtime must belong to the selected compiler manifest" end
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
      val () = if Record.find r "family" = SOME "rune" then
        let val version = Record.require r "version"
            val () = if size version = 40 andalso List.all
              (fn c => Char.isDigit c orelse c >= #"a" andalso c <= #"f") (String.explode version)
              andalso Record.require r "source.commit" = version then ()
              else raise Fail "Rune version must be its full source commit hash"
            val _ = runeRuntime r
            val library = Record.require r "library.path"
        in if contained r (Record.require r "path") andalso contained r (library ^ "/basis/MANIFEST")
           then () else raise Fail "Rune compiler and Basis must belong to the selected manifest" end
        else ()
    in r end
  fun externalSeed {steps, path, roots, base, family} =
    let val path = Process.resolve path
        val manifest = snapshot {steps = steps, roots = roots, base = base}
        val probe = Process.run {parent = steps, label = "external bootstrap seed identity",
          command = {program = path, args = if family = "rune" then ["--version"] else [], cwd = OS.FileSys.getDir (),
                     env = Process.environment (), timeoutSeconds = 15}}
    in [("kind", "external-compiler-seed"), ("bootstrap.stage", "0"), ("family", family),
        ("path", path), ("sha256", Digest.file {steps = steps, path = path}),
        ("version.output", Process.output probe ^ Files.read (#directory probe ^ "/stderr.log")),
        ("version.status", Process.statusText (#status probe)),
        ("usage", "stage-1 bootstrap only; never a corpus test or workload compiler")] @ manifest end
  fun externalRuneSeed {steps} =
    let val compiler = Process.resolve "rune"
        val runtime = Process.resolve "runevm"
        val library = Files.absolute (getOpt (OS.Process.getEnv "CORPUS_RUNE_LIB",
          OS.Path.concat (OS.Path.dir compiler, "../lib/rune")))
        val seed = externalSeed {steps = steps, path = compiler,
          roots = [compiler, runtime, library], base = "/", family = "rune"}
    in [("runtime.path", runtime), ("library.path", library)] @ seed end
end
