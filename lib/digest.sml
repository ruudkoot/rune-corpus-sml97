signature CORPUS_DIGEST =
sig
  val valid : string -> bool
  val file : {steps : string, path : string} -> string
  val files : {steps : string, paths : string list} -> (string * string) list
  val text : {steps : string, value : string} -> string
end

structure Digest :> CORPUS_DIGEST =
struct
  fun valid s = size s = 64 andalso List.all
    (fn c => Char.isDigit c orelse (c >= #"a" andalso c <= #"f")) (String.explode s)
  fun file {steps, path} =
    let val result = Process.run {parent = steps, label = "sha256", command =
          {program = Process.resolve "sha256sum", args = ["--", Files.absolute path],
           cwd = OS.FileSys.getDir (), env = Process.environment (), timeoutSeconds = 120}}
        val line = Process.output result
        val hash = if size line >= 64 then String.substring (line, 0, 64) else ""
    in if Process.success result andalso valid hash then hash
       else raise Fail ("sha256 failed; see " ^ #directory result) end
  fun text {steps, value} =
    let val dir = Files.freshDir (steps ^ "/inputs")
        val path = dir ^ "/content"
    in Files.write (path, value); file {steps = steps, path = path} end
  fun batch {steps, paths} =
    if null paths then [] else
    let val result = Process.run {parent = steps, label = "sha256-files", command =
          {program = Process.resolve "sha256sum", args = "--" :: paths,
           cwd = OS.FileSys.getDir (), env = Process.environment (), timeoutSeconds = 120}}
        val lines = String.tokens (fn c => c = #"\n") (Process.output result)
        fun pair (path, line) =
          let val hash = if size line >= 64 then String.substring (line, 0, 64) else ""
          in if valid hash then (path, hash) else raise Fail "invalid sha256 output" end
    in if Process.success result andalso length lines = length paths
       then ListPair.map pair (paths, lines)
       else raise Fail ("file hashing failed; see " ^ #directory result) end
  fun files {steps, paths} =
    let
      fun take (0, xs, acc) = (List.rev acc, xs)
        | take (_, [], acc) = (List.rev acc, [])
        | take (n, x :: xs, acc) = take (n - 1, xs, x :: acc)
      fun loop [] = []
        | loop xs = let val (group, rest) = take (128, xs, [])
                    in batch {steps = steps, paths = group} @ loop rest end
    in loop paths end
end
