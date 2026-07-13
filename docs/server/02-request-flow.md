# Request flow

How a call reaches a tool. The code is `server/src/index.ts`.

## The path

```
agent (MCP client)
   │  JSON-RPC over Streamable HTTP
   ▼
Worker fetch(request, env, ctx)
   │  route on pathname
   ├─ /mcp  ──►  FossuiMcp.serve("/mcp")  ──►  McpAgent  ──►  tool handler
   └─ else  ──►  200 "fossui mcp server"   (health text)
   │
   ▼
tool handler reads the in-memory manifest, returns a JSON slice
```

`McpAgent` (from the `agents` SDK) owns the transport and the session; the
handler code only maps an input to a manifest slice. The session lives in a
Durable Object (`FossuiMcp`, SQLite-backed), so a multi-call MCP session keeps its
state on one instance.

## Load time

The manifest is `import`ed, so it is parsed once when the isolate starts, not per
request. On load the server asserts every component still has a `name`, `summary`,
and `tags` array, and throws if not. A manifest that drifted out of shape fails
loudly at startup, not deep inside a handler.

## What the client sees

Each tool returns MCP `content` with one `text` block of pretty-printed JSON. A
miss on `get_component` sets `isError: true` and still returns a JSON body with
`didYouMean`, so the agent can recover in one step.
