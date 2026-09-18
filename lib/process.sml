signature CORPUS_PROCESS =
sig
  datatype status = Exited of int | Signaled of int | TimedOut
  type command = {program : string, args : string list, cwd : string,
                  env : string list, timeoutSeconds : int}
  type result = {status : status, directory : string}
  val resolve : string -> string
  val environment : unit -> string list
  val run : {parent : string, label : string, command : command} -> result
  val runIdentified : {parent : string, label : string, command : command,
                       identity : Record.t} -> result
  val success : result -> bool
  val statusText : status -> string
  val output : result -> string
end

structure Process :> CORPUS_PROCESS =
struct
  datatype status = Exited of int | Signaled of int | TimedOut
  type command = {program : string, args : string list, cwd : string,
                  env : string list, timeoutSeconds : int}
  type result = {status : status, directory : string}
  fun statusText (Exited n) = "exit:" ^ Int.toString n
    | statusText (Signaled n) = "signal:" ^ Int.toString n
    | statusText TimedOut = "timeout"
  fun success ({status = Exited 0, ...} : result) = true | success _ = false
  fun output ({directory, ...} : result) = Files.read (directory ^ "/stdout.log")
  fun executable p = (OS.FileSys.access (p, [OS.FileSys.A_EXEC])
    andalso not (OS.FileSys.isDir p)) handle OS.SysErr _ => false
  fun resolve requested =
    let val name = if requested = "rune" then getOpt (OS.Process.getEnv "RUNE", requested)
                   else if requested = "runevm" then getOpt (OS.Process.getEnv "RUNEVM", requested)
                   else requested
    in
    if String.isSubstring "/" name then
      if executable name then Files.absolute name else raise Fail ("missing executable: " ^ name)
    else
      let val dirs = String.fields (fn c => c = #":") (getOpt (OS.Process.getEnv "PATH", ""))
          val paths = List.map (fn d => OS.Path.concat (if d = "" then "." else d, name)) dirs
      in case List.find executable paths of
        SOME path => Files.absolute path
      | NONE => raise Fail ("missing executable on PATH: " ^ name) end end
  fun environment () =
    let
      val names = ["PATH", "HOME", "TMPDIR", "RUNE", "RUNEVM", "CORPUS_RUNE_LIB",
                   "CC", "CXX", "AR", "AS", "LD",
                   "CFLAGS", "CXXFLAGS", "LDFLAGS", "PKG_CONFIG_PATH",
                   "MAKEFLAGS", "CMAKE_BUILD_PARALLEL_LEVEL"]
      val inherited = List.mapPartial (fn key => Option.map (fn value => key ^ "=" ^ value)
                        (OS.Process.getEnv key)) names
    in ["LC_ALL=C", "LANG=C", "TZ=UTC"] @ inherited end
  fun signalNumber s = SysWord.toInt (Posix.Signal.toWord s)
  fun decode Posix.Process.W_EXITED = Exited 0
    | decode (Posix.Process.W_EXITSTATUS w) = Exited (Word8.toInt w)
    | decode (Posix.Process.W_SIGNALED s) = Signaled (signalNumber s)
    | decode (Posix.Process.W_STOPPED s) = Signaled (signalNumber s)
  fun runIdentified {parent, label, identity, command = {program, args, cwd, env, timeoutSeconds}} =
    let
      val () = if timeoutSeconds > 0 then () else raise Fail "timeout must be positive"
      val directory = Files.freshDir parent
      val started = Time.toString (Time.now ())
      val base = [("kind", "process"), ("label", label), ("program", program),
                  ("cwd", cwd), ("started", started),
                  ("timeout.seconds", Int.toString timeoutSeconds)] @
                 Record.strings "args" args @ Record.strings "env" env @ identity
      fun save fields = Files.record (directory ^ "/step.record", fields @ base)
      val () = save [("status", "preparing")]
      fun execute () =
        let
          val timeout = resolve "timeout"
          val target = resolve (if String.isSubstring "/" program andalso
                                   not (OS.Path.isAbsolute program)
                                then OS.Path.concat (cwd, program) else program)
          val tracing = Record.find identity "trace.files" = SOME "true"
          val tracer = if tracing then resolve "strace" else target
          val targetArgs = if tracing then
            ["-f", "-qq", "-yy", "-s", "4096", "-e", "trace=execve,openat,open,chdir,readlink,readlinkat",
             "-o", directory ^ "/files.trace.log", "--", target] @ args else args
          val () = save [("status", "starting"), ("executable", target), ("timeout.executable", timeout)]
          val () = TextIO.flushOut TextIO.stdOut
          val () = TextIO.flushOut TextIO.stdErr
          val child = Posix.Process.fork ()
        in
          case child of
            NONE =>
              ((let
                  val () = Posix.ProcEnv.setpgid {pid = NONE, pgid = NONE}
                  val perms = Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr]
                  fun redirect (path, dest) =
                    let val fd = Posix.FileSys.creat (path, perms)
                    in Posix.IO.dup2 {old = fd, new = dest};
                       if fd = dest then () else Posix.IO.close fd end
                  val () = redirect (directory ^ "/stdout.log", Posix.FileSys.stdout)
                  val () = redirect (directory ^ "/stderr.log", Posix.FileSys.stderr)
                  val input = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_RDONLY,
                                                  Posix.FileSys.O.flags [])
                  val () = Posix.IO.dup2 {old = input, new = Posix.FileSys.stdin}
                  val () = if input = Posix.FileSys.stdin then () else Posix.IO.close input
                  val () = OS.FileSys.chDir cwd
                in Posix.Process.exece (timeout,
                     timeout :: "--verbose" :: "--kill-after=2s" ::
                     (Int.toString (timeoutSeconds + 5) ^ "s") :: tracer :: targetArgs, env) end)
               handle e => (TextIO.output (TextIO.stdErr, "corpus: child setup failed: " ^
                                           General.exnMessage e ^ "\n");
                            TextIO.flushOut TextIO.stdErr;
                            Posix.Process.exit (Word8.fromInt 126)))
          | SOME pid =>
              let
                val running = [("pid", SysWord.toString (Posix.Process.pidToWord pid)),
                               ("executable", target), ("timeout.executable", timeout)]
                val () = save (("status", "running") :: running)
                val timer = Timer.startRealTimer ()
                fun send signal =
                  (Posix.Process.kill (Posix.Process.K_GROUP pid, signal)
                   handle OS.SysErr _ => ())
                fun wait () =
                  case Posix.Process.waitpid_nh (Posix.Process.W_CHILD pid, []) of
                    SOME (_, raw) => decode raw
                  | NONE =>
                      if Time.>= (Timer.checkRealTimer timer, Time.fromSeconds (IntInf.fromInt timeoutSeconds))
                      then (save (("status", "terminating-timeout") :: running);
                            send Posix.Signal.term;
                            OS.Process.sleep (Time.fromMilliseconds (IntInf.fromInt 100));
                            send Posix.Signal.kill;
                            ignore (Posix.Process.waitpid (Posix.Process.W_CHILD pid, []));
                            TimedOut)
                      else (OS.Process.sleep (Time.fromMilliseconds (IntInf.fromInt 10)); wait ())
                val status = wait ()
                val () = save ([("status", statusText status),
                                ("finished", Time.toString (Time.now ()))] @ running)
              in {status = status, directory = directory} end
        end
    in execute () handle e =>
      (save [("status", "infrastructure-failure"), ("error", General.exnMessage e),
             ("finished", Time.toString (Time.now ()))]; raise e) end
  fun run {parent, label, command} =
    runIdentified {parent = parent, label = label, command = command, identity = []}
end
