structure Program =
struct
  datatype instruction = Push of IntInf.int | Dup | Mul | Add | Halt
  fun read path =
    let val input = TextIO.openIn path
        val contents = (TextIO.inputAll input before TextIO.closeIn input)
          handle e => (TextIO.closeIn input; raise e)
        fun parse [] = []
          | parse ("PUSH" :: n :: rest) =
              (case IntInf.fromString n of SOME i => Push i :: parse rest
               | NONE => raise Fail "invalid integer operand")
          | parse ("DUP" :: rest) = Dup :: parse rest
          | parse ("MUL" :: rest) = Mul :: parse rest
          | parse ("ADD" :: rest) = Add :: parse rest
          | parse ["HALT"] = [Halt]
          | parse _ = raise Fail "invalid instruction stream"
    in case String.tokens Char.isSpace contents of
      "CORPUS-STACK-1" :: words => Vector.fromList (parse words)
    | _ => raise Fail "unsupported bytecode format" end
  fun evaluate code =
    let fun loop (pc, stack) =
      case (Vector.sub (code, pc), stack) of
        (Push i, _) => loop (pc + 1, i :: stack)
      | (Dup, i :: rest) => loop (pc + 1, i :: i :: rest)
      | (Mul, a :: b :: rest) => loop (pc + 1, (a * b) :: rest)
      | (Add, a :: b :: rest) => loop (pc + 1, (a + b) :: rest)
      | (Halt, [result]) => if pc + 1 = Vector.length code then result
                           else raise Fail "trailing instructions"
      | _ => raise Fail "invalid stack state"
    in loop (0, []) end
  fun main (_, [path, repetitions]) =
        let val count = case Int.fromString repetitions of SOME n =>
              if n > 0 then n else raise Fail "repetitions must be positive"
              | NONE => raise Fail "invalid repetitions"
            val code = read path
            fun loop (0, total) = total
              | loop (n, total) = loop (n - 1, total + evaluate code)
            val result = loop (count, 0)
        in print ("CORPUS_STACK_RESULT " ^ IntInf.toString result ^ "\n"); OS.Process.success end
    | main _ = (TextIO.output (TextIO.stdErr, "usage: runtime BYTECODE REPETITIONS\n"); OS.Process.failure)
end
