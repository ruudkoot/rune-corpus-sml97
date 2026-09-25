structure HarnessTest =
struct
  fun sourceList root path =
    List.map (fn s => root ^ "/" ^ s)
      (String.tokens (fn c => c = #"\n") (Files.read (root ^ "/" ^ path)))
  fun quoted s = "\"" ^ String.toString s ^ "\""
  fun run artifactPath =
    let
      val root = OS.FileSys.getDir ()
      val work = Files.freshDir (root ^ "/_work/cross-checks")
      val steps = work ^ "/steps"
      val reference = Artifact.compiler {steps = steps, path = artifactPath, allowBootstrap = false}
      val family = Record.require reference "family"
      val compiler = Record.require reference "path"
      val sources = sourceList root "sources.txt" @ sourceList root "tests/sources.txt"
      fun command label program args = Lifecycle.required (Process.run
        {parent = steps, label = label, command = {program = program, args = args,
          cwd = root, env = Process.environment (), timeoutSeconds = 600}})
      val baseline = work ^ "/rune-tests.rbc"
      val _ = command "compile harness tests with installed Rune" "rune" (sources @ ["-o", baseline])
      val runeResult = command "Rune harness tests" "runevm" [baseline]
      val driver = work ^ "/driver.sml"
      val () = Files.write (driver,
        "val () = ((List.app use [" ^ String.concatWith "," (List.map quoted sources) ^
        "]; OS.Process.exit OS.Process.success) handle e => " ^
        "(TextIO.output (TextIO.stdErr, General.exnMessage e ^ \"\\n\"); OS.Process.exit OS.Process.failure));\n")
      val result = case family of
        "rune" =>
          let val bytecode = work ^ "/reference-tests.rbc"
              val _ = command "compile harness tests with corpus Rune" compiler (sources @ ["-o", bytecode])
          in command "corpus Rune harness tests" (Artifact.runeRuntime reference) [bytecode] end
      | "smlnj" => command "SML/NJ harness tests" compiler [driver]
      | "polyml" => command "Poly/ML harness tests" compiler ["--script", driver]
      | "mlton" =>
          let val mlb = work ^ "/tests.mlb"
              val executable = work ^ "/mlton-tests"
              val () = Files.write (mlb, "$(SML_LIB)/basis/basis.mlb\n" ^
                String.concatWith "\n" (List.map quoted sources) ^ "\n")
              val _ = command "compile harness tests with MLton" compiler ["-output", executable, mlb]
          in command "MLton harness tests" executable [] end
      | _ => raise Fail ("no harness test adapter for compiler family: " ^ family)
      fun verdicts r = List.filter (String.isPrefix "PASS ")
        (String.tokens (fn c => c = #"\n") (Process.output r))
      fun completed r = String.isSubstring "CORPUS_HARNESS_TESTS_COMPLETE" (Process.output r)
      val passed = completed runeResult andalso completed result andalso
        not (null (verdicts result)) andalso verdicts runeResult = verdicts result
      val () = Files.record (work ^ "/comparison.record",
        [("kind", "harness-cross-check"), ("reference.artifact", Files.absolute artifactPath),
         ("reference.content.sha256", Record.require reference "content.sha256"),
         ("reference.family", family), ("reference.version", Record.require reference "version"),
         ("harness.compiler", Process.resolve "rune"), ("harness.runtime", Process.resolve "runevm"),
         ("rune.logs", #directory runeResult), ("reference.logs", #directory result),
         ("normalization", "compare ordered PASS lines and require completion marker; retain all raw output"),
         ("status", if passed then "passed" else "test-failure")])
    in if passed then print ("cross-check passed: " ^ work ^ "\n")
       else raise Fail ("harness cross-check mismatch: " ^ work) end
end
