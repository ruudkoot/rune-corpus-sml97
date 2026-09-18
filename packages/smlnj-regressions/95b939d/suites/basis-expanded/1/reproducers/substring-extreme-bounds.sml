structure Program =
struct
  fun check name index =
    ((ignore (Substring.substring ("", index, index));
      print (name ^ ": UNEXPECTED success\n"); false)
     handle Subscript => (print (name ^ ": Subscript\n"); true)
          | e => (print (name ^ ": UNEXPECTED " ^ General.exnName e ^ "\n"); false))
  fun main _ =
    case (Int.minInt, Int.maxInt) of
      (SOME minimum, SOME maximum) =>
        let val upper = check "maximum" maximum
            val lower = check "minimum" minimum
        in if upper andalso lower then OS.Process.success else OS.Process.failure end
    | _ => (print "not applicable: unbounded Int\n"; OS.Process.success)
end
