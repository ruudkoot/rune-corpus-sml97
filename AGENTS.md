# Repository instructions

## Keep the user manual current

`README.md` is both the GitHub landing page and the user manual for the
implemented system. Update it
in the same change as any change to commands, arguments, defaults, environment
settings, concepts, artifact selection, result interpretation, supported
workflows or documented limitations. Do not defer this to a later documentation
milestone.

Keep its progression: concepts, command operations, then complete workflows.
Check command examples against the current dispatcher, launchers and adapters.
Distinguish implemented behavior from planned work and validated configurations
from experimental recipes. Keep the brief project introduction and quick start
before the detailed manual. Update `bin/corpus --help` when the same interface
change affects it. Put transient build progress and chronological run history
in `docs/implementation.md`. Keep `RESULTS.md` as the curated, dated acceptance
snapshot, with exact evidence IDs, benchmark limitations, manual reruns and
remaining work. When accepted results supersede it, update its date, tables and
interpretation together; check its rerun commands after interface changes.
Update the manual's support summary when
a capability becomes validated or its limitation changes.

For implementation changes, include this documentation check in completion:
either update the affected manual sections or establish that user-visible
behavior is unchanged. Do not add tests that merely duplicate documentation.

## Repository boundary

Normal corpus work stays in this repository. Preserve a reproducer and obtain
human confirmation before editing `../rune`, as required by `ROADMAP.md`.
