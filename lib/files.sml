signature CORPUS_FILES =
sig
  val exists : string -> bool
  val mkdir : string -> unit
  val read : string -> string
  val write : string * string -> unit
  val atomic : string * string -> unit
  val record : string * Record.t -> unit
  val load : string -> Record.t
  val freshDir : string -> string
  val entries : string -> string list
  val absolute : string -> string
  val sorted : string list -> string list
  val tree : string -> string list
end

structure Files :> CORPUS_FILES =
struct
  fun exists path = OS.FileSys.access (path, []) handle OS.SysErr _ => false
  fun mkdir path = if path = "" orelse path = "." orelse exists path then ()
    else (mkdir (OS.Path.dir path); OS.FileSys.mkDir path)
  fun read path =
    let val s = TextIO.openIn path
    in (TextIO.inputAll s before TextIO.closeIn s)
       handle e => (TextIO.closeIn s; raise e) end
  fun write (path, text) =
    let val s = TextIO.openOut path
    in (TextIO.output (s, text); TextIO.closeOut s)
       handle e => (TextIO.closeOut s; raise e) end
  val serial = ref 0
  fun token () =
    (serial := !serial + 1;
     IntInf.toString (Time.toMicroseconds (Time.now ())) ^ "-" ^
     SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ())) ^ "-" ^
     Int.toString (!serial))
  fun atomic (path, text) =
    let val tmp = path ^ ".tmp-" ^ token ()
    in write (tmp, text); OS.FileSys.rename {old = tmp, new = path} end
  fun record (path, data) = atomic (path, Record.encode data)
  fun load path = Record.decode (read path)
  fun freshDir parent =
    let val () = mkdir parent
        val path = OS.Path.concat (parent, token ())
    in OS.FileSys.mkDir path; path end
  fun entries path =
    let val d = OS.FileSys.openDir path
        fun next acc = case OS.FileSys.readDir d of NONE => List.rev acc
                     | SOME n => next (n :: acc)
    in (next [] before OS.FileSys.closeDir d)
       handle e => (OS.FileSys.closeDir d; raise e) end
  fun absolute path = OS.Path.mkAbsolute {path = path, relativeTo = OS.FileSys.getDir ()}
  fun sorted xs =
    let
      fun split ([], a, b) = (a, b)
        | split ([x], a, b) = (x :: a, b)
        | split (x :: y :: rest, a, b) = split (rest, x :: a, y :: b)
      fun merge ([], ys) = ys | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) =
          if String.< (x, y) then x :: merge (xs, y :: ys) else y :: merge (x :: xs, ys)
      fun sort [] = [] | sort [x] = [x]
        | sort xs = let val (a, b) = split (xs, [], []) in merge (sort a, sort b) end
    in sort xs end
  fun tree path =
    if OS.FileSys.isDir path then
      List.concat (List.map (fn n => tree (OS.Path.concat (path, n))) (sorted (entries path)))
    else [path]
end
