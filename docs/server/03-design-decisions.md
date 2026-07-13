# Design decisions

Why the server is built the way it is. The mechanics are in
[request-flow.md](02-request-flow.md).

## Bundle the manifest, do not fetch it

`registry.json` is imported into the Worker, not read from storage or a URL. It is
small, it changes only at release, and bundling makes every request a memory read
with no cold-fetch and no failure mode. Redeploy is the update mechanism.

## Stateless and read-only

Every tool is a pure function of the manifest. No writes, no user state, no
per-request package work. The Durable Object exists only because the MCP session
transport needs a home, not because the server keeps data.

## Fail loudly at load

The drift guard runs once at startup and throws on a malformed manifest. A bad
generate should break the deploy, not surface as a broken tool call to an agent
mid-session.

## A miss should teach, not dead-end

Two rules keep a wrong name useful. A companion, enum, or launcher name routes to
its owning component with the full record, because those are the classes an agent
actually has to construct. A genuine miss fuzzy-matches and returns `didYouMean`
rather than an error alone or the whole catalog.

## Search on intent, not just keys

Component search weighs name over tag over summary. Token families match on
synonyms (`radius` finds `radii`, `font` finds `typography`), because an agent
searches for the concept, not the field name.

## The server is dumb on purpose

All the knowledge is in the manifest. The server has no analyzer, no package
dependency, no Dart parsing; its quality equals the manifest's. To fix what an
agent knows, regenerate the manifest, never patch a handler. This is the same line
the generator draws from the other side (see `docs/generator/`).
