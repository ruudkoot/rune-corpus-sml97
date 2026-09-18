structure Report =
struct
  fun show path =
    let val r = Files.load path
    in List.app (fn (k, v) => print (k ^ ": " ^ v ^ "\n")) r end
  fun compilers root =
    let val parent = Files.absolute root ^ "/_work/attempts"
        fun one name =
          let val dir = parent ^ "/" ^ name
              fun artifact file = if Files.exists (dir ^ "/" ^ file) then
                let val r = Files.load (dir ^ "/" ^ file)
                in case Record.find r "bootstrap.stage" of NONE => () | SOME stage =>
                  print (Record.require r "package" ^ " " ^ Record.require r "variant" ^
                    " stage=" ^ stage ^ " " ^ dir ^ "/" ^ file ^ "\n") end else ()
          in if Files.exists (dir ^ "/attempt.record") andalso
                Record.find (Files.load (dir ^ "/attempt.record")) "status" = SOME "passed"
             then List.app artifact ["artifact.record", "bootstrap-artifact.record"] else () end
    in if Files.exists parent then List.app one (Files.sorted (Files.entries parent)) else () end
  fun attempts root =
    let val parent = Files.absolute root ^ "/_work/attempts"
    in if Files.exists parent then
      List.app (fn name =>
        let val path = parent ^ "/" ^ name
            val r = Files.load (path ^ "/attempt.record")
            val status = Record.require r "status"
            val displayed = if status = "running" then "incomplete (inspect steps; may still be live)" else status
        in print (name ^ " " ^ displayed ^ " " ^ Record.require r "package" ^
                  " " ^ Record.require r "variant" ^ " " ^ Record.require r "phase" ^ "\n") end)
        (List.filter (fn n => Files.exists (parent ^ "/" ^ n ^ "/attempt.record"))
          (Files.entries parent)) else print "no attempts\n" end
  fun search path needle =
    let
      fun file name =
        let val s = TextIO.openIn name
            fun loop n = case TextIO.inputLine s of NONE => ()
              | SOME line => (if String.isSubstring needle line then
                                print (name ^ ":" ^ Int.toString n ^ ":" ^ line) else (); loop (n + 1))
        in (loop 1 before TextIO.closeIn s)
           handle e => (TextIO.closeIn s; raise e) end
      fun walk p = if OS.FileSys.isDir p then
        List.app (fn n => walk (OS.Path.concat (p, n))) (Files.entries p)
        else if String.isSuffix ".log" p then file p else ()
    in walk path end
  fun detail attempt =
    let val r = Files.load (attempt ^ "/attempt.record")
        val steps = attempt ^ "/steps"
        val () = show (attempt ^ "/attempt.record")
        fun one n =
          let val dir = steps ^ "/" ^ n
          in if Files.exists (dir ^ "/step.record") then
            let val s = Files.load (dir ^ "/step.record")
                val status = Record.require s "status"
            in if status = "exit:0" then () else
              print (Record.require s "label" ^ ": " ^ status ^ "; logs: " ^ dir ^ "\n") end
            else () end
    in if Files.exists steps then List.app one (Files.sorted (Files.entries steps)) else ();
       print ("Rerun using the saved recipe " ^ attempt ^ "/recipe.record and variant " ^
         Record.require r "variant" ^ ". Recreate prerequisites from system.record and selected-tools.record; " ^
         "each step records its environment. See docs/evidence.md.\n") end
  fun export attempt destination =
    let val attempt = Files.absolute attempt
        val record = Files.load (attempt ^ "/attempt.record")
        val () = if Record.require record "status" = "running"
                 then raise Fail "cannot export an incomplete or live attempt" else ()
        val steps = attempt ^ "/steps"
        val files = List.filter (fn n => String.isSuffix ".record" n) (Files.entries attempt)
        val () = Files.atomic (attempt ^ "/RERUN.md",
          "# Evidence bundle\n\nPackage: " ^ Record.require record "package" ^ "\n\n" ^
          "Run `bin/corpus " ^ Record.require record "phase" ^
          " PATH/TO/recipe.record " ^ Record.require record "variant" ^
          (case Record.find record "compiler.record" of NONE => "" | SOME p => " " ^ p) ^
          "` from the matching corpus checkout. Restore the recorded installed Rune, " ^
          "native prerequisites and relevant step environments first.\n\n" ^
          "This bundle contains records and raw logs. It excludes downloaded archives, " ^
          "upstream sources and compiler installations. Semantic-suite evidence includes " ^
          "its generated reproducer programs, results and logs. The recipe names the pinned " ^
          "source and the checkout supplies its owned inputs and patches. Full environmental " ^
          "reproduction is not guaranteed; inspect the recorded provenance gaps.\n")
        val output = Files.absolute destination
        val () = if Files.exists output then raise Fail "export destination already exists" else ()
        val suiteFiles = if Files.exists (attempt ^ "/build/suites") then
          List.map (fn path => OS.Path.mkRelative {path = path, relativeTo = attempt})
            (List.filter (fn p => List.exists (fn suffix => String.isSuffix suffix p)
              [".record", ".log", ".sml"]) (Files.tree (attempt ^ "/build/suites")))
          else []
    in ignore (Lifecycle.tool (OS.Path.dir attempt ^ "/exports") (OS.Path.dir attempt) "export" "tar"
        (["-czf", output, "-C", attempt] @ files @ ["RERUN.md", "steps"] @ suiteFiles));
       print ("exported records and raw logs to " ^ output ^ "\n") end
  fun compare left right =
    let
      fun fields label file =
        let val a = Files.load (left ^ "/" ^ file)
            val b = Files.load (right ^ "/" ^ file)
            val keys = Files.sorted (List.map #1 a @
              List.map #1 (List.filter (fn (k, _) => not (Option.isSome (Record.find a k))) b))
            fun value r k = getOpt (Record.find r k, "<absent>")
        in List.app (fn k => if value a k = value b k then () else
          print (label ^ "." ^ k ^ ": " ^ value a k ^ " -> " ^ value b k ^ "\n")) keys end
    in fields "attempt" "attempt.record";
       if Files.exists (left ^ "/specification.record") andalso
          Files.exists (right ^ "/specification.record")
       then fields "specification" "specification.record" else ();
       print ("Raw evidence: " ^ left ^ "/steps and " ^ right ^ "/steps\n") end
  fun failureGroups root =
    let
      val parent = Files.absolute root ^ "/_work/attempts"
      val destination = Files.freshDir (Files.absolute root ^ "/_work/reports")
      fun lastLine path = if not (Files.exists path) then "" else
        let val input = TextIO.openIn path
            fun loop last = case TextIO.inputLine input of NONE => last
              | SOME line => if List.all Char.isSpace (String.explode line) then loop last
                             else loop line
        in (loop "" before TextIO.closeIn input)
           handle e => (TextIO.closeIn input; raise e) end
      fun normalize line = String.concatWith " " (List.map (fn word =>
        if String.isPrefix "/" word then "<path>"
        else if size word > 0 andalso List.all Char.isDigit (String.explode word) then "<number>"
        else word) (String.tokens Char.isSpace line))
      fun diagnostic directory =
        let val r = Files.load (directory ^ "/attempt.record")
            val operation = getOpt (Record.find r "operation", "unknown")
            val steps = directory ^ "/steps"
            val records = if Files.exists steps then List.mapPartial (fn n =>
              let val path = steps ^ "/" ^ n
              in if Files.exists (path ^ "/step.record") then
                SOME (path, Files.load (path ^ "/step.record")) else NONE end) (Files.entries steps) else []
            val matching = List.find (fn (_, s) => Record.find s "label" = SOME operation andalso
              Record.find s "status" <> SOME "exit:0") records
            val observed = case matching of NONE => getOpt (Record.find r "error", "no diagnostic")
              | SOME (path, _) =>
                  let val stderr = lastLine (path ^ "/stderr.log")
                  in if stderr = "" then lastLine (path ^ "/stdout.log") else stderr end
        in (Record.require r "package" ^ " | " ^
            getOpt (Record.find r "failure.class", "unknown") ^ " | " ^ operation ^ " | " ^
            normalize observed, directory) end
      val failures = List.filter (fn directory => Files.exists (directory ^ "/attempt.record") andalso
        Record.find (Files.load (directory ^ "/attempt.record")) "status" = SOME "failed")
        (List.map (fn n => parent ^ "/" ^ n)
          (if Files.exists parent then Files.sorted (Files.entries parent) else []))
      fun add ((signatureText, path), []) = [(signatureText, [path])]
        | add ((signatureText, path), (key, paths) :: rest) =
            if signatureText = key then (key, path :: paths) :: rest
            else (key, paths) :: add ((signatureText, path), rest)
      val groups = List.foldl add [] (List.map diagnostic failures)
      fun group (i, (key, paths)) =
        (print (Int.toString (length paths) ^ " occurrences: " ^ key ^ "\n");
         List.app (fn p => print ("  " ^ p ^ "\n")) paths;
         ("group." ^ Int.toString i ^ ".signature", key) ::
         Record.strings ("group." ^ Int.toString i ^ ".attempts") paths)
      val fields = List.concat (List.tabulate (length groups, fn i => group (i, List.nth (groups, i))))
      val () = Files.record (destination ^ "/groups.record",
        [("kind", "failure-groups"), ("group.count", Int.toString (length groups)),
         ("method", "package, class, operation and last nonempty stderr line (stdout fallback); normalize standalone absolute paths and numbers; diagnostic similarity is not a root-cause claim")] @ fields)
    in print ("failure groups: " ^ destination ^ "/groups.record\n") end
end
