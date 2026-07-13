# fossui/rules

A ready-to-paste rules snippet for coding agents, so a project that uses `fossui`
gets the library's idioms without the MCP.

`fossui.md` is the snippet: the rules that keep AI-written fossui code compiling
and idiomatic (enum-not-string variants, no per-instance props, the group and
launcher APIs, how tokens resolve). `reference.md` beside it is the full component
catalog, generated from the manifest and committed, so the pair is self-contained
and works with no MCP server.

Drop `fossui.md` into your project's `CLAUDE.md`, `AGENTS.md`, or `.cursorrules`,
and keep `reference.md` in the repo for the exact per-component API. Both are
generated from the same source of truth as the MCP server, so all three agree.
Do not hand-edit `reference.md`; regenerate it with the generator.
