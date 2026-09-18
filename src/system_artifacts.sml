(* Linux adapter. Preserve the raw strace alongside this conservative summary.
   Paths seen in calls may include probes; fd annotations identify opened files.
   Relative, escaped, removed or inaccessible paths remain explicit gaps. *)
structure SystemArtifacts =
struct
  fun capture {steps, trace, destination} =
    let
      val buckets = Array.array (4093, [] : string list)
      fun bucket s = List.foldl (fn (c, h) => (h * 33 + Char.ord c) mod 4093) 0 (String.explode s)
      fun systemPath s = List.exists (fn p => String.isPrefix p s)
        ["/usr/", "/lib/", "/lib64/", "/bin/", "/sbin/", "/etc/"]
      fun add s = if systemPath s andalso not (String.isSubstring "\\" s) then
        let val i = bucket s
            val xs = Array.sub (buckets, i)
        in if List.exists (fn x => x = s) xs then () else Array.update (buckets, i, s :: xs) end
        else ()
      fun scan line =
        let
          fun close (i, delimiter) = if i >= size line then i
            else if String.sub (line, i) = delimiter then i else close (i + 1, delimiter)
          fun loop i = if i >= size line then () else
            let val c = String.sub (line, i)
            in if c = #"\"" orelse c = #"<" then
              let val j = close (i + 1, if c = #"<" then #">" else #"\"")
              in add (String.substring (line, i + 1, j - i - 1)); loop (j + 1) end
              else loop (i + 1) end
        in if String.isSubstring "= -1 " line then () else loop 0 end
      val input = TextIO.openIn trace
      fun loop () = case TextIO.inputLine input of NONE => () | SOME line => (scan line; loop ())
      val () = (loop () before TextIO.closeIn input)
        handle e => (TextIO.closeIn input; raise e)
      val paths = Files.sorted (Array.foldr op@ [] buckets)
      fun readable p = (Files.exists p andalso not (OS.FileSys.isDir p) andalso
        OS.FileSys.access (p, [OS.FileSys.A_READ])) handle OS.SysErr _ => false
      val readablePaths = List.filter readable paths
      val missing = List.filter (fn p => not (readable p)) paths
      val hashes = Digest.files {steps = steps, paths = readablePaths}
      val fields = [("kind", "observed-system-artifacts"), ("trace", trace),
        ("provenance.gaps", "Linux strace summary: includes observed probes; relative/escaped names may be omitted; hashes captured after execution; see raw trace for interrupted calls and paths outside system directories")] @
        Record.strings "files" (List.map (fn (p, h) => p ^ "\t" ^ h) hashes) @
        Record.strings "unhashed" missing
    in Files.record (destination, fields); fields end
end
