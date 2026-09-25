(* Planning is separate from execution. Every run names exact compiler artifacts;
   aliases are local bindings, never an implicit latest-version lookup. *)
signature CORPUS_EXPERIMENT =
sig
  type plan = {directory : string, settings : Record.t,
               nodes : Graph.node list, configurations : Record.t list}
  val plan : {root : string, specification : string, bindings : string} -> plan
  val display : plan -> unit
end

structure Experiment :> CORPUS_EXPERIMENT =
struct
  type plan = {directory : string, settings : Record.t,
               nodes : Graph.node list, configurations : Record.t list}
  fun integer r key minimum maximum =
    let val value = Record.require r key
    in case Int.fromString value of SOME n =>
         if n >= minimum andalso n <= maximum andalso Int.toString n = value then n
         else raise Fail ("invalid experiment " ^ key)
       | NONE => raise Fail ("invalid experiment " ^ key) end
  fun safe s = size s > 0 andalso size s <= 48 andalso List.all
    (fn c => Char.isAlphaNum c orelse c = #"-" orelse c = #"_") (String.explode s)
  fun unique xs = List.foldl (fn (x, acc) =>
    if List.exists (fn y => x = y) acc then acc else acc @ [x]) [] xs
  fun plan {root, specification, bindings} =
    let
      val root = Files.absolute root
      val specification = Files.absolute specification
      val bindings = Files.absolute bindings
      val spec = Files.load specification
      val selected = Files.load bindings
      val () = if Record.require spec "kind" = "stackvm-experiment" andalso
        Record.require selected "kind" = "compiler-bindings" then ()
        else raise Fail "expected stackvm-experiment and compiler-bindings records"
      val () = if Record.require spec "format" = "corpus-stack-1" then ()
               else raise Fail "unsupported program/runtime instruction format"
      val generators = unique (Record.getStrings spec "generators")
      val runtimes = unique (Record.getStrings spec "runtimes")
      val sizes = unique (Record.getStrings spec "sizes")
      val () = if null generators orelse null runtimes orelse null sizes then
        raise Fail "experiment dimensions must not be empty" else ()
      val aliases = unique (generators @ runtimes)
      val () = if List.all safe aliases then () else raise Fail "invalid compiler binding name"
      val () = List.app (fn s => ignore (integer [("size", s)] "size" 1 20000)) sizes
      val _ = integer spec "iterations" 1 1000000
      val _ = integer spec "warmups" 0 100
      val _ = integer spec "samples" 1 1000
      val _ = integer spec "timeout.seconds" 1 86400
      val _ = integer spec "memory.mib" 64 1048576
      val work = Files.freshDir (root ^ "/_work/experiments")
      val steps = work ^ "/steps"
      val () = Files.mkdir steps
      val () = Files.record (work ^ "/experiment.record", spec)
      val () = Files.record (work ^ "/bindings.record", selected)
      val inventory = Provenance.inventory {steps = steps, destination = work ^ "/system.record"}
      val stableInventory = List.filter (fn (key, _) => key <> "captured") inventory
      val systemHash = Digest.text {steps = steps, value = Record.encode stableInventory}
      val envHash = Digest.text {steps = steps,
        value = Record.encode (Record.strings "environment" (Process.environment ()))}
      val harnessPaths = "sources.txt" :: "src/main.sml" ::
        String.tokens (fn c => c = #"\n") (Files.read (root ^ "/sources.txt"))
      val harnessHashes = Digest.files {steps = steps,
        paths = List.map (fn path => root ^ "/" ^ path) harnessPaths}
      val harnessHash = Digest.text {steps = steps,
        value = Record.encode (Record.strings "harness" (List.map #2 harnessHashes))}
      val nodes = ref ([] : Graph.node list)
      fun node id dependencies fields =
        if List.exists (fn ({id = other, ...} : Graph.node) => other = id) (!nodes) then id
        else (nodes := !nodes @ [{id = id, dependencies = dependencies, fields = fields}]; id)
      fun source role =
        let val input = OS.Path.mkAbsolute {path = Record.require spec (role ^ ".source"),
                                          relativeTo = OS.Path.dir specification}
            val path = work ^ "/" ^ role ^ ".sml"
            val () = Files.write (path, Files.read input)
            val hash = Digest.file {steps = steps, path = path}
            val id = node ("source-" ^ hash) []
              [("kind", "source"), ("source", path), ("original", input), ("sha256", hash)]
        in (role, id, path, hash) end
      val sources = List.map source ["generator", "runtime"]
      fun compiler alias =
        (let val input = Record.require selected (alias ^ ".compiler")
            val () = if input = "installed-rune" then raise Fail
              "benchmark bindings require a corpus Rune artifact, not installed-rune" else ()
            val path = OS.Path.mkAbsolute {path = input, relativeTo = OS.Path.dir bindings}
            fun resolve () =
              let val record = Artifact.compiler {steps = steps, path = path, allowBootstrap = false}
                  val family = Record.require record "family"
                  val arguments = if Option.isSome (Record.find selected (alias ^ ".arguments.count"))
                    then Record.getStrings selected (alias ^ ".arguments") else []
                  val () = if List.exists (fn x => x = family) ["rune", "smlnj", "polyml", "mlton"]
                    then () else raise Fail ("unsupported builder family: " ^ family)
                  val () = if null arguments orelse family = "rune" orelse family = "mlton" then ()
                    else raise Fail ("extra program compiler arguments are unsupported for " ^ family)
                  val () = case Record.find record "target" of NONE => () | SOME target =>
                    if target = "x86_64-linux" then () else raise Fail ("unsupported builder target: " ^ target)
                  val hash = Digest.text {steps = steps, value = Record.encode record}
                  val snapshot = work ^ "/compiler-" ^ alias ^ ".record"
                  val () = Files.record (snapshot, record)
                  val id = node ("compiler-" ^ hash) []
                    [("kind", "compiler"), ("artifact", path), ("snapshot", snapshot),
                     ("family", family), ("identity.sha256", hash)]
              in (alias, SOME (id, path, hash, arguments), "") end
        in resolve () end handle e => (alias, NONE, Lifecycle.describe e))
      val compilers = List.map compiler aliases
      fun builder role alias =
        let val (_, input, reason) = valOf (List.find (fn (name, _, _) => name = alias) compilers)
        in case input of NONE => (NONE, alias ^ ": " ^ reason)
           | SOME (compilerNode, compilerPath, compilerHash, arguments) =>
             let val (_, sourceNode, sourcePath, sourceHash) =
                   valOf (List.find (fn (name, _, _, _) => name = role) sources)
                 val inputs = [("kind", "program-build-inputs"), ("source.sha256", sourceHash),
                   ("compiler.sha256", compilerHash), ("system.sha256", systemHash),
                   ("environment.sha256", envHash), ("harness.sha256", harnessHash),
                   ("adapter", "Program.buildWithArguments")] @ Record.strings "compiler.arguments" arguments
                 val hash = Digest.text {steps = steps, value = Record.encode inputs}
                 val id = node ("build-" ^ hash) [sourceNode, compilerNode]
                   ([("kind", "program-build"), ("role", role), ("source", sourcePath),
                     ("compiler", compilerPath), ("identity.sha256", hash)] @
                     List.filter (fn (key, _) => key <> "kind") inputs)
             in (SOME id, "") end end
      val generatorBuilds = List.map (fn alias => (alias, builder "generator" alias)) generators
      val runtimeBuilds = List.map (fn alias => (alias, builder "runtime" alias)) runtimes
      fun configuration (generator, (generatorId, generatorError)) (runtime, (runtimeId, runtimeError)) size =
        let val id = Int.toString (String.size generator) ^ "-" ^ generator ^ "-" ^
                     Int.toString (String.size runtime) ^ "-" ^ runtime ^ "-" ^ size
            val base = [("id", id), ("generator", generator), ("runtime", runtime),
              ("size", size), ("iterations", Record.require spec "iterations")]
        in case (generatorId, runtimeId) of
          (SOME g, SOME r) =>
            let val code = node ("bytecode-" ^ g ^ "-" ^ size) [g]
                  [("kind", "bytecode"), ("size", size), ("generator", g), ("format", "corpus-stack-1")]
                val workload = node ("workload-" ^ size) []
                  [("kind", "workload"), ("size", size), ("iterations", Record.require spec "iterations"),
                   ("oracle", "sum of squares from 1 through N, multiplied by iterations")]
                val run = node ("run-" ^ id) [r, code, workload]
                  [("kind", "run"), ("configuration", id), ("runtime", r), ("bytecode", code)]
                val _ = node ("result-" ^ id) [run] [("kind", "result"), ("configuration", id)]
            in [("status", "planned"), ("runtime.build", r), ("generator.build", g),
                ("bytecode", code), ("run", run)] @ base end
        | _ => [("status", "unsupported"),
                ("reason", String.concatWith "; " (List.filter (fn s => s <> "")
                  [generatorError, runtimeError]))] @ base end
      val configurations = List.concat (List.map (fn generator =>
        List.concat (List.map (fn runtime => List.map (configuration generator runtime) sizes) runtimeBuilds)) generatorBuilds)
      val ordered = Graph.order (!nodes)
      fun nodeFields (i, {id, dependencies, fields} : Graph.node) =
        let val prefix = "node." ^ Int.toString i
        in (prefix ^ ".id", id) :: Record.strings (prefix ^ ".dependencies") dependencies @
           List.map (fn (k, v) => (prefix ^ "." ^ k, v)) fields end
      val graph = [("kind", "experiment-plan"), ("format", "corpus-stack-1"),
        ("system.sha256", systemHash), ("environment.sha256", envHash),
        ("cache.policy", "share identical dependencies within this plan; fresh builds across attempts; no cached compile timings"),
        ("node.count", Int.toString (length ordered))] @
        List.concat (List.tabulate (length ordered, fn i => nodeFields (i, List.nth (ordered, i))))
      val () = Files.record (work ^ "/plan.record", graph)
      val () = Files.mkdir (work ^ "/configurations")
      val () = List.app (fn r => Files.record
        (work ^ "/configurations/" ^ Record.require r "id" ^ ".record", r)) configurations
    in {directory = work, settings = spec, nodes = ordered, configurations = configurations} end
  fun display ({directory, nodes, configurations, ...} : plan) =
    (print ("experiment plan: " ^ directory ^ "/plan.record\n");
     List.app (fn r => print (Record.require r "id" ^ ": " ^ Record.require r "status" ^
       (case Record.find r "reason" of NONE => "" | SOME s => " (" ^ s ^ ")") ^ "\n")) configurations;
     List.app (fn ({id, dependencies, fields} : Graph.node) =>
       print (Record.require fields "kind" ^ " " ^ id ^ " <- " ^ String.concatWith ", " dependencies ^ "\n")) nodes)
end
