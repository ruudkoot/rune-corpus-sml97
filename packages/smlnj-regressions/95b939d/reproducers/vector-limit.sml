(* Report whether maxLen + 1 is representable before invoking Vector.tabulate. *)
structure Program =
struct
  fun main (_, _) =
    (print ("Vector.maxLen=" ^ Int.toString Vector.maxLen ^ "\n");
     print ("Int.maxInt=" ^ (case Int.maxInt of NONE => "unbounded" | SOME n => Int.toString n) ^ "\n");
     ((print ("maxLen+1=" ^ Int.toString (Vector.maxLen + 1) ^ "\n"))
      handle Overflow => print "maxLen+1 raises Overflow before Vector.tabulate can be called\n");
     OS.Process.success)
end
