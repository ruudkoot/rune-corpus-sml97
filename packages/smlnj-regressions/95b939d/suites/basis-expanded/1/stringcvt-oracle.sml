(* Explicit OK expectations for every active declaration in the pinned source.
   Counts include each element of list-valued scanning tests. *)
val checks : (string * int * string list) list = [
  ("test1", 1, [Subject.test1]),
  ("test2", 1, [Subject.test2]),
  ("test3", 1, [Subject.test3]),
  ("test4", 1, [Subject.test4]),
  ("test5", 1, [Subject.test5]),
  ("test6", 1, [Subject.test6]),
  ("test7", 1, [Subject.test7]),
  ("test8", 1, [Subject.test8]),
  ("test9", 1, [Subject.test9]),
  ("test10", 1, [Subject.test10])];
val () = List.app (fn (name, expectedCount, results) =>
  let
    val () = if length results = expectedCount then ()
      else raise Fail ("stringcvt." ^ name ^ ": wrong assertion count")
    fun check ([], _) = ()
      | check (result :: rest, index) =
          if result = "OK" then check (rest, index + 1)
          else raise Fail ("stringcvt." ^ name ^ "[" ^ Int.toString index ^
            "]: expected OK, got " ^ result)
  in check (results, 0) end) checks;
