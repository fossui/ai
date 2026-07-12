# Design decisions

Why the generator is built the way it is. The mechanics are in
[pipeline.md](02-pipeline.md).

## Analyzer, not `dart doc` JSON

Two hard requirements settle it: exact const token values (the analyzer evaluates
constants cleanly) and full parameter fidelity (type, required, default). Macro
expansion is a small string pass either way, so one toolchain wins. `dart doc`
output is HTML-first and would add a second, coarser model to reconcile for no
gain.

## Extract URLs, do not derive them

The doc-site links already live in the dartdoc. Reading them is faithful to the
frozen asset paths and drops the whole slug-exception problem. Deriving them from
the component name would break on compound names (`FossAlertDialog`) and would
invent paths for secondary widgets that have no preview.

## Generated versus curated is a hard line

Stages 1 through 8 are pure extraction, no judgment. Stage 9 is the only place a
human-written value enters. That is why the manifest cannot silently drift:
everything mechanical is regenerated on every run, everything subjective lives in
a sidecar and is reviewed like code.

## The server is dumb on purpose

All the intelligence is compiled into the manifest at build time, so the server
is a cache-and-serve reader with no package dependency, no analyzer, and no Dart
parsing. Its quality equals the manifest's quality. Fixing what an agent knows
means regenerating the manifest, never editing the server.
