structure GraphTests =
struct
  fun node id dependencies : Graph.node = {id = id, dependencies = dependencies, fields = []}
  val nodes = [node "run" ["runtime", "bytecode"], node "bytecode" ["generator"],
               node "runtime" ["compiler"], node "generator" ["compiler"], node "compiler" []]
  val ordered = Graph.order nodes
  fun index id =
    let fun find (_, []) = raise Fail "node disappeared"
          | find (i, ({id = candidate, ...} : Graph.node) :: rest) =
              if id = candidate then i else find (i + 1, rest)
    in find (0, ordered) end
  val () = CoreTests.assert ("graph keeps independent builders and shared compiler",
    length ordered = 5 andalso index "compiler" < index "generator" andalso
    index "compiler" < index "runtime" andalso index "generator" < index "bytecode" andalso
    index "runtime" < index "run" andalso index "bytecode" < index "run")
  val () = CoreTests.assert ("graph rejects cycles",
    ((Graph.order [node "a" ["b"], node "b" ["a"]]; false) handle Fail _ => true))
  val () = CoreTests.assert ("graph rejects missing inputs",
    ((Graph.order [node "a" ["missing"]]; false) handle Fail _ => true))
  val () = CoreTests.assert ("graph rejects conflicting identities",
    ((Graph.order [node "a" [], node "a" []]; false) handle Fail _ => true))
end
