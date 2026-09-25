(* Build an owned SML program exposing Program.main : string * string list ->
   OS.Process.status. Compiler-specific export details stay in this adapter. *)
signature CORPUS_PROGRAM =
sig
  val build : {root : string, source : string, compilerArtifact : string,
               trace : bool} -> string
  val buildWithArguments : {root : string, source : string, compilerArtifact : string,
                           trace : bool, arguments : string list} -> string
  val command : {record : Record.t, args : string list, timeout : int} -> Process.command
  val execute : {root : string, artifact : string, args : string list} -> Process.result
end

structure Program :> CORPUS_PROGRAM =
struct
  fun quote s = "\"" ^ String.toString s ^ "\""
  val nativeTools = ["sh", "bash", "gcc", "g++", "as", "ld", "ar", "ranlib",
    "cat", "sed", "awk", "dirname", "basename", "rm", "cp", "mv", "uname",
    "grep", "readlink", "file", "mkdir", "chmod", "touch", "env", "timeout", "strace"]
  fun buildWithArguments {root, source, compilerArtifact, trace, arguments = extraArguments} =
    let
      val root = Files.absolute root
      val source = Files.absolute source
      val () = if compilerArtifact = "installed-rune" then raise Fail
        "workloads require a corpus compiler artifact; installed Rune is for the harness and bootstrap" else ()
      val compilerArtifact = Files.absolute compilerArtifact
      val work = Files.freshDir (root ^ "/_work/programs")
      val steps = work ^ "/steps"
      val () = Files.mkdir steps
      val base = [("kind", "program-build"), ("source", source),
                  ("compiler.artifact", compilerArtifact)]
      fun state status more = Files.record (work ^ "/attempt.record", ("status", status) :: base @ more)
      val () = state "running" []
      fun buildProgram () =
        let
          val compiler = Artifact.compiler {steps = steps, path = compilerArtifact, allowBootstrap = false}
          val family = Record.require compiler "family"
          val () = if null extraArguments orelse family = "rune" orelse family = "mlton" then ()
            else raise Fail ("extra program compiler arguments are unsupported for " ^ family)
          val executable = Record.require compiler "path"
          val system = Provenance.inventory {steps = steps, destination = work ^ "/system.record"}
          val () = Files.record (work ^ "/compiler-input.record", compiler)
          val selected = Provenance.selectedTools steps nativeTools
          val () = Files.record (work ^ "/selected-tools.record", selected)
          val tools = work ^ "/host-tools"
          val () = Files.mkdir tools
          val () = List.app (fn name => Posix.FileSys.symlink
            {old = Process.resolve name, new = tools ^ "/" ^ name}) nativeTools
          val env = ["PATH=" ^ OS.Path.dir executable ^ ":" ^ tools,
                     "TMPDIR=" ^ work, "RUNE=" ^ (if family = "rune" then executable else Process.resolve "rune"),
                     "RUNEVM=" ^ (if family = "rune" then Artifact.runeRuntime compiler else Process.resolve "runevm")] @
            List.filter (fn s => not (List.exists (fn p => String.isPrefix p s)
              ["PATH=", "TMPDIR=", "RUNE=", "RUNEVM="])) (Process.environment ())
          val original = Files.read source
          val () = Files.write (work ^ "/source.sml", original)
          val sourceHash = Digest.file {steps = steps, path = work ^ "/source.sml"}
          val specification = [("kind", "program-specification"), ("source.sha256", sourceHash),
            ("family", family), ("compiler.record.sha256", Digest.file
              {steps = steps, path = work ^ "/compiler-input.record"}),
            ("tools.sha256", Digest.text {steps = steps, value = Record.encode selected}),
            ("trace.files", Bool.toString trace),
            ("measurement", "compiler command only; includes linking where the adapter combines phases")] @
            Record.strings "compiler.arguments" extraArguments
          val () = Files.record (work ^ "/specification.record", specification)
          val compilation = ref ([] : string list)
          fun run label program args =
            let
              val hash = Digest.file {steps = steps, path = program}
              val r = Process.runIdentified {parent = steps, label = label,
                identity = [("selected.sha256", hash), ("trace.files", Bool.toString trace)],
                command = {program = program, args = args, cwd = work, env = env, timeoutSeconds = 600}}
              val () = compilation := #directory r :: !compilation
              val () = if trace then
                (ignore (SystemArtifacts.capture {steps = steps, trace = #directory r ^ "/files.trace.log",
                  destination = #directory r ^ "/system-artifacts.record"})
                 handle e => Files.record (#directory r ^ "/system-artifacts.record",
                   [("kind", "observed-system-artifacts"), ("provenance.gaps", Lifecycle.describe e)]))
                else ()
            in Lifecycle.required r end
          val entry = work ^ "/entry.sml"
          val output = work ^ "/program"
          val tail = "\nval () = OS.Process.exit (Program.main (CommandLine.name (), CommandLine.arguments ()));\n"
          val (payload, runner, arguments) = case family of
            "rune" =>
              let val () = Files.write (entry, original ^ tail)
                  val _ = run "compile" executable (extraArguments @ [entry, "-o", output ^ ".rbc"])
              in (output ^ ".rbc", Artifact.runeRuntime compiler, [output ^ ".rbc"]) end
          | "mlton" =>
              let val () = Files.write (entry, original ^ tail)
                  val _ = run "compile-and-link" executable (extraArguments @ ["-output", output, entry])
              in (output, output, []) end
          | "polyml" =>
              let val () = Files.write (entry, original ^
                    "\nfun main () = OS.Process.exit (Program.main (CommandLine.name (), CommandLine.arguments ()));\n")
                  val _ = run "compile-and-link" (OS.Path.dir executable ^ "/polyc")
                    ["-b", executable, "-o", output, entry]
              in (output, output, []) end
          | "smlnj" =>
              let
                val suffixResult = Lifecycle.required (Process.run {parent = steps, label = "heap suffix",
                  command = {program = executable, args = ["@SMLsuffix"], cwd = work, env = env, timeoutSeconds = 30}})
                val suffix = String.concat (String.tokens Char.isSpace (Process.output suffixResult))
                val () = if size suffix > 0 andalso List.all
                  (fn c => Char.isAlphaNum c orelse c = #"-") (String.explode suffix)
                  then () else raise Fail "invalid SML/NJ heap suffix"
                val () = Files.write (entry, "val () = (use " ^ quote (work ^ "/source.sml") ^
                  " handle e => (TextIO.output(TextIO.stdErr, General.exnMessage e ^ \"\\n\"); " ^
                  "OS.Process.exit OS.Process.failure));\nval _ = SMLofNJ.exportFn (" ^ quote output ^
                  ", Program.main);\nval () = OS.Process.exit OS.Process.success;\n")
                val _ = run "compile-and-export" executable [entry]
              in (output ^ "." ^ suffix, executable, ["@SMLload=" ^ output]) end
          | _ => raise Fail ("unsupported program compiler family: " ^ family)
          val manifest = Artifact.snapshot {steps = steps, roots = [payload], base = work}
          val artifact = [("kind", "runnable-program"), ("family", family), ("attempt", work),
            ("compiler.artifact", compilerArtifact), ("compiler.input", work ^ "/compiler-input.record"),
            ("specification", work ^ "/specification.record"), ("path", payload),
            ("run.program", runner), ("run.program.sha256", Digest.file {steps = steps, path = runner}),
            ("run.cwd", work), ("system", work ^ "/system.record"),
            ("provenance.gaps", if trace then "consult per-step observed system dependencies and their gaps"
              else "untraced timing build; selected tools and compiler manifest recorded, transitive files not observed")] @
            Record.strings "run.args" arguments @ Record.strings "run.env" env @
            Record.strings "compile.logs" (List.rev (!compilation)) @ manifest
          val path = work ^ "/artifact.record"
          val () = Files.record (path, artifact)
        in state "passed" [("artifact", path)]; path end
    in buildProgram () handle e =>
      (state "failed" [("error", Lifecycle.describe e)]; raise Fail (Lifecycle.describe e ^ "; program build: " ^ work)) end
  fun build {root, source, compilerArtifact, trace} =
    buildWithArguments {root = root, source = source, compilerArtifact = compilerArtifact,
                        trace = trace, arguments = []}
  fun command {record, args, timeout} =
    {program = Record.require record "run.program", args = Record.getStrings record "run.args" @ args,
     cwd = Record.require record "run.cwd", env = Record.getStrings record "run.env", timeoutSeconds = timeout}
  fun execute {root, artifact, args} =
    let val r = Files.load artifact
        val work = Files.freshDir (Files.absolute root ^ "/_work/program-runs")
        val steps = work ^ "/steps"
        val () = if Record.require r "kind" = "runnable-program" then ()
                 else raise Fail "expected a runnable-program artifact"
        val () = Artifact.verify {steps = steps, record = r}
        val () = if Digest.file {steps = steps, path = Record.require r "run.program"} =
                    Record.require r "run.program.sha256" then ()
                 else raise Fail "program runtime executable changed"
        val parent = Record.require r "compiler.artifact"
        val () = if parent = "installed-rune" then raise Fail
          "historical installed-Rune programs must be rebuilt with a corpus Rune artifact"
          else ignore (Artifact.compiler {steps = steps, path = parent, allowBootstrap = false})
        val result = Process.run {parent = steps, label = "program execution",
          command = command {record = r, args = args, timeout = 120}}
        val () = Files.record (work ^ "/result.record", [("kind", "program-run"),
          ("artifact", Files.absolute artifact), ("logs", #directory result),
          ("status", Process.statusText (#status result))])
    in result end
end
