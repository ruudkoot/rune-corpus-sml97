(* A successful process exit alone is insufficient: SML/NJ can recover from
   interactive errors. The recipe also requires the marker printed below. *)
structure CorpusSmoke =
struct
  fun check (label, true) = ()
    | check (label, false) = raise Fail label
  fun factorial 0 = 1
    | factorial n = n * factorial (n - 1)
  fun sort [] = []
    | sort (x :: xs) =
      sort (List.filter (fn y => y < x) xs) @ [x] @
      sort (List.filter (fn y => y >= x) xs)
  val () = check ("recursive arithmetic", factorial 8 = 40320)
  val () = check ("lists", sort [3, 1, 4, 1, 5, 9] = [1, 1, 3, 4, 5, 9])
  val () = check ("IntInf", IntInf.toString (IntInf.pow (2, 80)) = "1208925819614629174706176")
  val () = check ("exceptions", (raise Fail "expected") handle Fail s => s = "expected")
  val a = Array.tabulate (20, fn i => i * i)
  val () = check ("arrays", Array.sub (a, 7) = 49)
  val () = print "CORPUS_SMLNJ_SMOKE_PASS\n"
end
val () = OS.Process.exit OS.Process.success
