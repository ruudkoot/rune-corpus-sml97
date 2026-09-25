structure Lifecycle =
struct
  exception StepFailed of string
  fun describe (StepFailed s) = s
    | describe (Fail s) = s
    | describe (Record.Invalid s) = s
    | describe (OS.SysErr (s, _)) = s
    | describe (IO.Io {name, function, cause}) = function ^ " " ^ name ^ ": " ^ describe cause
    | describe e = General.exnMessage e
  fun required result = if Process.success result then result
    else raise StepFailed (Process.statusText (#status result) ^ "; logs: " ^ #directory result)
  fun tool steps cwd label program args = required (Process.run
    {parent = steps, label = label, command = {program = Process.resolve program, args = args,
      cwd = cwd, env = Process.environment (), timeoutSeconds = 120}})
  fun fetchSource {root, steps, url, hash} =
    let val cache = root ^ "/_work/downloads"
        val () = Files.mkdir cache
        val path = cache ^ "/" ^ hash ^ ".archive"
        fun verified p = Digest.file {steps = steps, path = p} = hash
    in
      if Files.exists path then
        if verified path then path else raise StepFailed ("cached source checksum mismatch: " ^ path)
      else
        let val dir = Files.freshDir (cache ^ "/pending")
            val pending = dir ^ "/source.archive"
            val () = if String.isPrefix "https://" url orelse String.isPrefix "file://" url
                     then () else raise Fail "source URL must use https:// or file://"
            val _ = tool steps root "download" "curl"
              ["--fail", "--location", "--proto", "=https,file", "--proto-redir", "=https", "--output", pending, url]
        in
          if verified pending then (OS.FileSys.rename {old = pending, new = path}; path)
          else raise StepFailed ("downloaded source checksum mismatch: " ^ pending)
        end
    end
  fun runWithCompiler {root, recipePath, variant, phase, compilerPath} =
    let
      val root = Files.absolute root
      val recipePath = Files.absolute recipePath
      val recipe = Recipe.load recipePath
      val () = if List.exists (fn v => v = variant) (Recipe.variants recipe)
               then () else raise Fail ("unsupported variant: " ^ variant)
      val () = if List.exists (fn p => p = phase) ["fetch", "patch", "build", "test"]
               then () else raise Fail ("unsupported lifecycle phase: " ^ phase)
      val attempt = Files.freshDir (root ^ "/_work/attempts")
      val steps = attempt ^ "/steps"
      val operation = ref "prerequisites"
      val failureClass = ref "infrastructure-failure"
      val base = [("kind", "attempt"), ("package", Recipe.name recipe), ("variant", variant),
                  ("phase", phase), ("recipe", recipePath), ("started", Time.toString (Time.now ())),
                  ("runner.pid", SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ())))] @
                 (case compilerPath of NONE => [] | SOME p => [("compiler.record", Files.absolute p)])
      fun save more = Files.record (attempt ^ "/attempt.record", more @ base)
      val () = save [("status", "running")]
      val () = Files.mkdir steps
      val () = Files.write (attempt ^ "/recipe.record", Record.encode (Recipe.fields recipe))
      fun work () =
        let
          val () = if Doctor.check {root = root, path = recipePath, variant = variant, dir = attempt}
                   then () else raise StepFailed "missing recipe prerequisites; see attempt doctor.record"
          val inventory = Provenance.inventory {steps = steps, destination = attempt ^ "/system.record"}
          val selected = Provenance.selectedTools steps (Record.getStrings (Recipe.fields recipe) "tools")
          val () = Files.record (attempt ^ "/selected-tools.record", selected)
          val toolDirectory = attempt ^ "/host-tools"
          val () = Files.mkdir toolDirectory
          val () = List.app (fn name =>
            let val target = Process.resolve name
                val link = toolDirectory ^ "/" ^ OS.Path.file name
            in if Files.exists link then raise Fail ("duplicate native tool name: " ^ name)
               else Posix.FileSys.symlink {old = target, new = link} end)
            (Record.getStrings (Recipe.fields recipe) "tools")
          val compilerKind = getOpt (Record.find (Recipe.fields recipe) "compiler.kind", "harness-rune")
          val parent = case (compilerKind, compilerPath) of
            ("external-rune-seed", NONE) =>
              if Recipe.get recipe "bootstrap.stage" = "1" andalso Recipe.get recipe "name" = "rune"
              then SOME (Artifact.externalRuneSeed {steps = steps})
              else raise Fail "an installed Rune seed is permitted only for Rune stage 1"
          |
            ("external-seed", NONE) =>
              if Recipe.get recipe "bootstrap.stage" <> "1" then
                raise Fail "an external SML seed is permitted only for stage 1"
              else SOME (Artifact.externalSeed {steps = steps,
                path = Recipe.get recipe "compiler.external.path",
                roots = Record.getStrings (Recipe.fields recipe) "compiler.external.roots",
                base = Recipe.get recipe "compiler.external.root", family = Recipe.get recipe "name"})
          | ("external-seed", SOME _) => raise Fail "external seed recipe does not accept a corpus compiler argument"
          |
            ("corpus", SOME path) => SOME (Artifact.compiler {steps = steps, path = path,
              allowBootstrap = Record.find (Recipe.fields recipe) "bootstrap.stage" = SOME "2"})
          | ("corpus", NONE) => raise Fail "this recipe requires an explicit corpus compiler artifact"
          | ("harness-rune", NONE) => NONE
          | ("native-boot-files", NONE) => NONE
          | (_, SOME _) => raise Fail "this recipe does not accept a corpus compiler artifact"
          | _ => raise Fail ("unsupported compiler selection: " ^ compilerKind)
          val () = case parent of NONE => () | SOME r =>
            Files.record (attempt ^ "/compiler-input.record", r)
          val () = case parent of NONE => () | SOME r =>
            (Recipe.checkCompiler recipe r handle e =>
              (failureClass := "unsupported"; raise e))
          val parentHash = case compilerPath of NONE =>
              (case parent of NONE => "not-applicable" | SOME r =>
                Digest.text {steps = steps, value = Record.encode r})
            | SOME p => Digest.file {steps = steps, path = p}
          val systemHash = Digest.text {steps = steps, value = Record.encode
            (List.filter (fn (k, _) => k <> "captured") inventory)}
          val recipeHash = Digest.file {steps = steps, path = recipePath}
          val patchPaths = List.map (Recipe.expand [("root", root)])
            (Record.getStrings (Recipe.fields recipe) "patches")
          val patchHashes = List.map (fn p => Digest.file {steps = steps, path = p}) patchPaths
          val ownedInputs = if Option.isSome (Record.find (Recipe.fields recipe) "inputs.count")
            then Record.getStrings (Recipe.fields recipe) "inputs" else []
          val ownedHashes = Digest.files {steps = steps,
            paths = List.map (Recipe.expand [("root", root)]) ownedInputs}
          val harnessPaths = "sources.txt" :: "src/main.sml" ::
            List.filter (fn s => size s > 0)
              (String.tokens (fn c => c = #"\n") (Files.read (root ^ "/sources.txt")))
          val harnessHashes = Digest.files {steps = steps,
            paths = List.map (fn p => root ^ "/" ^ p) harnessPaths}
          val harnessHash = Digest.text {steps = steps,
            value = Record.encode (Record.strings "sources" (List.map #2 harnessHashes))}
          val () = operation := "fetch"
          val archive = fetchSource {root = root, steps = steps,
            url = Recipe.get recipe "source.url", hash = Recipe.get recipe "source.sha256"}
          val archives = List.map (fn (name, url, hash) =>
            (name, fetchSource {root = root, steps = steps, url = url, hash = hash})) (Recipe.archives recipe)
          val source = attempt ^ "/source"
          val build = attempt ^ "/build"
          val () = Files.mkdir source
          val () = Files.mkdir build
          val bindings = [("root", root), ("source", source), ("build", build),
                          ("tools", toolDirectory),
                          ("rune", Process.resolve "rune"), ("runevm", Process.resolve "runevm"),
                          ("variant", variant)] @ (case parent of NONE => [] | SOME r =>
                            [("compiler", Record.require r "path"),
                             ("compiler.record", case compilerPath of SOME p => Files.absolute p
                                | NONE => attempt ^ "/compiler-input.record"),
                             ("compiler.root", Record.require r "root"),
                             ("compiler.bin", OS.Path.dir (Record.require r "path"))] @
                             List.mapPartial (fn key => Option.map
                               (fn value => ("compiler." ^ key, value)) (Record.find r key))
                               ["runtime.path", "library.path"])
          val selectedHash = Digest.text {steps = steps, value = Record.encode selected}
          val inputs = [("kind", "build-specification"), ("recipe.sha256", recipeHash),
                      ("source.sha256", Recipe.get recipe "source.sha256"), ("variant", variant),
                      ("harness.compiler", Process.resolve "rune"), ("system.sha256", systemHash),
                      ("selected-tools.sha256", selectedHash),
                      ("compiler.kind", compilerKind),
                      ("compiler.record.sha256", parentHash),
                      ("compiler.content.sha256", case parent of NONE => "not-applicable"
                        | SOME r => Record.require r "content.sha256"),
                      ("builder", getOpt (Record.find (Recipe.fields recipe) "builder", "installed:rune")),
                      ("harness.sha256", harnessHash)] @ Record.strings "patch.sha256" patchHashes @
                      Record.strings "inputs.sha256" (List.map #2 ownedHashes) @
                      Record.strings "environment" (Process.environment ())
          val specId = Digest.text {steps = steps, value = Record.encode inputs}
          val () = Files.record (attempt ^ "/specification.record", ("id", specId) :: inputs)
          fun prepare () =
            (operation := "extract";
             ignore (tool steps root "extract" "tar"
              ["--extract", "--file", archive, "--directory", source,
               "--strip-components=" ^ getOpt (Record.find (Recipe.fields recipe) "source.strip-components", "1"),
               "--no-same-owner", "--no-same-permissions"]);
             List.app (fn (name, path) => ignore (tool steps source ("supplementary archive:" ^ name)
               "cp" ["--", path, source ^ "/" ^ name])) archives;
             operation := "patch";
             List.app (fn path => ignore (tool steps source "patch" "patch"
               ["--batch", "--forward", "-p1", "--input", Files.absolute path]))
               patchPaths)
          fun commands key =
            let
              val planned = Recipe.commands recipe key bindings
              val states = Array.array (length planned, "pending")
              fun plan () = Files.record (attempt ^ "/" ^ key ^ "-plan.record",
                [("kind", "command-plan"), ("phase", key)] @
                  Record.strings "status" (Array.foldr op:: [] states))
              val () = plan ()
              fun loop (_, []) = ()
                | loop (i, c :: cs) =
                  let
                    val () = operation := key ^ ":" ^ Int.toString i
                    val () = failureClass := (if key = "test" then "test-failure" else "build-failure")
                    val () = Array.update (states, i, "running")
                    val () = plan ()
                    fun execute () =
                    let
                    val toolPath = Process.resolve
                      (if String.isSubstring "/" (#program c) andalso
                          not (OS.Path.isAbsolute (#program c))
                       then OS.Path.concat (#cwd c, #program c) else #program c)
                    val hash = Digest.file {steps = steps, path = toolPath}
                    val p = Process.runIdentified {parent = steps, label = key ^ ":" ^ Int.toString i,
                      command = c, identity = [("selected.executable", toolPath),
                                              ("selected.sha256", hash),
                        ("trace.files", getOpt (Record.find (Recipe.fields recipe) "trace.files", "false"))]}
                    val () = Files.record (#directory p ^ "/executable.record",
                      [("path", toolPath), ("sha256", hash), ("kind", "direct-executable")])
                    val () = if #status p = Process.TimedOut then failureClass := "timeout" else ()
                    val () = if Files.exists (#directory p ^ "/files.trace.log") then
                      (ignore (SystemArtifacts.capture {steps = steps,
                        trace = #directory p ^ "/files.trace.log",
                        destination = #directory p ^ "/system-artifacts.record"})
                       handle e => Files.record (#directory p ^ "/system-artifacts.record",
                         [("kind", "observed-system-artifacts"), ("provenance.gaps", General.exnMessage e)]))
                      else ()
                    val _ = required p
                    val prefix = key ^ "." ^ Int.toString i
                    val () = if key = "test" then
                  let val expected = Recipe.get recipe (prefix ^ ".stdout")
                          val actual = Process.output p
                          val matches = case Record.find (Recipe.fields recipe) (prefix ^ ".stdout.mode") of
                            NONE => actual = expected | SOME "exact" => actual = expected
                          | SOME "contains" => size expected > 0 andalso String.isSubstring expected actual
                          | SOME other => raise Fail ("unknown stdout oracle: " ^ other)
                      in if matches then () else raise StepFailed
                        ("output mismatch; logs: " ^ #directory p) end else ()
                    in () end
                    val () = execute () handle e =>
                      (Array.update (states, i, "failed");
                       Array.modify (fn s => if s = "pending" then "blocked" else s) states;
                       plan (); raise e)
                    val () = Array.update (states, i, "passed")
                    val () = plan ()
                  in loop (i + 1, cs) end
            in loop (0, planned) end
          fun artifact () =
            let val path = Recipe.expand bindings (Recipe.get recipe "artifact")
                val hash = Digest.file {steps = steps, path = path}
                val kind = getOpt (Record.find (Recipe.fields recipe) "artifact.kind", "program")
                val compilerFields = if kind = "compiler" orelse kind = "compiler-bootstrap" then
                  [("bootstrap.stage", Recipe.get recipe "bootstrap.stage"),
                   ("bootstrap.seed", Recipe.get recipe "bootstrap.seed"),
                   ("family", Recipe.get recipe "name"), ("version", Recipe.get recipe "version"),
                   ("target", Recipe.get recipe "target"), ("word.size", Recipe.get recipe "word.size"),
                   ("configuration", Recipe.get recipe "configuration"),
                   ("compiler.parent", case compilerPath of NONE =>
                      if compilerKind = "external-seed" orelse compilerKind = "external-rune-seed"
                      then attempt ^ "/compiler-input.record"
                      else "upstream-boot-files"
                      | SOME p => Files.absolute p),
                   ("source.sha256", Recipe.get recipe "source.sha256"),
                   ("system", attempt ^ "/system.record")] @
                  List.mapPartial (fn (input, output) => Option.map
                    (fn value => (output, Recipe.expand bindings value))
                    (Record.find (Recipe.fields recipe) input))
                    [("artifact.runtime", "runtime.path"), ("artifact.library", "library.path"),
                     ("source.commit", "source.commit")] @
                  Artifact.snapshot {steps = steps, base = source,
                    roots = List.map (Recipe.expand bindings)
                      (Record.getStrings (Recipe.fields recipe) "artifact.roots")}
                  else []
            in Files.record (attempt ^ "/artifact.record",
                 [("kind", kind), ("attempt", attempt),
                  ("path", path), ("sha256", hash),
                  ("package", Recipe.name recipe), ("variant", variant),
                  ("specification", attempt ^ "/specification.record")] @ compilerFields) end
        in
          if phase = "fetch" then () else
            (prepare (); if phase = "patch" then () else
              (commands "build";
               (case parent of SOME r =>
                  if Record.find (Recipe.fields recipe) "compiler.verify-after-build" = SOME "true"
                  then Artifact.verify {steps = steps, record = r} else ()
                | NONE => ());
               artifact (); if phase = "test" then commands "test" else ()))
        end
    in
      (work (); save [("status", "passed"), ("finished", Time.toString (Time.now ()))]; attempt)
      handle e => (save [("status", "failed"), ("error", describe e),
                         ("failure.class", !failureClass), ("operation", !operation),
                         ("finished", Time.toString (Time.now ()))];
                   raise StepFailed (describe e ^ "; attempt: " ^ attempt))
    end
  fun run {root, recipePath, variant, phase} =
    runWithCompiler {root = root, recipePath = recipePath, variant = variant,
                     phase = phase, compilerPath = NONE}
end
