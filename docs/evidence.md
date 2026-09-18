# Inspecting and retaining evidence

Initial development validation evidence is retained in `_work/initial-validation/`.
Those historical records keep their original working-directory paths; they are
not rewritten when the checkout or documentation changes. Later validation
attempts and their context are listed in [implementation notes](implementation.md).

`bin/corpus report` lists attempts; `bin/corpus report ATTEMPT_DIRECTORY` lists
unsuccessful or unfinished steps with their raw log directories. `logs PATH TEXT`
searches `.log` files line by line. `show RECORD` decodes a record for inspection.
Command plans retain pending, running, passed, failed and blocked states.

An interrupted harness cannot write a final verdict. A running attempt or step
is therefore incomplete; inspect its PID and logs before deciding it is stale.
The process supervisor bounds child lifetime after interruption. A retry creates
a fresh attempt and never resumes or overwrites the old source/build tree.

`bin/corpus export ATTEMPT_DIRECTORY NEW_ARCHIVE.tar.gz` exports a completed
attempt's records, complete raw step logs and rerun instructions. The destination
must not already exist. Nested semantic-suite records, logs and generated SML
reproducers are included. Other source/build trees, downloaded archives and compiler
installations are excluded; preserve these separately when they are needed for
offline reconstruction. Exports may contain local paths and declared environment
values. No automatic external upload is performed.

To rerun, restore the matching corpus sources, installed Rune and native tools
recorded in `system.record` and `selected-tools.record`. Use the recorded step
environment, then invoke the original phase with the saved `recipe.record` and
variant. The harness verifies the source digest again and creates a new attempt.
Compare `specification.record`; an equal ID is not proof of equal output. Native
headers, libraries and tools not yet identified are recorded as provenance gaps.

There is no automatic cleanup. Keep failed/interrupted logs until the diagnosis
and any reproducer have been recorded. Retain source archives and every compiler
artifact referenced by downstream results. Large unreferenced build/source trees
may be removed manually after their evidence is exported; doing so prevents
direct inspection and invalidates any artifact paths inside them. Retain the
small attempt, specification, result and raw-log records even after removing a
work tree. Do not delete a directory belonging to a live process.
