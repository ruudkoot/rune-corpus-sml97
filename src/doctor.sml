structure Doctor =
struct
  fun check {root, path, variant, dir} =
    let
      val r = Recipe.load path
      val () = if List.exists (fn v => v = variant) (Recipe.variants r)
               then () else raise Fail ("unsupported variant: " ^ variant)
      val names = Record.getStrings (Recipe.fields r) "tools"
      fun one name = (ignore (Process.resolve name); NONE)
        handle e => SOME (name ^ ": " ^ General.exnMessage e)
      val missingTools = List.mapPartial one names
      fun probe program args =
        let val p = Process.run {parent = dir ^ "/steps", label = "prerequisite:" ^ program,
              command = {program = program, args = args, cwd = Files.absolute root,
                         env = Process.environment (), timeoutSeconds = 15}}
        in if Process.success p then Process.output p else raise Fail ("prerequisite probe failed: " ^ program) end
      fun version s = List.mapPartial Int.fromString
        (String.tokens (fn c => not (Char.isDigit c))
          (hd (String.fields (fn c => c = #"\n") s)))
      fun atLeast (_, []) = true
        | atLeast ([], _ :: _) = false
        | atLeast (a :: rest, b :: needed) = a > b orelse a = b andalso atLeast (rest, needed)
      fun minimum (key, needed) =
        if String.isPrefix "minimum." key then
          let val tool = String.extract (key, size "minimum.", NONE)
          in (if atLeast (version (probe tool ["--version"]), version needed) then NONE
              else SOME (tool ^ " >= " ^ needed ^ " is required"))
              handle e => SOME (General.exnMessage e) end
        else NONE
      fun platform () = case Record.find (Recipe.fields r) "host" of NONE => []
        | SOME expected =>
          let fun trim s = String.concat (String.tokens Char.isSpace s)
              val actual = trim (probe "uname" ["-m"]) ^ "-" ^ trim (probe "uname" ["-s"])
          in if actual = expected then [] else ["unsupported host " ^ actual ^ "; recipe requires " ^ expected] end
      val missing = missingTools @ List.mapPartial minimum (Recipe.fields r) @ platform ()
      val () = Files.record (dir ^ "/doctor.record",
        [("kind", "recipe-doctor"), ("package", Recipe.name r), ("variant", variant),
         ("status", if null missing then "passed" else "missing-prerequisites")] @
         Record.strings "missing" missing @ Record.strings "tools" names)
    in List.app (fn s => TextIO.output (TextIO.stdErr, s ^ "\n")) missing;
       print ("recipe doctor: " ^ dir ^ "/doctor.record\n"); null missing end
  fun recipe {root, path, variant} =
    check {root = root, path = path, variant = variant,
           dir = Files.freshDir (Files.absolute root ^ "/_work/doctor")}
end
