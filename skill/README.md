# fossui/skill

A Claude Code skill carrying the fossui idioms. It teaches an agent the library's
API rules and, when the fossui MCP server is connected, routes it to the tools for
exact, version-accurate API.

## Install

Copy the skill folder into your skills directory:

```
# per project
cp -r skill/fossui <your-project>/.claude/skills/fossui

# or for every project
cp -r skill/fossui ~/.claude/skills/fossui
```

The skill activates on any fossui work: a `Foss`-prefixed widget, `FossThemeData`,
`context.fossTheme`, or an import of `package:fossui/fossui.dart`.

## Relationship to the other vehicles

The skill, the `rules/` snippet, and the MCP server all carry the same guidance
from one source of truth. The skill is the richest for Claude Code, the rules
snippet is the always-on paste-in baseline, and the MCP server serves the exact
per-component API on demand. Use the skill with the server for the best result.
