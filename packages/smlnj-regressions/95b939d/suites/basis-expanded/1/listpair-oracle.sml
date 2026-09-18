(* Explicit OK expectations for every active declaration in the pinned source.
   Counts include each element of list-valued scanning tests. *)
val checks : (string * int * string list) list = [
  ("test1", 1, [Subject.test1]),
  ("test2a", 1, [Subject.test2a]),
  ("test2b", 1, [Subject.test2b]),
  ("test3a", 1, [Subject.test3a]),
  ("test3b", 1, [Subject.test3b]),
  ("test4", 1, [Subject.test4]),
  ("test5a", 1, [Subject.test5a]),
  ("test5b", 1, [Subject.test5b]),
  ("test5c", 1, [Subject.test5c]),
  ("test5d", 1, [Subject.test5d]),
  ("test5e", 1, [Subject.test5e]),
  ("test6", 1, [Subject.test6]),
  ("test7", 1, [Subject.test7])];
val () = List.app (fn (name, expectedCount, results) =>
  let
    val () = if length results = expectedCount then ()
      else raise Fail ("listpair." ^ name ^ ": wrong assertion count")
    fun check ([], _) = ()
      | check (result :: rest, index) =
          if result = "OK" then check (rest, index + 1)
          else raise Fail ("listpair." ^ name ^ "[" ^ Int.toString index ^
            "]: expected OK, got " ^ result)
  in check (results, 0) end) checks;
