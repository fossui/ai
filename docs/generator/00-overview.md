# The generator

The generator reads the `fossui` Flutter package and emits `registry.json`, the
single manifest the MCP server serves. It is the whole knowledge layer of the
system: the server is a thin reader over its output and holds no understanding of
its own. Get the generator right and the server is trivial.

It lives in `mcp/generator/`, is written in Dart, and uses `package:analyzer`
(the same engine `dart analyze` runs on) so it sees the package exactly as the
compiler does.

## Where it sits

Two programs meet at one file and nowhere else.

```
BUILD TIME (run per release)
   foss_ui_package/  ┐
                     ├──►  generator (Dart)  ──►  registry.json + llms.txt
   meta/*.yaml       ┘

RUNTIME (per agent query)
   agent  ──►  TS Worker  ──►  reads registry.json  ──►  serves a slice  ──►  agent
```

The generator is the only thing that reads Dart. The server never parses source,
never depends on the package, never runs the analyzer. Everything the server can
answer is baked into `registry.json` ahead of time. To fix or extend what an
agent knows, you change the generator or a sidecar and regenerate; you never
touch the server.

## Read next

- [data-model.md](01-data-model.md): the inputs it reads and the exact shape of what
  it produces (the component record and the token layer).
- [pipeline.md](02-pipeline.md): the ten stages that turn the package into the
  manifest, each mapped to the code.
- [design-decisions.md](03-design-decisions.md): why it is built this way (analyzer
  over `dart doc`, extracted URLs, the generated-versus-curated line).
- [running.md](04-running.md): how to run it, what the tests assert, and how to
  extend it.
