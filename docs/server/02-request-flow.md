# Request flow

How a call reaches a tool. The code is `server/src/index.ts`.

## The path

```
agent (MCP client)
   │  JSON-RPC over Streamable HTTP
   ▼
Worker fetch(request)
   │  route on pathname
   ├─ POST /mcp  ──►  buildServer() + OneShotTransport  ──►  tool handler
   ├─ GET/DELETE /mcp  ──►  405 (no stream to open, no session to end)
   └─ else  ──►  200 "fossui mcp server"   (health text)
   │
   ▼
tool handler reads the in-memory manifest, returns a JSON slice
```

A POST carries exactly one JSON-RPC message. `OneShotTransport` hands it to a
fresh `McpServer` and resolves with whatever the server sends back, so the reply
is a plain JSON response. A notification carries no id, expects nothing back, and
returns 202.

Nothing is shared between requests, so the server needs no session and no
Durable Object. That also means there is no server-initiated stream: a `GET /mcp`
gets 405, which the spec allows and clients handle by not opening one.

## Load time

The manifest is `import`ed, so it is parsed once when the isolate starts, not per
request. On load the server asserts every component still has a `name`, `summary`,
and `tags` array, and throws if not. A manifest that drifted out of shape fails
loudly at startup, not deep inside a handler.

## What the client sees

Each tool returns MCP `content` with one `text` block of pretty-printed JSON. A
miss on `get_component` sets `isError: true` and still returns a JSON body with
`didYouMean`, so the agent can recover in one step.
