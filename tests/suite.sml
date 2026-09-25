structure SuiteTests =
struct
  val work = Files.freshDir (Files.absolute "_work/suite-tests")
  val () = Files.write (work ^ "/input.sml", "val answer = 42;\n")
  val () = Files.write (work ^ "/bad.sml", "val () = raise Fail \"deliberate oracle failure\";\n")
  val () = Files.write (work ^ "/good.sml",
    "val () = if Subject.answer = 42 then () else raise Fail \"answer\";\n")
  val metadata = work ^ "/suite.record"
  val () = Files.record (metadata,
    [("kind", "semantic-suite"), ("bad.source", "input.sml"), ("bad.validator", "bad.sml"),
     ("good.source", "input.sml"), ("good.validator", "good.sml")] @
    Record.strings "cases" ["bad", "good"])
  val failed = ((Suite.run {metadata = metadata, source = work, build = work,
                            compilerArtifact = TestCompiler.first}; false) handle Fail _ => true)
  val () = CoreTests.assert ("semantic suite rejects failed oracle", failed)
  val directory = work ^ "/suites/" ^ hd (Files.entries (work ^ "/suites"))
  val () = CoreTests.assert ("semantic suite preserves failed case",
    Record.require (Files.load (directory ^ "/bad/result.record")) "status" = "test-failure")
  val () = CoreTests.assert ("semantic suite continues independent case",
    Record.require (Files.load (directory ^ "/good/result.record")) "status" = "passed")
  val () = CoreTests.assert ("semantic suite keeps reproducer",
    Files.exists (directory ^ "/bad/program.sml"))
end
