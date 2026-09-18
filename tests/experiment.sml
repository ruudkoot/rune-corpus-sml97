structure ExperimentTests =
struct
  val root = OS.FileSys.getDir ()
  val work = Files.freshDir (root ^ "/_work/experiment-tests")
  val generator = work ^ "/generator.sml"
  val runtime = work ^ "/runtime.sml"
  val () = Files.write (generator, Files.read (root ^ "/experiments/stackvm/codegen.sml"))
  val () = Files.write (runtime, Files.read (root ^ "/experiments/stackvm/runtime.sml"))
  val specification = work ^ "/experiment.record"
  val bindings = work ^ "/bindings.record"
  val settings = [("kind", "stackvm-experiment"), ("format", "corpus-stack-1"),
    ("generator.source", generator), ("runtime.source", runtime), ("iterations", "1"),
    ("warmups", "0"), ("samples", "1"), ("timeout.seconds", "5"), ("memory.mib", "64")] @
    Record.strings "generators" ["rune", "same", "all", "missing"] @
    Record.strings "runtimes" ["rune"] @ Record.strings "sizes" ["1", "2"]
  val () = Files.record (specification, settings)
  val () = Files.record (bindings, [("kind", "compiler-bindings"),
    ("rune.compiler", "installed-rune"), ("same.compiler", "installed-rune"),
    ("all.compiler", "installed-rune")] @ Record.strings "all.arguments" ["--basis", "all"])
  val first = Experiment.plan {root = root, specification = specification, bindings = bindings}
  val configurations = #configurations first
  fun configuration (plan : Experiment.plan) name = valOf (List.find (fn r =>
    Record.require r "generator" = name andalso Record.require r "size" = "1") (#configurations plan))
  val () = CoreTests.assert ("experiment retains incompatible selections",
    length configurations = 8 andalso length (List.filter
      (fn r => Record.require r "status" = "unsupported") configurations) = 2)
  val () = CoreTests.assert ("experiment shares identical builder inputs",
    Record.require (configuration first "rune") "generator.build" =
    Record.require (configuration first "same") "generator.build")
  val () = CoreTests.assert ("compiler flags distinguish build identities",
    Record.require (configuration first "rune") "generator.build" <>
    Record.require (configuration first "all") "generator.build")
  val builds = List.filter (fn ({fields, ...} : Graph.node) =>
    Record.find fields "kind" = SOME "program-build") (#nodes first)
  val () = CoreTests.assert ("matrix reuses shared builds across workload sizes", length builds = 3)
  val () = Files.write (generator, Files.read generator ^ "\n(* changed source identity *)\n")
  val second = Experiment.plan {root = root, specification = specification, bindings = bindings}
  val () = CoreTests.assert ("changed source invalidates planned builds",
    Record.require (configuration first "rune") "generator.build" <>
    Record.require (configuration second "rune") "generator.build")
  val () = Files.record (specification, ("format", "incompatible-bytecode") ::
    List.filter (fn (key, _) => key <> "format") settings)
  val () = CoreTests.assert ("experiment rejects incompatible runtime format",
    ((Experiment.plan {root = root, specification = specification, bindings = bindings}; false)
     handle Fail _ => true))
end
