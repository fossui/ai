# fossui/ai

The AI delivery layer for [fossui](https://fossui.org): tooling that teaches any
AI assistant the fossui API, so AI-written fossui code compiles and follows the
library's idioms on the first try.

fossui ships as one pub package. The weak point is what happens after install: a
developer asks an AI assistant to build a screen with fossui, and the model
guesses the API. It invents props that do not exist, misses the enum-based
variants, or forgets to register the theme. This repo fixes that by giving agents
a current, structured, version-accurate description of the library.

## Use it

The server is live at `https://mcp.fossui.org`. Point any MCP client at it.

```
claude mcp add --transport http fossui https://mcp.fossui.org
```

See [docs/mcp-server.md](docs/mcp-server.md) for the tools it exposes and how a
tagged release redeploys it.

## How it works

Everything is generated from one source of truth. A Dart generator reads the
package and emits a single manifest, `registry.json`, that describes every
component, its exact API, the token system, and the idioms that matter. Every
delivery vehicle serves from that one manifest, so none of them can drift.

```
foss_ui_package/  ─►  generator  ─►  registry.json  ─►  server, llms.txt, skill
```

## What is here

```
generator/   Dart tool: reads the package, emits registry.json and llms.txt
docs/        architecture guide (start at docs/00-architecture.md)
server/      MCP server (Cloudflare Worker) serving registry.json over the protocol
skill/       Claude Code skill carrying the fossui idioms
rules/       a CLAUDE.md / AGENTS.md snippet to paste into a project
```

Every vehicle reads the one manifest, so none can drift.

## Generator

```
cd generator
dart run bin/generate.dart      # writes build/registry.json and build/llms.txt
dart test                       # regenerates, then asserts the invariants
```

The package location comes from the first argument, then the `FOSSUI_PACKAGE`
environment variable, then a default. See
[docs/generator](docs/generator/00-overview.md) for the full architecture.

## License

MIT. See [LICENSE](LICENSE).
