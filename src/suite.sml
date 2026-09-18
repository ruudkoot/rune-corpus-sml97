(* Semantic suites use explicit validators, not captured output from a candidate. *)
structure Suite =
struct
  fun quote s = "\"" ^ String.toString s ^ "\""
  fun run {metadata, source, build, compilerArtifact} =
    let
      val suite = Files.load metadata
      val work = Files.freshDir (build ^ "/suites")
      val steps = work ^ "/steps"
      val () = Files.mkdir steps
      val reference = if compilerArtifact = "installed-rune" then NONE
        else SOME (Artifact.compiler {steps = steps, path = compilerArtifact, allowBootstrap = false})
      val family = case reference of NONE => "rune" | SOME r => Record.require r "family"
      val compiler = case reference of NONE => Process.resolve "rune" | SOME r => Record.require r "path"
      val common = [("kind", "correctness-suite"), ("suite", Files.absolute metadata),
        ("source", source), ("family", family), ("compiler.artifact", compilerArtifact)]
      val () = Files.record (work ^ "/result.record", ("status", "running") :: common)
      val cases = Record.getStrings suite "cases"
      val () = if null cases then raise Fail "a suite must contain cases" else ()
      fun command label program args cwd = Process.runIdentified
        {parent = steps, label = label, identity = [("selected.executable", Process.resolve program)],
         command = {program = program, args = args, cwd = cwd,
                    env = Process.environment (), timeoutSeconds = 120}}
      fun one name =
        let
          val directory = work ^ "/" ^ name
          val () = if size name > 0 andalso List.all Char.isAlphaNum (String.explode name)
                   then () else raise Fail "invalid suite case name"
          val () = Files.mkdir directory
          val file = directory ^ "/program.sml"
          val input = source ^ "/" ^ Record.require suite (name ^ ".source")
          val validator = OS.Path.dir (Files.absolute metadata) ^ "/" ^
            Record.require suite (name ^ ".validator")
          val code = "structure Subject = struct\n" ^ Files.read input ^
            "\nend;\n" ^ Files.read validator
          val () = Files.write (file, code)
          val marker = "CORPUS_CASE_PASS " ^ name
          val () = Files.write (file, code ^ "\nval () = print " ^ quote (marker ^ "\n") ^ ";\n")
          val current = ref "compile"
          val evidence = ref ([] : (string * string) list)
          fun record (p : Process.result) phase =
            (evidence := (phase ^ ".logs", #directory p) :: !evidence; p)
          fun execute () =
            let
              val result = case family of
                "rune" =>
                  let val out = directory ^ "/program.rbc"
                      val _ = Lifecycle.required (record (command (name ^ ":compile") compiler
                        [file, "-o", out] directory) "compile")
                      val () = current := "run"
                  in record (command (name ^ ":run") (Process.resolve "runevm") [out] directory) "run" end
              | "mlton" =>
                  let val out = directory ^ "/program"
                      val _ = Lifecycle.required (record (command (name ^ ":compile") compiler
                        ["-output", out, file] directory) "compile")
                      val () = current := "run"
                  in record (command (name ^ ":run") out [] directory) "run" end
              | "smlnj" =>
                  let val driver = directory ^ "/driver.sml"
                      val () = Files.write (driver, "val () = ((use " ^ quote file ^
                        "; OS.Process.exit OS.Process.success) handle e => " ^
                        "(TextIO.output(TextIO.stdErr, General.exnMessage e ^ \"\\n\"); " ^
                        "OS.Process.exit OS.Process.failure));\n")
                      val () = current := "compile-and-run"
                  in record (command (name ^ ":compile-and-run") compiler [driver] directory) "run" end
              | "polyml" =>
                  (current := "compile-and-run";
                   record (command (name ^ ":compile-and-run") compiler ["--script", file] directory) "run")
              | _ => raise Fail ("unsupported suite compiler family: " ^ family)
              val _ = Lifecycle.required result
              val lines = String.tokens (fn c => c = #"\n") (Process.output result)
            in if List.exists (fn line => line = marker) lines then "passed"
               else raise Fail "semantic validation did not reach its completion marker" end
          val error = ref ""
          val status = execute () handle e =>
            (error := Lifecycle.describe e;
             if String.isPrefix "timeout" (!error) then "timeout"
             else if !current = "compile" then "compile-failure" else "test-failure")
          val () = Files.record (directory ^ "/result.record",
            [("kind", "suite-case"), ("case", name), ("status", status), ("phase", !current),
             ("error", !error), ("source", input), ("validator", validator),
             ("program.sha256", Digest.file {steps = steps, path = file})] @ !evidence)
          val () = print (name ^ ": " ^ status ^ " (" ^ directory ^ ")\n")
        in (name, status) end
      val results = List.map one cases
      val passed = List.all (fn (_, status) => status = "passed") results
      val () = Files.record (work ^ "/result.record",
        [("status", if passed then "passed" else "test-failure")] @ common @
        Record.strings "cases" (List.map (fn (name, status) => name ^ "\t" ^ status) results))
    in if passed then print "CORPUS_SUITE_PASS\n"
       else raise Fail ("suite failures: " ^ work ^ "/result.record") end
end
