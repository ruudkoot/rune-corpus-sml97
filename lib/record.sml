signature CORPUS_RECORD =
sig
  type t = (string * string) list
  exception Invalid of string
  val encode : t -> string
  val decode : string -> t
  val find : t -> string -> string option
  val require : t -> string -> string
  val strings : string -> string list -> t
  val getStrings : t -> string -> string list
end

structure Record :> CORPUS_RECORD =
struct
  type t = (string * string) list
  exception Invalid of string
  fun validKey s = size s > 0 andalso
    List.all (fn c => Char.isAlphaNum c orelse List.exists (fn d => c = d) [#".", #"_", #"-"])
      (String.explode s)
  fun canonical fields =
    let
      val () = List.app (fn (key, value) =>
        if validKey key andalso not (String.isSubstring (str (Char.chr 0)) value)
        then () else raise Invalid ("invalid field: " ^ key)) fields
      fun split ([], a, b) = (a, b)
        | split ([x], a, b) = (x :: a, b)
        | split (x :: y :: rest, a, b) = split (rest, x :: a, y :: b)
      fun merge ([], ys) = ys | merge (xs, []) = xs
        | merge (xs as (x as (k, _)) :: xr, ys as (y as (l, _)) :: yr) =
          (case String.compare (k, l) of LESS => x :: merge (xr, ys)
           | GREATER => y :: merge (xs, yr)
           | EQUAL => raise Invalid ("duplicate key: " ^ k))
      fun sort [] = [] | sort [x] = [x]
        | sort xs = let val (a, b) = split (xs, [], []) in merge (sort a, sort b) end
    in sort fields end
  fun escape s = String.translate
    (fn #"\\" => "\\\\" | #"\n" => "\\n" | #"\r" => "\\r" | #"\t" => "\\t" | c => str c) s
  fun unescape s =
    let
      fun loop [] = []
        | loop (#"\\" :: #"\\" :: cs) = #"\\" :: loop cs
        | loop (#"\\" :: #"n" :: cs) = #"\n" :: loop cs
        | loop (#"\\" :: #"r" :: cs) = #"\r" :: loop cs
        | loop (#"\\" :: #"t" :: cs) = #"\t" :: loop cs
        | loop (#"\\" :: _) = raise Invalid "invalid escape"
        | loop (c :: cs) = if c = #"\t" orelse c = #"\r"
                          then raise Invalid "unescaped control character" else c :: loop cs
    in String.implode (loop (String.explode s)) end
  fun encode fields = "corpus-record-v1\n" ^ String.concat
    (List.map (fn (k, v) => k ^ "\t" ^ escape v ^ "\n") (canonical fields))
  fun decode text =
    let
      fun row s = case String.fields (fn c => c = #"\t") s of
        [k, v] => (k, unescape v)
      | _ => raise Invalid "expected key and value separated by one tab"
    in
      if size text = 0 orelse String.sub (text, size text - 1) <> #"\n"
      then raise Invalid "incomplete record"
      else case String.fields (fn c => c = #"\n") text of
        "corpus-record-v1" :: rest =>
          canonical (List.map row (List.take (rest, length rest - 1)))
      | _ => raise Invalid "unsupported record version"
    end
  fun find fields key = Option.map #2 (List.find (fn (k, _) => k = key) fields)
  fun require fields key = case find fields key of SOME s => s
    | NONE => raise Invalid ("missing key: " ^ key)
  fun strings key values =
    let fun loop (_, []) = []
          | loop (i, s :: rest) = (key ^ "." ^ Int.toString i, s) :: loop (i + 1, rest)
    in (key ^ ".count", Int.toString (length values)) :: loop (0, values) end
  fun getStrings fields key =
    let val raw = require fields (key ^ ".count")
        val n = case Int.fromString raw of
          SOME n => if n >= 0 andalso Int.toString n = raw then n
                    else raise Invalid ("invalid count: " ^ key)
        | NONE => raise Invalid ("invalid count: " ^ key)
        val values = Array.array (n, NONE : string option)
        val prefix = key ^ "."
        fun collect (field, value) = if String.isPrefix prefix field then
          let val suffix = String.extract (field, size prefix, NONE)
          in case Int.fromString suffix of SOME i =>
            if i >= 0 andalso i < n andalso Int.toString i = suffix andalso
               not (Option.isSome (Array.sub (values, i)))
            then Array.update (values, i, SOME value) else ()
           | NONE => () end else ()
        val () = List.app collect fields
    in List.tabulate (n, fn i => case Array.sub (values, i) of SOME value => value
         | NONE => raise Invalid ("missing key: " ^ prefix ^ Int.toString i)) end
end
