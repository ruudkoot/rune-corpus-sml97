(* Synthetic artifacts for harness adapter tests. These wrap the harness's
   installed Rune, not a built upstream commit, and live outside the corpus
   compiler registry. Real workload selection is exercised by the profiles. *)
structure TestCompiler =
struct
  val work = Files.freshDir (Files.absolute "_work/test-compilers")
  val seed = Artifact.externalRuneSeed {steps = work ^ "/steps"}
  val () = Files.record (work ^ "/attempt.record", [("kind", "harness-fixture"),
    ("status", "passed"), ("phase", "test")])
  fun artifact digit =
    let val version = String.implode (List.tabulate (40, fn _ => digit))
        val path = work ^ "/" ^ version ^ ".record"
        val metadata = [("kind", "compiler"), ("bootstrap.stage", "2"),
          ("version", version), ("source.commit", version), ("target", "x86_64-linux"),
          ("attempt", work), ("fixture", "synthetic harness compiler; not an upstream Rune build")]
        val () = Files.record (path, metadata @ List.filter (fn (key, _) =>
          not (List.exists (fn (k, _) => k = key) metadata)) seed)
    in path end
  val first = artifact #"0"
  val second = artifact #"1"
end
