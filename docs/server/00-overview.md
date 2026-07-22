# The server

The server is a thin reader over `registry.json`. It serves the manifest to AI
agents over the Model Context Protocol, as five read-only tools and one resource.
It parses no Dart, depends on no package, and holds no state of its own: every
answer is a slice of the manifest bundled at build time.

It lives in `server/`, is written in TypeScript, and runs as a Cloudflare Worker.
The MCP plumbing (transport, session) is handled by `McpAgent` from the `agents`
SDK, backed by a Durable Object.

## Where it sits

```
BUILD TIME
   generator  ──►  registry.json + llms.txt   (committed under generator/build/)

BUILD/DEPLOY
   registry.json ┐
                 ├──►  bundled into the Worker (import, not fetch)
   llms.txt      ┘

RUNTIME (per agent query)
   agent  ──MCP──►  Worker /mcp  ──►  slice of the in-memory manifest  ──►  agent
```

The manifest is imported into the bundle, so a request touches memory, not the
filesystem or the network. To change what an agent gets, regenerate the manifest
and redeploy; you do not edit request handlers.

## Read next

- [tools.md](01-tools.md): the seven tools and the resource, with input and output
  shapes.
- [request-flow.md](02-request-flow.md): how a request reaches a tool (transport,
  `McpAgent`, the Durable Object, routing).
- [design-decisions.md](03-design-decisions.md): why it is built this way (stateless,
  bundled manifest, drift guard, name routing, synonym search).
- [running.md](04-running.md): run locally, smoke-test, deploy, and configure.
