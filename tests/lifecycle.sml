structure LifecycleTests =
struct
  val root = OS.FileSys.getDir ()
  val work = Files.freshDir (root ^ "/_work/fixtures")
  val archive = work ^ "/hello.tar"
  val steps = work ^ "/steps"
  val _ = Lifecycle.tool steps root "fixture archive" "tar"
    ["-cf", archive, "-C", "tests/fixtures", "hello"]
  val hash = Digest.file {steps = steps, path = archive}
  val () = CoreTests.assert ("sha256 known vector",
    Digest.text {steps = steps, value = "abc"} =
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
  val common = [("kind", "package"), ("name", "fixture-hello"), ("version", "1"),
      ("source.url", "file://" ^ archive), ("source.sha256", hash),
      ("artifact", "{build}/hello.rbc"), ("build.count", "1"),
      ("build.0.program", "{rune}"), ("build.0.cwd", "{source}"), ("build.0.timeout", "120"),
      ("test.count", "1"), ("test.0.program", "{runevm}"), ("test.0.cwd", "{build}"),
      ("test.0.timeout", "10"), ("test.0.stdout", "hello corpus\n")] @
      Record.strings "variants" ["default", "second"] @
      Record.strings "tools" ["rune", "runevm", "curl", "tar", "patch", "sha256sum", "timeout"] @
      Record.strings "patches" ["{root}/tests/fixtures/hello.patch"] @
      Record.strings "build.0.args" ["main.sml", "-o", "{build}/hello.rbc"] @
      Record.strings "test.0.args" ["{build}/hello.rbc"]
  val recipe = work ^ "/hello.record"
  val () = Files.record (recipe, common)
  fun run variant = Lifecycle.run {root = root, recipePath = recipe, variant = variant, phase = "test"}
  val first = run "default"
  val second = run "second"
  val () = CoreTests.assert ("variant outputs isolated", first <> second andalso
    Files.exists (first ^ "/artifact.record") andalso Files.exists (second ^ "/artifact.record"))
  val repeated = run "default"
  val () = CoreTests.assert ("repeat patches fresh source", Record.require (Files.load (repeated ^ "/attempt.record")) "status" = "passed")
  val () = CoreTests.assert ("repeat inputs have same specification",
    Record.require (Files.load (first ^ "/specification.record")) "id" =
    Record.require (Files.load (repeated ^ "/specification.record")) "id")
  val () = CoreTests.assert ("variants have distinct specifications",
    Record.require (Files.load (first ^ "/specification.record")) "id" <>
    Record.require (Files.load (second ^ "/specification.record")) "id")
  val () = CoreTests.assert ("unknown variant rejected",
    ((run "missing"; false) handle Fail _ => true))
  val bad = work ^ "/bad.record"
  val () = Files.record (bad, ("source.sha256", String.implode (List.tabulate (64, fn _ => #"0"))) ::
      List.filter (fn (k, _) => k <> "source.sha256") common)
  val () = CoreTests.assert ("corrupt acquisition rejected",
    ((Lifecycle.run {root = root, recipePath = bad, variant = "default", phase = "fetch"}; false)
      handle Lifecycle.StepFailed _ => true))
  val () = print "PASS fixture lifecycle\n"
  val missing = work ^ "/missing-tool.record"
  val () = Files.record (missing, Record.strings "tools" ["/corpus-fixture-missing-tool"] @
    List.filter (fn (k, _) => not (String.isPrefix "tools." k)) common)
  val () = CoreTests.assert ("recipe doctor rejects missing prerequisite",
    not (Doctor.recipe {root = root, path = missing, variant = "default"}))
  val () = CoreTests.assert ("missing prerequisites stop the lifecycle",
    ((Lifecycle.run {root = root, recipePath = missing, variant = "default", phase = "fetch"}; false)
      handle Lifecycle.StepFailed _ => true))
  val isolated = work ^ "/isolated.record"
  val tools = Record.getStrings common "tools" @ ["dirname", "sh"]
  val isolatedRecipe = [("environment.isolated", "true"), ("test.count", "2"),
    ("test.1.program", "sh"), ("test.1.cwd", "{build}"), ("test.1.timeout", "5"),
    ("test.1.stdout", "seeds-unavailable\n")] @ Record.strings "tools" tools @
    Record.strings "test.1.args" ["-c",
      "for seed in sml mlton poly; do if command -v \"$seed\" >/dev/null; then exit 1; fi; done; printf 'seeds-unavailable\\n'"] @
    List.filter (fn (k, _) => k <> "test.count" andalso not (String.isPrefix "tools." k)) common
  val () = Files.record (isolated, isolatedRecipe)
  val isolatedAttempt = Lifecycle.run {root = root, recipePath = isolated, variant = "default", phase = "test"}
  val () = CoreTests.assert ("fixture succeeds with system SML seeds absent from PATH",
    Record.require (Files.load (isolatedAttempt ^ "/attempt.record")) "status" = "passed")
  val failing = work ^ "/failing.record"
  val failureRecipe = [("build.count", "2"), ("build.0.program", "/bin/sh"),
    ("build.0.cwd", "{build}"), ("build.0.timeout", "5"),
    ("build.1.program", "touch"), ("build.1.cwd", "{build}"), ("build.1.timeout", "5")] @
    Record.strings "build.0.args" ["-c", "printf build-partial; printf known-build-error >&2; exit 7"] @
    Record.strings "build.1.args" ["{build}/should-not-exist"] @
    List.filter (fn (k, _) => not (String.isPrefix "build." k)) common
  val () = Files.record (failing, failureRecipe)
  val () = CoreTests.assert ("lifecycle build failure reported",
    ((Lifecycle.run {root = root, recipePath = failing, variant = "default", phase = "test"}; false)
      handle Lifecycle.StepFailed _ => true))
  val failed = case List.find (fn n =>
      let val p = root ^ "/_work/attempts/" ^ n ^ "/attempt.record"
      in Files.exists p andalso Record.find (Files.load p) "recipe" = SOME failing end)
      (Files.entries (root ^ "/_work/attempts")) of
    SOME n => root ^ "/_work/attempts/" ^ n | NONE => raise Fail "failure attempt missing"
  val () = CoreTests.assert ("dependent commands blocked",
    Record.getStrings (Files.load (failed ^ "/build-plan.record")) "status" = ["failed", "blocked"] andalso
    not (Files.exists (failed ^ "/build/should-not-exist")))
  val () = CoreTests.assert ("build failure classified",
    Record.require (Files.load (failed ^ "/attempt.record")) "failure.class" = "build-failure")
  val exported = work ^ "/failure.tar.gz"
  val () = Report.export failed exported
  val listing = Lifecycle.tool steps root "inspect evidence export" "tar" ["-tzf", exported]
  val () = CoreTests.assert ("export contains logs and rerun instructions",
    String.isSubstring "RERUN.md" (Process.output listing) andalso
    String.isSubstring "/stderr.log" (Process.output listing) andalso
    not (String.isSubstring "source/main.sml" (Process.output listing)))
  val () = CoreTests.assert ("export preserves existing destination",
    ((Report.export failed exported; false) handle Fail _ => true))
  val () = Report.attempts root
  val () = CoreTests.assert ("report accepts export directories", true)
end
