signature CORPUS_RECIPE =
sig
  type t
  val load : string -> t
  val fields : t -> Record.t
  val get : t -> string -> string
  val name : t -> string
  val variants : t -> string list
  val expand : (string * string) list -> string -> string
  val commands : t -> string -> (string * string) list -> Process.command list
  val archives : t -> (string * string * string) list
  val checkCompiler : t -> Record.t -> unit
end

structure Recipe :> CORPUS_RECIPE =
struct
  type t = Record.t
  fun fields r = r
  fun get r k = Record.require r k
  fun name r = get r "name" ^ "/" ^ get r "version"
  fun variants r = Record.getStrings r "variants"
  fun checkCompiler r compiler =
    List.app (fn (field, allowed) =>
      if Option.isSome (Record.find r (allowed ^ ".count")) then
        let val actual = Record.require compiler field
        in if List.exists (fn value => value = actual) (Record.getStrings r allowed)
           then () else raise Fail ("unsupported compiler " ^ field ^ ": " ^ actual)
        end
      else ()) [("family", "compiler.families"), ("version", "compiler.versions"),
                ("target", "compiler.targets")]
  fun safeName s = size s > 0 andalso s <> "." andalso s <> ".." andalso
    List.all (fn c => Char.isAlphaNum c orelse c = #"." orelse c = #"-" orelse c = #"_")
      (String.explode s)
  fun archives r =
    let val names = if Option.isSome (Record.find r "archives.count")
                    then Record.getStrings r "archives" else []
        fun one name =
          let val prefix = "archive." ^ name
              val hash = get r (prefix ^ ".sha256")
          in if safeName name andalso Digest.valid hash then
               (name, get r (prefix ^ ".url"), hash)
             else raise Fail "invalid supplementary archive identity" end
    in List.map one names end
  fun load path =
    let val r = Files.load path
        val () = if get r "kind" = "package" then () else raise Fail "expected a package recipe"
        val () = List.app (fn k => if safeName (get r k) then ()
                              else raise Fail ("invalid package " ^ k)) ["name", "version"]
        val () = if Digest.valid (get r "source.sha256") then () else raise Fail "invalid source checksum"
        val vs = variants r
        val () = if length vs > 0 andalso List.all safeName vs then () else raise Fail "invalid variants"
        val _ = archives r
        val strip = getOpt (Record.find r "source.strip-components", "1")
        val () = case Int.fromString strip of SOME n =>
          if n >= 0 andalso Int.toString n = strip then () else raise Fail "invalid source strip count"
          | NONE => raise Fail "invalid source strip count"
    in r end
  fun expand bindings s =
    let
      fun loop i = if i >= size s then ""
        else if String.sub (s, i) = #"{"
        then
          let fun close j = if j >= size s then raise Fail "unterminated recipe substitution"
                            else if String.sub (s, j) = #"}" then j else close (j + 1)
              val j = close (i + 1)
              val key = String.substring (s, i + 1, j - i - 1)
              val value = case List.find (fn (k, _) => k = key) bindings of
                SOME (_, v) => v | NONE => raise Fail ("unknown recipe substitution: " ^ key)
          in value ^ loop (j + 1) end
        else str (String.sub (s, i)) ^ loop (i + 1)
    in loop 0 end
  fun commands r phase bindings =
    let val countText = get r (phase ^ ".count")
        val count = case Int.fromString countText of SOME n =>
          if n >= 0 andalso Int.toString n = countText then n else raise Fail "invalid command count"
          | NONE => raise Fail "invalid command count"
        fun one i =
          let val prefix = phase ^ "." ^ Int.toString i
              fun field k = expand bindings (get r (prefix ^ "." ^ k))
              val timeout = case Int.fromString (field "timeout") of
                SOME n => if n > 0 then n else raise Fail "invalid command timeout"
              | NONE => raise Fail "invalid command timeout"
              val env = Process.environment ()
              val isolated = Record.find r "environment.isolated" = SOME "true"
              val path = if isolated then expand bindings
                (getOpt (Record.find r "environment.path.prefix", "") ^ "{tools}") else ""
              val declared = if Option.isSome (Record.find r "environment.set.count") then
                List.map (expand bindings) (Record.getStrings r "environment.set") else []
              fun key s = hd (String.fields (fn c => c = #"=") s)
              val () = List.app (fn s => if String.isSubstring "=" s andalso safeName (key s)
                then () else raise Fail "invalid declared environment entry") declared
              val controlled = (if isolated then
                ["PATH=" ^ path, "RUNE=" ^ expand bindings "{rune}",
                 "RUNEVM=" ^ expand bindings "{runevm}"] else []) @ declared
              val merged = controlled @ List.filter (fn s =>
                not (List.exists (fn t => key s = key t) controlled)) env
          in {program = field "program", args = List.map (expand bindings) (Record.getStrings r (prefix ^ ".args")),
              cwd = field "cwd", env = merged, timeoutSeconds = timeout} end
    in List.tabulate (count, one) end
end
