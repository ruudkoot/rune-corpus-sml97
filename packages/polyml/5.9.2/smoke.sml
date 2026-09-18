val () = if List.foldl op+ 0 [1,2,3,4] = 10 andalso IntInf.pow (2,80) = 1208925819614629174706176 then print "CORPUS_POLYML_SMOKE_PASS\n" else raise Fail "smoke";
