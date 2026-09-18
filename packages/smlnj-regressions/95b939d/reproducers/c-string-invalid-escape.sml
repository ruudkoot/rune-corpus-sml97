(* The Basis STRING.fromCString contract uses the same failure rule as
   fromString: an illegal escape at the start must return NONE.
   https://smlfamily.github.io/Basis/string.html#SIG:STRING.fromCString:VAL *)
structure Program =
struct
  fun main (_, _) =
    case String.fromCString "\\q" of
      NONE => (print "CORPUS_INVALID_C_ESCAPE_REJECTED\n"; OS.Process.success)
    | SOME text => (print ("UNEXPECTED SOME \"" ^ String.toString text ^ "\"\n"); OS.Process.failure)
end
