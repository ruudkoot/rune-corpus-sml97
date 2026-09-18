structure Main =
struct
  val usage = "usage: corpus doctor [RECIPE VARIANT]\n\
    \       corpus fetch|patch|build|test RECIPE VARIANT [COMPILER_ARTIFACT]\n\
    \       corpus report [ATTEMPT_DIRECTORY] | compilers | failures\n\
    \       corpus compare LEFT_ATTEMPT RIGHT_ATTEMPT | show RECORD | logs PATH TEXT\n\
    \       corpus export ATTEMPT_DIRECTORY NEW_ARCHIVE | cross-check COMPILER_ARTIFACT\n\
    \       corpus program SOURCE.sml COMPILER_ARTIFACT_OR_installed-rune\n\
    \       corpus execute PROGRAM_ARTIFACT [ARG ...]\n\
    \       corpus bench [--dry-run] EXPERIMENT_RECORD BINDINGS_RECORD\n\
    \       corpus profile PROFILE_RECORD [BINDINGS_RECORD]\n\
    \       corpus run-suite METADATA SOURCE_DIRECTORY BUILD_DIRECTORY COMPILER_ARTIFACT_OR_installed-rune\n\
    \       corpus --help\n\
    \See README.md for concepts, command details and workflows. run-suite is an internal recipe adapter.\n"
  fun main args =
    case args of
      ["doctor"] =>
        let val dir = Files.freshDir (Files.absolute "_work/doctor")
            val r = Provenance.inventory {steps = dir ^ "/steps", destination = dir ^ "/system.record"}
            val failures = List.filter (fn (k, _) => String.isSuffix ".error" k) r
        in print ("system inventory: " ^ dir ^ "/system.record\n");
           List.app (fn (k, v) => print (k ^ ": " ^ v ^ "\n")) failures;
           if null failures then OS.Process.success else OS.Process.failure end
    | ["run-suite", metadata, source, build, compiler] =>
        (Suite.run {metadata = metadata, source = source, build = build,
                    compilerArtifact = compiler}; OS.Process.success)
    | ["program", source, compiler] =>
        (print ("program artifact: " ^ Program.build {root = OS.FileSys.getDir (),
          source = source, compilerArtifact = compiler, trace = true} ^ "\n"); OS.Process.success)
    | ["bench", "--dry-run", specification, bindings] =>
        (Benchmark.run {root = OS.FileSys.getDir (), specification = specification,
                        bindings = bindings, dryRun = true}; OS.Process.success)
    | ["bench", specification, bindings] =>
        (Benchmark.run {root = OS.FileSys.getDir (), specification = specification,
                        bindings = bindings, dryRun = false}; OS.Process.success)
    | ["profile", specification] =>
        (Profile.run {root = OS.FileSys.getDir (), specification = specification,
                      bindings = NONE}; OS.Process.success)
    | ["profile", specification, bindings] =>
        (Profile.run {root = OS.FileSys.getDir (), specification = specification,
                      bindings = SOME bindings}; OS.Process.success)
    | "execute" :: artifact :: args =>
        let val result = Program.execute {root = OS.FileSys.getDir (), artifact = artifact, args = args}
            val () = print (Process.output result)
            val () = print ("program logs: " ^ #directory result ^ "\n")
        in if Process.success result then OS.Process.success else OS.Process.failure end
    | [phase, recipe, variant] =>
        if phase = "compare" then (Report.compare recipe variant; OS.Process.success)
        else if phase = "doctor" then
          (if Doctor.recipe {root = OS.FileSys.getDir (), path = recipe, variant = variant}
           then OS.Process.success else OS.Process.failure)
        else if phase = "logs" then (Report.search recipe variant; OS.Process.success)
        else if phase = "export" then (Report.export recipe variant; OS.Process.success)
        else (print ("attempt: " ^ Lifecycle.run {root = OS.FileSys.getDir (), recipePath = recipe,
                   variant = variant, phase = phase} ^ "\n"); OS.Process.success)
    | ["report"] => (Report.attempts (OS.FileSys.getDir ()); OS.Process.success)
    | ["compilers"] => (Report.compilers (OS.FileSys.getDir ()); OS.Process.success)
    | ["failures"] => (Report.failureGroups (OS.FileSys.getDir ()); OS.Process.success)
    | ["report", path] => (Report.detail path; OS.Process.success)
    | ["show", path] => (Report.show path; OS.Process.success)
    | ["cross-check", path] => (HarnessTest.run path; OS.Process.success)
    | [phase, recipe, variant, compiler] =>
        (print ("attempt: " ^ Lifecycle.runWithCompiler {root = OS.FileSys.getDir (),
          recipePath = recipe, variant = variant, phase = phase, compilerPath = SOME compiler} ^ "\n");
         OS.Process.success)
    | ["--help"] => (print usage; OS.Process.success)
    | _ => (TextIO.output (TextIO.stdErr, usage); OS.Process.failure)
  val status = main (CommandLine.arguments ()) handle e =>
    (TextIO.output (TextIO.stdErr, "corpus: " ^ Lifecycle.describe e ^ "\n"); OS.Process.failure)
  val () = OS.Process.exit status
end
