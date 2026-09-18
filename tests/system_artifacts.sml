structure SystemArtifactTests =
struct
  val work = Files.freshDir (Files.absolute "_work/system-artifact-tests")
  val p = Process.runIdentified {parent = work, label = "traced native command",
    identity = [("trace.files", "true")], command = {program = "/bin/sh",
      args = ["-c", "cat /etc/os-release >/dev/null; printf traced"], cwd = work,
      env = Process.environment (), timeoutSeconds = 10}}
  val () = CoreTests.assert ("traced command preserves result", Process.success p andalso Process.output p = "traced")
  val r = SystemArtifacts.capture {steps = work ^ "/summary-steps", trace = #directory p ^ "/files.trace.log",
    destination = work ^ "/observed.record"}
  val () = CoreTests.assert ("system file identity captured",
    List.exists (String.isPrefix "/etc/os-release\t") (Record.getStrings r "files"))
end
