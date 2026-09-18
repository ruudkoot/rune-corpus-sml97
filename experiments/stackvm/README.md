# Independent program and runtime builders

This owned fixture validates the experiment model. It is a small stack-machine
workload, not a claim about the performance of full SML applications.

`codegen.sml` emits a versioned instruction stream for the sum of squares from
1 through N. `runtime.sml` interprets it using arbitrary-precision integers.
The generator and interpreter expose the same portable `Program.main` interface
and can be built by independent compiler selections. The mathematical oracle is
N × (N+1) × (2N+1) / 6, multiplied by the requested workload repetitions.

The fixture is intentionally separate from Rune's bytecode format. This corpus
uses the installed Rune and does not build or manage Rune runtime versions.
Different SML compilers produce incompatible native/heap formats; the shared
stack-machine format makes independent generator/runtime choices meaningful.
The benchmark planner must reject incompatible formats, record both builders,
check correctness before timing, and retain every individual sample.

The experimental `bench` adapter now implements planning and measurement for
this format. `demo.record` selects two generator builders, two interpreter
builders and two sizes, with one warmup and five samples per valid configuration.
Copy `bindings.example.record` locally and replace the two reference artifact
paths with validated stage-2 artifacts; keep Rune as `installed-rune`.

```sh
bin/corpus bench --dry-run experiments/stackvm/demo.record _work/my-bindings.record
bin/corpus bench experiments/stackvm/demo.record _work/my-bindings.record
```

Source paths resolve relative to the experiment file, compiler paths relative
to the bindings file. Use absolute artifact paths for convenient local bindings.
Builds are shared by recorded input identity only within an experiment and are
fresh across experiments. Missing/incompatible bindings are explicit exclusions.
The runner records whole-command runtime samples, including startup and parsing,
and separate fresh compiler-command wall observations. Correctness precedes
comparisons, and any failing sample invalidates its configuration.

The first eight-configuration run passed. Its short samples established the
workflow rather than a performance claim; the demo now uses 5000 iterations
per invocation to improve timing resolution. A binding can declare an optional
`ALIAS.arguments` list for Rune/MLton compiler options, allowing the same compiler
artifact to be selected under distinct flag choices. Those arguments enter
build identity; other builders reject nonempty argument lists explicitly.

See [the manual](../../README.md) for
measurement boundaries, limits, records, reruns and current restrictions.

The longer profile also passed all eight configurations, with 40 measured
samples plus eight correctness checks and eight warmups. Both generator
builders produced identical bytecode for each size. Samples ranged from
0.15 to 5.6 seconds across sizes and configurations, with substantial variation
within some configurations; they do not support a reliable compiler ranking.
Wrong-output and timeout fixtures were rejected before measured samples, and
a missing binding remained explicitly unsupported. Exact evidence and recorded
whole-profile costs are in the implementation notes.
