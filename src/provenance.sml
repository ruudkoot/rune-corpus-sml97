structure Provenance =
struct
  type tool = {name : string, path : string, digest : string, version : string}
  fun captureTool {steps, name, args} : tool =
    let val path = Process.resolve name
        val hash = Digest.file {steps = steps, path = path}
        val result = Process.run {parent = steps, label = "version:" ^ name, command =
          {program = path, args = args, cwd = OS.FileSys.getDir (), env = Process.environment (),
           timeoutSeconds = 15}}
        val text = Process.output result ^ Files.read (#directory result ^ "/stderr.log")
    in {name = name, path = path, digest = hash,
        version = if Process.success result then text
                  else "probe " ^ Process.statusText (#status result) ^ ": " ^ text} end
  fun fields prefix ({name, path, digest, version} : tool) =
    [(prefix ^ ".name", name), (prefix ^ ".path", path),
     (prefix ^ ".sha256", digest), (prefix ^ ".version", version)]
  val tools = [("rune", ["--version"]), ("runevm", ["--version"]),
               ("gcc", ["--version"]), ("g++", ["--version"]), ("make", ["--version"]),
               ("as", ["--version"]), ("ld", ["--version"]), ("ar", ["--version"]),
               ("curl", ["--version"]), ("tar", ["--version"]),
               ("patch", ["--version"]), ("sha256sum", ["--version"]),
               ("timeout", ["--version"]), ("strace", ["--version"]), ("uname", ["-a"])]
  fun selectedTools steps names =
    let
      fun one (i, name) =
        fields ("selected." ^ Int.toString i)
          (captureTool {steps = steps, name = name, args = ["--version"]})
      fun loop (_, []) = []
        | loop (i, name :: rest) = one (i, name) @ loop (i + 1, rest)
    in ("selected.count", Int.toString (length names)) :: loop (0, names) end
  fun runeInstallation steps =
    let
      val lib = Files.absolute (getOpt (OS.Process.getEnv "CORPUS_RUNE_LIB",
        OS.Path.concat (OS.Path.dir (Process.resolve "rune"), "../lib/rune")))
      fun walk path = if OS.FileSys.isDir path then
        List.concat (List.map (fn n => walk (OS.Path.concat (path, n))) (Files.entries path))
        else [path]
      val paths = walk (lib ^ "/basis") @
        (if Files.exists (lib ^ "/rune.rbc") then [lib ^ "/rune.rbc"] else [])
      val hashes = Digest.files {steps = steps, paths = paths}
      (* Record a sorted, complete file list without assuming distinct contents. *)
      fun insert (x : string, []) = [x]
        | insert (x, y :: ys) = if String.< (x, y) then x :: y :: ys else y :: insert (x, ys)
      val lines = List.foldl (fn ((p, h), acc) => insert (p ^ " " ^ h, acc)) [] hashes
      val digest = Digest.text {steps = steps, value = String.concatWith "\n" lines}
    in [("rune.library.path", lib), ("rune.installation.sha256", digest)] @
       Record.strings "rune.files" lines end
  fun inventory {steps, destination} =
    let
      fun one (i, (name, args)) =
        (fields ("tool." ^ Int.toString i) (captureTool {steps = steps, name = name, args = args})
         handle e => [("tool." ^ Int.toString i ^ ".name", name),
                      ("tool." ^ Int.toString i ^ ".error", General.exnMessage e)])
      fun indexed (_, []) = []
        | indexed (i, x :: xs) = one (i, x) @ indexed (i + 1, xs)
      val installation = runeInstallation steps handle e =>
        [("rune.installation.error", General.exnMessage e)]
      val result = [("kind", "system-inventory"), ("tool.count", Int.toString (length tools)),
                    ("captured", Time.toString (Time.now ())),
                    ("provenance.gaps", "inventory excludes transitive dependencies; consult per-step system-artifacts.record and raw traces where present; untraced steps have incomplete transitive provenance")]
                   @ indexed (0, tools) @ installation
    in Files.record (destination, result); result end
end
