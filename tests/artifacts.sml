structure ArtifactTests =
struct
  val work = Files.freshDir (Files.absolute "_work/artifact-tests")
  val root = work ^ "/installation"
  val () = Files.mkdir root
  val () = Files.write (root ^ "/payload", "original")
  val manifest = Artifact.snapshot {steps = work ^ "/steps", roots = [root], base = root}
  val () = Artifact.verify {steps = work ^ "/steps", record = manifest}
  val () = CoreTests.assert ("artifact manifest verifies", true)
  val () = Files.write (root ^ "/payload", "changed")
  val () = CoreTests.assert ("modified artifact rejected",
    ((Artifact.verify {steps = work ^ "/steps", record = manifest}; false) handle Fail _ => true))
  val stage1 = work ^ "/stage1.record"
  val () = Files.record (stage1, [("kind", "compiler-bootstrap"), ("bootstrap.stage", "1")])
  val () = CoreTests.assert ("stage 1 forbidden for workloads",
    ((Artifact.compiler {steps = work ^ "/steps", path = stage1, allowBootstrap = false}; false)
     handle Fail _ => true))
  val incomplete = work ^ "/incomplete"
  val () = Files.mkdir incomplete
  val () = Files.record (incomplete ^ "/attempt.record", [("status", "running"), ("phase", "test")])
  val () = Files.record (stage1,
    [("kind", "compiler"), ("bootstrap.stage", "2"), ("attempt", incomplete)])
  val () = CoreTests.assert ("unvalidated compiler rejected",
    ((Artifact.compiler {steps = work ^ "/steps", path = stage1, allowBootstrap = false}; false)
     handle Fail _ => true))
  val recipePath = work ^ "/selection.record"
  val () = Files.record (recipePath,
    [("kind", "package"), ("name", "selection"), ("version", "1"),
     ("source.sha256", String.implode (List.tabulate (64, fn _ => #"0")))] @
    Record.strings "variants" ["native"] @
    Record.strings "compiler.families" ["smlnj"] @
    Record.strings "compiler.versions" ["2026.2", "110.99.9"])
  val recipe = Recipe.load recipePath
  val () = Recipe.checkCompiler recipe [("family", "smlnj"), ("version", "110.99.9")]
  val () = CoreTests.assert ("declared alternate compiler version accepted", true)
  val () = CoreTests.assert ("wrong compiler family rejected",
    ((Recipe.checkCompiler recipe [("family", "mlton"), ("version", "2026.2")]; false)
     handle Fail _ => true))
  val () = CoreTests.assert ("undeclared compiler version rejected",
    ((Recipe.checkCompiler recipe [("family", "smlnj"), ("version", "0")]; false)
     handle Fail _ => true))
end
