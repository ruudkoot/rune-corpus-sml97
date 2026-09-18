(* HaMLet's interpreted Basis does not provide IntInf. Stay within the
   portable Int range while checking recursive evaluation and List.foldl. *)
fun fact (0 : int) = 1 | fact n = n * fact (n - 1);
val () = if fact 10 = 3628800 andalso List.foldl op+ 0 [1,2,3,4] = 10 then print "CORPUS_HAMLET_SMOKE_PASS\n" else raise Fail "semantic smoke";
