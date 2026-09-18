(* Profiles are explicit, serial collections of existing corpus operations.
   Independent tasks continue after failure and retain their own child logs. *)
structure Profile =
struct
  fun run {root, specification, bindings} =
    let
      val root = Files.absolute root
      val specification = Files.absolute specification
      val metadata = Files.load specification
      val () = if Record.require metadata "kind" = "profile" then () else raise Fail "expected a profile record"
      val names = Record.getStrings metadata "tasks"
      val () = if null names then raise Fail "profile has no tasks" else ()
      fun distinct ([], _) = ()
        | distinct (name :: rest, seen) =
            if size name = 0 orelse not (List.all
              (fn c => Char.isAlphaNum c orelse c = #"-") (String.explode name))
              orelse List.exists (fn n => n = name) seen then raise Fail "invalid or duplicate profile task"
            else distinct (rest, name :: seen)
      val () = distinct (names, [])
      val bindingPath = Option.map Files.absolute bindings
      val selected = case bindingPath of NONE => [] | SOME path => Files.load path
      val () = case bindingPath of NONE => () | SOME _ =>
        if Record.require selected "kind" = "compiler-bindings" then () else raise Fail "expected compiler bindings"
      val work = Files.freshDir (root ^ "/_work/profiles")
      val steps = work ^ "/steps"
      val () = Files.mkdir steps
      val () = Files.mkdir (work ^ "/tasks")
      val () = Files.record (work ^ "/profile.record", metadata)
      val () = Files.record (work ^ "/bindings.record", selected)
      val base = [("kind", "profile-result"), ("profile", specification),
        ("bindings", getOpt (bindingPath, "none")), ("started", Time.toString (Time.now ())),
        ("harness.bytecode.sha256", Digest.file {steps = steps, path = root ^ "/_work/bin/corpus.rbc"})]
      val results = ref ([] : string list)
      fun save status = Files.record (work ^ "/result.record",
        ("status", status) :: base @
        (if status = "running" then [] else [("finished", Time.toString (Time.now ()))]) @
        Record.strings "tasks" (List.rev (!results)))
      val () = save "running"
      val () = print ("profile: " ^ work ^ "\n")
      fun task name =
        let
          val prefix = name ^ "."
          fun get key = Record.require metadata (prefix ^ key)
          val taskPath = work ^ "/tasks/" ^ name ^ ".record"
          val common = [("kind", "profile-task"), ("task", name)]
          val phase = ref "selection"
          fun state status more = Files.record (taskPath, ("status", status) :: common @ more)
          val () = state "running" []
          fun compiler () =
            let val alias = get "compiler"
                val input = Record.require selected (alias ^ ".compiler")
                val () = if input = "installed-rune" then raise Fail
                  "reference profile task requires a corpus stage-2 compiler" else ()
            in OS.Path.mkAbsolute {path = input, relativeTo =
                 OS.Path.dir (valOf bindingPath)} end
          fun perform () =
            let
              val kind = get "kind"
              val args = case kind of
                "harness" => NONE
              | "recipe" => SOME (["test", root ^ "/" ^ get "recipe", get "variant"] @
                  (case Record.find metadata (prefix ^ "compiler") of NONE => [] | SOME _ => [compiler ()]))
              | "cross-check" => SOME ["cross-check", compiler ()]
              | "benchmark" => SOME ["bench", root ^ "/" ^ get "experiment",
                    case bindingPath of NONE => raise Fail "benchmark profile requires compiler bindings"
                      | SOME path => path]
              | _ => raise Fail ("unsupported profile task kind: " ^ kind)
              val timeoutText = get "timeout"
              val timeout = case Int.fromString timeoutText of SOME n =>
                if n > 0 andalso Int.toString n = timeoutText then n else raise Fail "invalid profile timeout"
                | NONE => raise Fail "invalid profile timeout"
              val executable = case args of NONE => root ^ "/bin/test" | SOME _ => Process.resolve "runevm"
              val argv = case args of NONE => [] | SOME xs => root ^ "/_work/bin/corpus.rbc" :: xs
              val () = phase := "execution"
              val p = Process.runIdentified {parent = steps, label = "profile:" ^ name,
                identity = [("profile", work ^ "/profile.record"),
                  ("selected.sha256", Digest.file {steps = steps, path = executable})],
                command = {program = executable, args = argv, cwd = root,
                  env = Process.environment (), timeoutSeconds = timeout}}
              val passed = Process.success p
              val status = if passed then "passed" else
                if #status p = Process.TimedOut then "timeout" else "failed"
              val () = state status [("process.status", Process.statusText (#status p)), ("logs", #directory p)]
            in status end
          val status = perform () handle e =>
            let val status = if !phase = "selection" then "unsupported" else "infrastructure-failure"
            in state status [("error", Lifecycle.describe e)]; status end
          val () = results := (name ^ "\t" ^ status) :: !results
          val () = save "running"
          val () = print (name ^ ": " ^ status ^ " (" ^ taskPath ^ ")\n")
        in status = "passed" end
      fun execute () =
        let val _ = Provenance.inventory {steps = steps, destination = work ^ "/system.record"}
            val outcomes = List.map task names
            val passed = List.all (fn yes => yes) outcomes
            val () = save (if passed then "passed" else "failed")
        in if passed then print ("profile passed: " ^ work ^ "/result.record\n")
           else raise Fail ("profile has unsuccessful tasks: " ^ work ^ "/result.record") end
    in execute () handle e =>
      (if Record.find (Files.load (work ^ "/result.record")) "status" = SOME "running" then
         Files.record (work ^ "/result.record", [("status", "failed"), ("error", Lifecycle.describe e),
           ("finished", Time.toString (Time.now ()))] @
           base @ Record.strings "tasks" (List.rev (!results))) else ();
       raise e) end
end
