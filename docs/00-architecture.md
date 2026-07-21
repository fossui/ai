# Architecture

What this repo is, how the parts fit, how data flows. Start here.

## What it does

Teaches any AI assistant the `fossui` API so AI-written fossui code compiles on
the first try. Everything is generated from one file, `registry.json`, so no two
delivery vehicles can disagree.

## The parts

```
generator/   Dart tool. Reads the package, writes registry.json + llms.txt + the references.
server/      MCP server (Cloudflare Worker). Serves registry.json over the protocol.
skill/       Claude Code skill. Hand-authored idioms + a generated reference.md.
rules/       CLAUDE.md / AGENTS.md paste-in snippet + a generated reference.md.
docs/        This guide (architecture) + generator and server internals.
```

The eval harness (measures whether the manifest helps) lives outside this repo,
at `foss_ui_docs/ai-eval/`.

## Build flow: one source of truth

```
        ┌──────────────────┐        ┌───────────────────────────┐
        │ foss_ui_package/ │        │   generator/meta/*.yaml    │
        │ (published lib,  │        │ curated notes: tags,       │
        │  read-only)      │        │ whenToUse, conventions,    │
        └────────┬─────────┘        │ commonMistakes             │
                 │ read public API  └─────────────┬─────────────┘
                 │                                 │
                 └──────────────┬──────────────────┘
                                ▼
                       ┌──────────────────┐
                       │    generator/    │
                       │      (Dart)      │
                       └────────┬─────────┘
                                │ emit
                                ▼
              ┌──────────────────────────────────┐
              │  generator/build/                 │
              │    registry.json   (structured)   │  <-- source of truth
              │    llms.txt        (flat overview)│
              └───────────────┬──────────────────┘
                              │ bundled into
                              ▼
                       ┌──────────────┐
                       │   server/    │  serves both over MCP
                       └──────────────┘

  skill/ and rules/ pair hand-authored idioms with a generated reference.md
  (the same llms.txt render), so each is self-contained and cannot drift.
```

Generated fields (constructors, params, enums, companions, functions, tokens)
cannot drift. Curated fields (tags, whenToUse, conventions, commonMistakes) come
from the `meta/` sidecars, reviewed like code. See `docs/generator/`.

## Runtime flow: an agent uses the server

```
   AI agent
      │
      │  one of seven tools over GET /mcp (Streamable HTTP)
      ▼
 ┌─────────────────────────────────────────────┐
 │  server  (Durable Object: FossuiMcp)         │
 │                                              │
 │   list_components   catalog                  │
 │   get_component     one component's full API │
 │   search            keyword -> matches       │
 │   get_theme_tokens  token values + Dart types│
 │   get_package       identity + install       │
 │   get_setup         theme wiring             │
 │   build_custom_component  matching widget    │
 │   resource: fossui://llms.txt                │
 └───────────────────────┬─────────────────────┘
                         │ returns a slice of
                         ▼
                 registry.json (bundled, in memory)
                         │
                         ▼
        agent writes fossui code that compiles
```

`get_component` also resolves a companion or enum name (`FossRadioGroup`,
`FossButtonVariant`) back to its owning component, so no lookup dead-ends.

## Data flow: one value, package to agent

```
FossButton constructor
   param `variant: FossButtonVariant`
        │  generator reads the type + dartdoc
        ▼
registry.json  components[].constructors[].params[]
        │  bundled at build
        ▼
server  get_component("FossButton")
        │  JSON over MCP
        ▼
agent   writes variant: FossButtonVariant.primary   (never the string 'primary')
```

## Commands

```
# generator (cd generator)
dart run bin/generate.dart     # write build/registry.json + build/llms.txt
dart test                      # regenerate, then assert invariants
dart analyze                   # lint

# server (cd server)
npx wrangler dev               # run locally on :8787, serves /mcp
node test/smoke.mjs            # end-to-end check against a running server
npx wrangler deploy            # ship (needs a Cloudflare account)
npx tsc --noEmit               # typecheck
```

## Delivery vehicles, when to use which

```
server/   live, exact, on-demand per-component API   -> best with an agent
skill/    idioms + bundled reference, self-contained -> Claude Code, no server needed
rules/    paste-in idioms + bundled reference        -> any agent, no server needed
llms.txt  flat whole-library overview                -> read-the-whole-thing clients
```

## Internals

- `docs/generator/` : how the package becomes the manifest.
- `docs/server/` : how the manifest is served over MCP.
