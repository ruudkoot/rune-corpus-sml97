signature CORPUS_BENCHMARK =
sig
  val run : {root : string, specification : string, bindings : string, dryRun : bool} -> unit
end

structure Benchmark :> CORPUS_BENCHMARK =
struct
  fun number r key = valOf (Int.fromString (Record.require r key))
  fun value r key = Record.require r key
  fun real s = case Real.fromString s of SOME x =>
      if Real.isFinite x andalso x >= 0.0 then x else raise Fail "invalid timing value"
    | NONE => raise Fail "invalid timing value"
  fun summary xs =
    let fun insert (x : real, []) = [x]
          | insert (x, y :: rest) = if x < y then x :: y :: rest else y :: insert (x, rest)
        val ordered = List.foldl insert [] xs
        val n = length ordered
        val () = if n > 0 then () else raise Fail "no timing samples"
        val middle = n div 2
        val median = if n mod 2 = 1 then List.nth (ordered, middle)
                     else (List.nth (ordered, middle - 1) + List.nth (ordered, middle)) / 2.0
    in [("samples", Int.toString n), ("minimum.seconds", Real.toString (hd ordered)),
        ("median.seconds", Real.toString median),
        ("maximum.seconds", Real.toString (List.last ordered))] end
  fun oracle size iterations =
    let val n = valOf (IntInf.fromString size)
        val count = valOf (IntInf.fromString iterations)
    in "CORPUS_STACK_RESULT " ^ IntInf.toString (n * (n + 1) * (2 * n + 1) div 6 * count) ^ "\n" end
  fun activeBuilds root =
    let val parent = root ^ "/_work/attempts"
        fun one name =
          let val path = parent ^ "/" ^ name ^ "/attempt.record"
          in if not (Files.exists path) then NONE else
            let val r = Files.load path
            in if Record.find r "status" <> SOME "running" then NONE else
              case Record.find r "runner.pid" of NONE => NONE | SOME pid =>
                let (* /proc names are decimal; corpus PID fields use hexadecimal. *)
                    val proc = "/proc/" ^ IntInf.toString (SysWord.toLargeInt
                      (valOf (SysWord.fromString pid))) ^ "/cmdline"
                in if Files.exists proc andalso String.isSubstring "corpus.rbc" (Files.read proc)
                   then SOME path else NONE end
            end end handle _ => NONE
    in if Files.exists parent then List.mapPartial one (Files.entries parent) else [] end
  fun run {root, specification, bindings, dryRun} =
    let
      val root = Files.absolute root
      val plan = Experiment.plan {root = root, specification = specification, bindings = bindings}
      val () = Experiment.display plan
      val work = #directory plan
      val settings = #settings plan
      val steps = work ^ "/steps"
      val lock = root ^ "/_work/benchmark.lock"
      val base = [("kind", "benchmark-result"), ("plan", work ^ "/plan.record"),
        ("measurement", "whole runtime command including startup, bytecode parsing and workload; wall/user/system seconds and maximum RSS KiB"),
        ("compile.measurement", "fresh compiler commands including linking/export where combined; wall time from process records, one observation per distinct build"),
        ("order", "correctness gates, warmups, then serial rounds with rotated configuration order"),
        ("provenance.gaps", "timed commands are untraced; external host load, CPU frequency and caches are not controlled; consult recorded system inventories and compiler ancestry")]
      fun state status more = Files.record (work ^ "/result.record", ("status", status) :: base @ more)
      fun execute () =
        let
          val active = activeBuilds root
          val () = if null active then () else raise Fail
            ("timing deferred while corpus lifecycle work is active: " ^ String.concatWith ", " active)
          val timingTools = Provenance.selectedTools steps ["time", "prlimit"]
          val () = Files.record (work ^ "/timing-tools.record", timingTools)
          val timeTool = Process.resolve "time"
          val limitTool = Process.resolve "prlimit"
          val timeout = number settings "timeout.seconds"
          val memory = IntInf.fromInt (number settings "memory.mib") * 1048576
          val () = Files.mkdir (work ^ "/machine")
          val () = List.app (fn name =>
            if Files.exists ("/proc/" ^ name) then Files.write
              (work ^ "/machine/" ^ String.translate (fn c => if c = #"/" then "-" else str c) name ^ ".txt",
               Files.read ("/proc/" ^ name)) else ())
            ["cpuinfo", "meminfo", "loadavg", "self/status"]
          val results = ref ([] : (string * Record.t) list)
          fun remember id record =
            (Files.record (work ^ "/nodes/" ^ id ^ ".record", record);
             results := (id, record) :: !results)
          fun lookup id = case List.find (fn (name, _) => name = id) (!results) of
            SOME (_, r) => r | NONE => raise Fail ("missing node result: " ^ id)
          fun command label artifact args =
            let val r = Files.load artifact
                val () = Artifact.verify {steps = steps, record = r}
                val () = if Digest.file {steps = steps, path = value r "run.program"} =
                  value r "run.program.sha256" then () else raise Fail "program runtime executable changed"
                val original = Program.command {record = r, args = args, timeout = timeout}
                val metrics = Files.freshDir (work ^ "/metrics") ^ "/time.txt"
                val process = Process.runIdentified {parent = steps, label = label,
                  identity = [("metrics", metrics), ("memory.limit.bytes", IntInf.toString memory),
                              ("program.artifact", artifact), ("trace.files", "false")],
                  command = {program = timeTool,
                    args = ["-o", metrics, "-f", "%e %U %S %M", limitTool,
                      "--as=" ^ IntInf.toString memory, "--", #program original] @ #args original,
                    cwd = #cwd original, env = #env original, timeoutSeconds = timeout}}
                val metricsText = if Files.exists metrics then Files.read metrics else ""
            in (process, metricsText) end
          fun compilation artifact =
            let val r = Files.load artifact
                fun duration path =
                  let val step = Files.load (path ^ "/step.record")
                  in real (value step "finished") - real (value step "started") end
                val seconds = List.foldl (fn (path, acc) => duration path + acc) 0.0
                  (Record.getStrings r "compile.logs")
            in Real.toString seconds end
          fun prepare ({id, dependencies, fields} : Graph.node) =
            let
              val kind = value fields "kind"
              val skipped = kind = "run" orelse kind = "result"
              val blocked = not skipped andalso not (List.all (fn parent =>
                Record.find (lookup parent) "status" = SOME "passed") dependencies)
              val common = [("kind", "experiment-node-result"), ("node", id), ("node.kind", kind)]
              fun save status extra = remember id (("status", status) :: common @ extra)
              fun build () =
                if kind = "program-build" then
                  let val artifact = Program.buildWithArguments {root = root, source = value fields "source",
                    compilerArtifact = value fields "compiler", trace = false,
                    arguments = Record.getStrings fields "compiler.arguments"}
                  in save "passed" [("artifact", artifact),
                    ("compile.wall.seconds", compilation artifact), ("compile.samples", "1")] end
                else if kind = "bytecode" then
                  let val generator = value (lookup (value fields "generator")) "artifact"
                      val output = work ^ "/bytecode/" ^ id ^ ".code"
                      val size = value fields "size"
                      val (p, _) = command ("generate:" ^ id) generator [output, size]
                      val _ = Lifecycle.required p
                      val () = if Process.output p = "CORPUS_STACK_CODE " ^ size ^ "\n" then ()
                        else raise Fail ("generator output mismatch; logs: " ^ #directory p)
                      val hash = Digest.file {steps = steps, path = output}
                  in save "passed" [("path", output), ("sha256", hash), ("logs", #directory p)] end
                else save "passed" (List.filter (fn (key, _) => key <> "kind") fields)
            in if skipped then () else if blocked then save "blocked" [("reason", "dependency failed")]
               else (build () handle e => save "failed" [("error", Lifecycle.describe e)]) end
          val () = Files.mkdir (work ^ "/nodes")
          val () = Files.mkdir (work ^ "/bytecode")
          val () = List.app prepare (#nodes plan)
          val configurations = #configurations plan
          val samples = ref ([] : (string * Record.t list) list)
          val verdicts = ref ([] : (string * bool) list)
          fun sample id r =
            samples := (id, [r]) :: !samples
          fun records id = List.concat (List.map #2
            (List.filter (fn (name, _) => name = id) (List.rev (!samples))))
          fun valid id = getOpt (Option.map #2
            (List.find (fn (name, _) => name = id) (!verdicts)), false)
          fun verdict id yes = verdicts := (id, yes) :: !verdicts
          fun runCase config phase index =
            let val id = value config "id"
                val runtime = value (lookup (value config "runtime.build")) "artifact"
                val code = lookup (value config "bytecode")
                val () = if Digest.file {steps = steps, path = value code "path"} = value code "sha256"
                  then () else raise Fail "generated bytecode changed"
                val (process, metrics) = command (phase ^ ":" ^ id ^ ":" ^ Int.toString index)
                  runtime [value code "path", value config "iterations"]
                val passed = Process.success process andalso Process.output process =
                  oracle (value config "size") (value config "iterations")
                val numbers = String.tokens Char.isSpace metrics
                val parsed = case numbers of [wall, user, system, rss] =>
                    [("wall.seconds", Real.toString (real wall)),
                     ("user.seconds", Real.toString (real user)),
                     ("system.seconds", Real.toString (real system)),
                     ("maximum.rss.kib", Real.toString (real rss))]
                  | _ => []
                val okay = passed andalso not (null parsed)
                val record = [("kind", "benchmark-sample"), ("configuration", id),
                  ("phase", phase), ("index", Int.toString index),
                  ("status", if okay then "passed" else "invalid"),
                  ("process.status", Process.statusText (#status process)),
                  ("logs", #directory process), ("metrics.raw", metrics),
                  ("expected.stdout", oracle (value config "size") (value config "iterations"))] @ parsed
                val () = Files.record (work ^ "/samples/" ^ id ^ "-" ^ phase ^ "-" ^ Int.toString index ^ ".record", record)
                val () = sample id record
            in if okay then () else verdict id false end
            handle e =>
              let val id = value config "id"
                  val r = [("kind", "benchmark-sample"), ("configuration", id),
                    ("phase", phase), ("status", "failed"), ("error", Lifecycle.describe e)]
              in Files.record (work ^ "/samples/" ^ id ^ "-" ^ phase ^ "-" ^ Int.toString index ^ ".record", r);
                 sample id r; verdict id false end
          fun gate config =
            let val id = value config "id"
                val ready = value config "status" = "planned" andalso
                  List.all (fn key => value (lookup (value config key)) "status" = "passed")
                    ["runtime.build", "bytecode"]
                val () = verdict id ready
            in if ready then runCase config "correctness" 0 else () end
          val () = Files.mkdir (work ^ "/samples")
          val () = List.app gate configurations
          fun round phase i =
            let val count = length configurations
                val offset = i mod count
                val ordered = List.drop (configurations, offset) @ List.take (configurations, offset)
            in List.app (fn config => if valid (value config "id") then runCase config phase i else ()) ordered end
          val () = List.app (round "warmup") (List.tabulate (number settings "warmups", fn i => i))
          val () = List.app (round "sample") (List.tabulate (number settings "samples", fn i => i))
          fun report config =
            let val id = value config "id"
                val measured = List.filter (fn r => Record.find r "phase" = SOME "sample" andalso
                  Record.find r "status" = SOME "passed") (records id)
                val okay = valid id andalso length measured = number settings "samples"
                val statistics = if okay then summary (List.map (fn r => real (value r "wall.seconds")) measured) else []
                val status = if okay then "passed" else if value config "status" = "unsupported" then "unsupported"
                  else if null (records id) then "blocked" else "invalid"
                val r = [("kind", "benchmark-configuration"), ("status", status)] @
                  List.filter (fn (k, _) => k <> "status") config @ statistics
                val configurationPath = work ^ "/configurations/" ^ id ^ ".record"
                val () = Files.record (configurationPath, r)
                val () = case Record.find config "run" of NONE => () | SOME run =>
                  (remember run [("kind", "experiment-node-result"), ("node", run),
                    ("status", status), ("configuration", configurationPath)];
                   remember ("result-" ^ id) [("kind", "experiment-node-result"),
                    ("node", "result-" ^ id), ("status", status), ("configuration", configurationPath)])
            in "| " ^ id ^ " | " ^ status ^ " | " ^
              (if okay then value r "median.seconds" ^ " | " ^ value r "minimum.seconds" ^
                "-" ^ value r "maximum.seconds" ^ " | " ^ value r "samples" else "n/a | n/a | 0") ^ " |\n" end
          val rows = String.concat (List.map report configurations)
          val allPassed = List.all (fn config => valid (value config "id")) configurations
          val () = Files.write (work ^ "/REPORT.md", "# Stack-machine experiment\n\n" ^
            "Whole runtime commands include startup and bytecode parsing. Units are seconds. " ^
            "Individual samples retain user/system CPU time and maximum RSS in KiB. " ^
            "Invalid and blocked configurations are excluded from timing comparisons.\n\n" ^
            "| Configuration | Status | Median | Min-max | Samples |\n| --- | --- | --- | --- | --- |\n" ^ rows ^
            "\nSee plan.record for dependency identities, nodes/ for fresh compilation timings and artifact paths, " ^
            "configurations/ and samples/ for individual results, and system.record and machine/ for host evidence. " ^
            "Compiler artifacts retain their full bootstrap ancestry. Timing commands are untraced. " ^
            "External host load and CPU frequency are not controlled.\n\n" ^
            "Rerun with the matching checkout, installed Rune, native prerequisites and exact compiler artifacts: " ^
            "`bin/corpus bench " ^ Files.absolute specification ^ " " ^ Files.absolute bindings ^ "`. " ^
            "Restore the saved experiment.record and bindings.record to their original path context " ^
            "before rerunning; relative paths in those records retain that context. " ^
            "Retain this result directory and the referenced compiler/program installations.\n")
          val () = state (if allPassed then "passed" else "invalid")
            [("report", work ^ "/REPORT.md"), ("configurations", Int.toString (length configurations))]
          val () = print ("benchmark report: " ^ work ^ "/REPORT.md\n")
        in if allPassed then () else raise Fail ("benchmark has invalid configurations: " ^ work) end
      fun unlocked () = (OS.FileSys.remove (lock ^ "/owner.record"); OS.FileSys.rmDir lock)
    in if dryRun then state "planned" [] else
      (OS.FileSys.mkDir lock handle OS.SysErr _ => raise Fail
         ("another benchmark may be active; inspect " ^ lock ^ "/owner.record before removing a stale lock");
       Files.record (lock ^ "/owner.record", [("kind", "benchmark-lock"), ("experiment", work),
         ("pid", SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ())))]);
       state "running" [];
       ((execute () before unlocked ()) handle e =>
         (if Record.find (Files.load (work ^ "/result.record")) "status" = SOME "running"
          then state "failed" [("error", Lifecycle.describe e)] else ();
          unlocked (); raise e))) end
end
