fun assert true = () | assert false = raise Fail "MLton smoke test"
fun sum 0 = 0 | sum n = n + sum (n - 1)
val () = assert (sum 100 = 5050)
val () = assert (IntInf.toString (IntInf.pow (2, 80)) = "1208925819614629174706176")
val a = Array.tabulate (30, fn i => i * i)
val () = assert (Array.sub (a, 11) = 121)
val () = print "CORPUS_MLTON_SMOKE_PASS\n"
