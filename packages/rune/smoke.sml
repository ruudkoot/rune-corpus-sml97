structure CorpusRuneSmoke =
struct
  fun fact n = if n = 0 then (1 : IntInf.int) else IntInf.fromInt n * fact (n - 1)
  val () = if fact 20 = 2432902008176640000 andalso
    List.foldl op+ 0 [1, 2, 3, 4] = 10 andalso Word8.toInt (Word8.fromInt 257) = 1
    then print "CORPUS_RUNE_SMOKE_PASS\n" else raise Fail "Rune bootstrap smoke"
end
