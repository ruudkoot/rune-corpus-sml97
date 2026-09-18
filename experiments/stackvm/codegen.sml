structure Program =
struct
  fun main (_, [destination, count]) =
        let
          val n = case Int.fromString count of SOME n =>
            if n > 0 andalso n <= 20000 then n else raise Fail "size outside 1..20000"
            | NONE => raise Fail "invalid size"
          val output = TextIO.openOut destination
          fun emit s = TextIO.output (output, s)
          fun loop i = if i > n then () else
            (emit ("PUSH " ^ Int.toString i ^ "\nDUP\nMUL\nADD\n"); loop (i + 1))
          val () = (emit "CORPUS-STACK-1\nPUSH 0\n"; loop 1; emit "HALT\n";
                    TextIO.closeOut output)
            handle e => (TextIO.closeOut output; raise e)
        in print ("CORPUS_STACK_CODE " ^ Int.toString n ^ "\n"); OS.Process.success end
    | main _ = (TextIO.output (TextIO.stdErr, "usage: codegen OUTPUT SIZE\n"); OS.Process.failure)
end
