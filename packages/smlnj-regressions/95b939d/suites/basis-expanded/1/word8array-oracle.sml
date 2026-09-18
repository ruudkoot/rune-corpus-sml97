(* Explicit OK expectations for every active declaration in the pinned source.
   Counts include each element of list-valued scanning tests. *)
val checks : (string * int * string list) list = [
  ("test1", 1, [Subject.test1]),
  ("test2", 1, [Subject.test2]),
  ("test3", 1, [Subject.test3]),
  ("test4a", 1, [Subject.test4a]),
  ("test4b", 1, [Subject.test4b]),
  ("test4c", 1, [Subject.test4c]),
  ("test5a", 1, [Subject.test5a]),
  ("test5b", 1, [Subject.test5b]),
  ("test6a", 1, [Subject.test6a]),
  ("test6b", 1, [Subject.test6b]),
  ("test6c", 1, [Subject.test6c]),
  ("test7", 1, [Subject.test7]),
  ("test8a", 1, [Subject.test8a]),
  ("test8b", 1, [Subject.test8b]),
  ("test9", 1, [Subject.test9]),
  ("test9a", 1, [Subject.test9a]),
  ("test9b", 1, [Subject.test9b]),
  ("test9c", 1, [Subject.test9c]),
  ("test9d", 1, [Subject.test9d]),
  ("test9e", 1, [Subject.test9e]),
  ("test9f", 1, [Subject.test9f]),
  ("test9g", 1, [Subject.test9g]),
  ("test9h", 1, [Subject.test9h]),
  ("test9i", 1, [Subject.test9i]),
  ("test10a", 1, [Subject.test10a]),
  ("test10b", 1, [Subject.test10b]),
  ("test10c", 1, [Subject.test10c]),
  ("test10d", 1, [Subject.test10d]),
  ("test10e", 1, [Subject.test10e]),
  ("test10f", 1, [Subject.test10f]),
  ("test10g", 1, [Subject.test10g]),
  ("test10h", 1, [Subject.test10h]),
  ("test10i", 1, [Subject.test10i]),
  ("test11a", 1, [Subject.test11a]),
  ("test11b", 1, [Subject.test11b]),
  ("test11c", 1, [Subject.test11c]),
  ("test11d", 1, [Subject.test11d]),
  ("test11e", 1, [Subject.test11e]),
  ("test11f", 1, [Subject.test11f]),
  ("test11g", 1, [Subject.test11g]),
  ("test11h", 1, [Subject.test11h]),
  ("test11i", 1, [Subject.test11i]),
  ("test11j", 1, [Subject.test11j]),
  ("test11k", 1, [Subject.test11k])];
val () = List.app (fn (name, expectedCount, results) =>
  let
    val () = if length results = expectedCount then ()
      else raise Fail ("word8array." ^ name ^ ": wrong assertion count")
    fun check ([], _) = ()
      | check (result :: rest, index) =
          if result = "OK" then check (rest, index + 1)
          else raise Fail ("word8array." ^ name ^ "[" ^ Int.toString index ^
            "]: expected OK, got " ^ result)
  in check (results, 0) end) checks;
