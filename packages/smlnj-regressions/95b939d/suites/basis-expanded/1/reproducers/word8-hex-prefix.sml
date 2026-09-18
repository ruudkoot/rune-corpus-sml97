structure Program =
struct
  fun check name parse =
    case parse "0w21" of
      SOME 0w0 => (print (name ^ ": SOME 0\n"); true)
    | SOME value => (print (name ^ ": UNEXPECTED SOME " ^ Word8.toString value ^ "\n"); false)
    | NONE => (print (name ^ ": UNEXPECTED NONE\n"); false)
  fun main _ =
    let val from = check "fromString" Word8.fromString
        val scan = check "scan HEX" (StringCvt.scanString (Word8.scan StringCvt.HEX))
    in if from andalso scan then OS.Process.success else OS.Process.failure end
end
