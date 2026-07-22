# MCP server: use and release

The MCP server serves the fossui manifest over the Model Context Protocol so an
AI assistant can look up the real API instead of guessing it. It runs as a
Cloudflare Worker at `https://mcp.fossui.org`.

## Use it

Point any MCP client at the endpoint.

Claude Code:

```
claude mcp add --transport http fossui https://mcp.fossui.org
```

Anything else that speaks Streamable HTTP: add a server with URL
`https://mcp.fossui.org`.

Once connected, the assistant has seven tools:

- `list_components` lists every component with its category, summary, and tags.
  Call this first.
- `get_component` returns the full API for one component: constructors, params,
  enums, companions, launcher functions, examples, and the curated `whenToUse`,
  conventions, and `commonMistakes`. Companion and enum names route to their
  owning component.
- `search` ranks components and token families by keyword across names,
  summaries, tags, and `whenToUse`.
- `get_theme_tokens` returns the token families (colors, radii, spacing,
  typography, shadows, motion). Omit the family for all of them.
- `get_package` returns the identity for pulling the package: name, version,
  pub.dev url, homepage, the `flutter pub add` command, the pubspec line, and the
  import.
- `get_setup` returns the once-per-project wiring for a `material`, `cupertino`,
  or `widgets` app.
- `build_custom_component` returns the recipe for building your own widget that
  matches the library: the `context.fossTheme` access pattern, the customization
  layers, and a worked token-only example.

There is also a resource, `fossui://llms.txt`, a flat overview for clients that
prefer reading the whole thing over calling tools.

Both the bare root `https://mcp.fossui.org` and `https://mcp.fossui.org/mcp`
accept MCP connections, so either URL works. A plain `GET /` is the exception: it
returns the health string `fossui mcp server`, so `curl https://mcp.fossui.org/`
is still the health check. The bare root is the documented endpoint; `/mcp` stays
as a fallback.

## What gets served

The content is baked into the Worker bundle at deploy time. The generator reads
the package and writes `generator/build/registry.json`; the Worker imports that
file and slices it across the seven tools. So a content change (a new package
release) is a regenerate plus redeploy, not a live edit. The served
`meta.version` is whatever package version the last deploy bundled.

## Release with a tag

Pushing a `v*` tag to this repo deploys. The `deploy` workflow
(`.github/workflows/deploy.yml`) checks out the package, regenerates the
manifest, and redeploys the Worker, then smoke-tests the live URL.

```
git tag v0.1.0
git push origin v0.1.0
```

The workflow, in order:

1. checks out this repo and `fossui/fossui` (the package, at `main`),
2. resolves the package with Flutter and runs the generator against it,
3. installs the server deps and runs `wrangler deploy`,
4. waits, then runs the smoke client against `https://mcp.fossui.org/mcp`.

Tag when the package release you want reflected is on the package's `main`, so
the regenerated manifest matches the published API. You can also run the
workflow by hand from the Actions tab (`workflow_dispatch`) without a tag.

### One-time setup

The deploy step needs two repo secrets (Settings, Secrets and variables,
Actions):

- `CLOUDFLARE_API_TOKEN`: a token scoped to Workers Scripts Edit on the account.
  Create it at Cloudflare, My Profile, API Tokens, with the Edit Cloudflare
  Workers template.
- `CLOUDFLARE_ACCOUNT_ID`: the account id (`wrangler whoami` prints it).

## Deploy by hand

Same two steps the workflow runs, from a checkout with the package beside this
repo:

```
cd generator && dart run bin/generate.dart /path/to/foss_ui_package
cd ../server && npx wrangler deploy
```

The first deploy of the Worker also provisions the `mcp.fossui.org` custom
domain and the Durable Object namespace McpAgent uses. Later deploys reuse them.

## Roll back

```
cd server
npx wrangler deployments list
npx wrangler rollback [version-id]
```

The server is stateless, so a rollback is only swapping the Worker version. A bad
manifest is undone by rolling back or by regenerating and redeploying.
