structure CoreTests =
struct
  fun assert (name, passed) = if passed then print ("PASS " ^ name ^ "\n") else raise Fail name
  fun rejects text = ((Record.decode text; false) handle Record.Invalid _ => true)
  val fields = [("z", "line\nwith\ttab\\slash\r"), ("a", "literal $(no-shell) ' string")]
  val () = assert ("record roundtrip", Record.encode (Record.decode (Record.encode fields)) = Record.encode fields)
  val () = assert ("record duplicate rejected", rejects "corpus-record-v1\na\tx\na\ty\n")
  val () = assert ("record truncated rejected", rejects "corpus-record-v1\na\tx")
  val () = assert ("record unknown escape rejected", rejects "corpus-record-v1\na\t\\q\n")
  val root = Files.freshDir (Files.absolute "_work/tests")
  fun run (label, program, args, seconds) = Process.run
    {parent = root, label = label, command = {program = program, args = args,
      cwd = root, env = Process.environment (), timeoutSeconds = seconds}}
  val p = run ("argv", "printf", ["%s\n", "literal $(not-executed) ' with space"], 5)
  val () = assert ("literal argument preserved", Process.success p andalso
    Process.output p = "literal $(not-executed) ' with space\n")
  val p = run ("failure", "sh", ["-c", "printf partial; printf diagnostic >&2; exit 7"], 5)
  val () = assert ("failure exit retained", Process.statusText (#status p) = "exit:7")
  val () = assert ("partial stdout retained", Process.output p = "partial")
  val () = assert ("stderr retained", Files.read (#directory p ^ "/stderr.log") = "diagnostic")
  val p = run ("exit 124", "sh", ["-c", "exit 124"], 5)
  val () = assert ("exit 124 is not a timeout", Process.statusText (#status p) = "exit:124")
  val p = run ("timeout", "sleep", ["5"], 1)
  val () = assert ("timeout classified", Process.statusText (#status p) = "timeout")
  val p = run ("large logs", "sh", ["-c", "i=0; while test $i -lt 4096; do printf '0123456789abcdef\n'; i=$((i+1)); done; exit 9"], 10)
  val () = assert ("large failing log retained", size (Process.output p) = 4096 * 17 andalso
    Process.statusText (#status p) = "exit:9")
  val first = #directory p
  val p = run ("retry", "printf", ["retry"], 5)
  val () = assert ("retry retains earlier attempt", #directory p <> first andalso Files.exists (first ^ "/step.record"))
  val () = assert ("missing executable rejected",
    ((run ("missing-tool", "/corpus-no-such-executable", [], 1); false) handle Fail _ => true))
  val missing = List.find (fn n =>
    Record.find (Files.load (root ^ "/" ^ n ^ "/step.record")) "label" = SOME "missing-tool")
    (Files.entries root)
  val () = assert ("missing executable evidence retained",
    case missing of NONE => false | SOME n =>
      Record.find (Files.load (root ^ "/" ^ n ^ "/step.record")) "status" = SOME "infrastructure-failure")
  val interrupted = Files.freshDir (root ^ "/interrupted")
  val () = TextIO.flushOut TextIO.stdOut
  val interruptedPid = case Posix.Process.fork () of
    NONE => (ignore (Process.run {parent = interrupted, label = "interrupted", command =
      {program = "/bin/sh", args = ["-c", "printf before-interruption; sleep 20; printf should-not-appear"],
       cwd = root, env = Process.environment (), timeoutSeconds = 1}});
      Posix.Process.exit (Word8.fromInt 0))
  | SOME pid => pid
  fun waitForLog remaining =
    if remaining = 0 then raise Fail "interruption fixture did not start"
    else case Files.entries interrupted of
      [] => (OS.Process.sleep (Time.fromMilliseconds (IntInf.fromInt 20)); waitForLog (remaining - 1))
    | name :: _ =>
        let val path = interrupted ^ "/" ^ name
        in if Files.exists (path ^ "/stdout.log") andalso
              Files.read (path ^ "/stdout.log") = "before-interruption" andalso
              Record.find (Files.load (path ^ "/step.record")) "status" = SOME "running"
           then path else (OS.Process.sleep (Time.fromMilliseconds (IntInf.fromInt 20)); waitForLog (remaining - 1)) end
  val interruptedStep = waitForLog 100
  val () = Posix.Process.kill (Posix.Process.K_PROC interruptedPid, Posix.Signal.kill)
  val _ = Posix.Process.waitpid (Posix.Process.W_CHILD interruptedPid, [])
  val () = assert ("interruption retains unfinished step",
    Record.find (Files.load (interruptedStep ^ "/step.record")) "status" = SOME "running")
  val () = assert ("interruption retains partial output",
    Files.read (interruptedStep ^ "/stdout.log") = "before-interruption")
  (* Sleep may return early, and a busy host can delay the timeout helper.
     Wait for its observable action with a bounded real-time deadline. *)
  val orphanTimer = Timer.startRealTimer ()
  fun fallbackFired () = String.isSubstring "sending signal"
    (Files.read (interruptedStep ^ "/stderr.log"))
  fun awaitFallback () =
    if fallbackFired () orelse
       Time.>= (Timer.checkRealTimer orphanTimer, Time.fromSeconds (IntInf.fromInt 15))
    then ()
    else (OS.Process.sleep (Time.fromMilliseconds (IntInf.fromInt 20)); awaitFallback ())
  val () = awaitFallback ()
  val () = assert ("fallback timeout stops orphaned work",
    Files.read (interruptedStep ^ "/stdout.log") = "before-interruption" andalso
    fallbackFired ())
  val () = print ("test evidence: " ^ root ^ "\n")
end
