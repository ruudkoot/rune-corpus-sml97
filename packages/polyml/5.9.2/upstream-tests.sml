val () = use "Tests/RunTests.sml";
val () = if runTests "Tests" then (print "CORPUS_POLYML_UPSTREAM_PASS\n"; OS.Process.exit OS.Process.success) else OS.Process.exit OS.Process.failure;
