(* The upstream shell launcher ignores a false CMB.make result. *)
val () = OS.Process.exit
  (if CMB.make () then OS.Process.success else OS.Process.failure);
