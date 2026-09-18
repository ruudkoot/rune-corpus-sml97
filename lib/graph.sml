signature CORPUS_GRAPH =
sig
  type node = {id : string, dependencies : string list, fields : Record.t}
  val order : node list -> node list
end

structure Graph :> CORPUS_GRAPH =
struct
  type node = {id : string, dependencies : string list, fields : Record.t}
  fun order nodes =
    let
      fun known id = List.exists (fn ({id = candidate, ...} : node) => id = candidate) nodes
      fun validate ([], _) = ()
        | validate (({id, dependencies, ...} : node) :: rest, seen) =
            if List.exists (fn previous => previous = id) seen then raise Fail ("duplicate graph node: " ^ id)
            else (List.app (fn dependency => if known dependency then ()
                  else raise Fail ("missing graph dependency: " ^ dependency)) dependencies;
                  validate (rest, id :: seen))
      val () = validate (nodes, [])
      fun loop ([], _, result) = List.rev result
        | loop (pending, done, result) =
          let fun ready ({dependencies, ...} : node) =
                List.all (fn dependency => List.exists (fn id => id = dependency) done) dependencies
          in case List.find ready pending of
            NONE => raise Fail "dependency graph contains a cycle"
          | SOME (node as {id, ...}) =>
              loop (List.filter (fn ({id = other, ...} : node) => id <> other) pending,
                    id :: done, node :: result)
          end
    in loop (nodes, [], []) end
end
