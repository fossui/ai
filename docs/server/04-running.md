# Running, testing, and deploying

## Running locally

```
cd server
npx wrangler dev        # serves /mcp on http://localhost:8787
```

The manifest comes from `../generator/build/registry.json`, so regenerate it
first if the package changed. The root path returns a health string; the MCP
endpoint is `/mcp`.

## Testing

```
node test/smoke.mjs [url]     # default http://localhost:8787/mcp
```

`smoke.mjs` connects as a real MCP client and checks every tool, the resource,
and the branches the happy path misses: the fuzzy miss, empty-input rejection,
search ranking, companion and enum name routing, token types, and each
`get_setup` app_type. Run it against a live `wrangler dev`.

```
npx tsc --noEmit        # typecheck
```

## Deploying

```
npx wrangler deploy     # needs a Cloudflare account (wrangler login)
```

`wrangler.jsonc` declares the Durable Object binding (`FossuiMcp`), the SQLite
migration, `nodejs_compat`, and a Text rule so `llms.txt` imports as a string. It
carries no route or custom domain yet, so a deploy lands on the generated
`workers.dev` subdomain until one is added.

## Extending it

- **New tool**: register it in `FossuiMcp.init` with a Zod input schema, returning
  `json(...)` over a manifest slice. Add a check to `smoke.mjs`.
- **New manifest field**: it flows through automatically; a tool only needs a
  change if it should surface the field. Regenerate, then redeploy.
- **Never** add package parsing or per-request computation here. If a value is
  missing, add it to the generator, not the server.
