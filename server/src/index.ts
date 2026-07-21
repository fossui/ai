// The fossui MCP server: serves the generated manifest over Streamable HTTP.
// Seven read-only tools, each a slice of registry.json. The server holds no state;
// McpAgent handles the Workers fetch and transport.

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { McpAgent } from "agents/mcp";
import { z } from "zod";

import registry from "../../generator/build/registry.json";
import llmsTxt from "../../generator/build/llms.txt";

interface Component {
  name: string;
  category: string;
  summary: string;
  tags?: string[];
  whenToUse?: string;
  [key: string]: unknown;
}

interface Env {
  FossuiMcp: DurableObjectNamespace;
}

const manifest = registry as {
  meta: { package: string; version: string; import: string; homepage: string };
  components: Component[];
  tokens: Record<string, unknown>;
  setup: Record<string, string>;
};

// Fail loudly on manifest drift (a component missing a field the tools read)
// rather than throwing deep inside a request handler.
for (const c of manifest.components) {
  if (typeof c.name !== "string" || typeof c.summary !== "string" || !Array.isArray(c.tags)) {
    throw new Error(`manifest drift: ${c.name ?? "a component"} is missing name, summary, or tags`);
  }
}

// Synonyms so a token search matches on intent, not just the family key:
// "radius" or "corner" finds radii, "font" or "text" finds typography.
const tokenAliases: Record<string, string[]> = {
  colors: ["color"],
  radii: ["radius", "corner", "rounded"],
  spacing: ["space", "gap", "padding", "margin"],
  typography: ["type", "font", "text"],
  shadows: ["shadow", "elevation"],
  motion: ["motion", "animation", "duration"],
};

// How to build a custom widget that matches the library: the access pattern,
// the customization layers, and a worked example. It teaches composition, not
// numbers; concrete values stay in get_theme_tokens so nothing drifts here.
const customComponentGuide = {
  access:
    "Read every token through context.fossTheme (a FossThemeData). It resolves the FossTheme InheritedWidget, then a FossThemeData registered in ThemeData.extensions, then the light default, so it works under MaterialApp, CupertinoApp, or a bare WidgetsApp.",
  layers: [
    "Global retheme: pass your own FossThemeData, or layer a FossThemeSpec over a base with FossThemeData.light.retheme(spec). This is the preferred path.",
    "Per-component style object (FossButtonStyle and the like): the one-off override for a single instance.",
    "No per-instance token props on constructors (no borderRadius:, color:, padding:). To change corners or color, change the theme.",
  ],
  example: [
    "Widget build(BuildContext context) {",
    "  final t = context.fossTheme;",
    "  return Container(",
    "    padding: t.spacing.all(4),",
    "    decoration: BoxDecoration(",
    "      color: t.colors.card,",
    "      borderRadius: BorderRadius.circular(t.radii.lg),",
    "      border: Border.all(color: t.colors.border),",
    "      boxShadow: t.shadows.sm,",
    "    ),",
    "    child: Text('Custom', style: t.typography.sm.medium),",
    "  );",
    "}",
  ].join("\n"),
  tokens:
    "Call get_theme_tokens for the concrete values of any family: colors, radii, spacing, typography, shadows, motion.",
  note: "Corners render as a superellipse (squircle) across the built-in components; the shape builder is not public, so BorderRadius.circular is close but not identical.",
};

const json = (data: unknown) => ({
  content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }],
});

const find = (name: string) =>
  manifest.components.find((c) => c.name.toLowerCase() === name.toLowerCase());

// A companion or enum lives on its owning component's record, not as a top-level
// entry, so an agent that asks for one by name (get_component("FossRadioGroup"))
// is routed to the owner instead of hitting a dead end.
const owned = new Map<string, { component: string; kind: string; record: unknown }>();
for (const c of manifest.components) {
  for (const comp of (c.companions ?? []) as Array<{ name: string; kind?: string }>) {
    owned.set(comp.name.toLowerCase(), { component: c.name, kind: comp.kind ?? "companion", record: comp });
  }
  for (const enumName of Object.keys((c.enums ?? {}) as Record<string, unknown>)) {
    owned.set(enumName.toLowerCase(), {
      component: c.name,
      kind: "enum",
      record: { name: enumName, values: (c.enums as Record<string, unknown>)[enumName] },
    });
  }
  for (const fn of (c.functions ?? []) as Array<{ name: string }>) {
    owned.set(fn.name.toLowerCase(), { component: c.name, kind: "function", record: fn });
  }
}

// Ordered-subsequence match: "slidr" matches "slider". Cheap fuzzy fallback for
// a name miss so we suggest the near thing instead of dumping the whole catalog.
const subsequence = (needle: string, hay: string) => {
  let i = 0;
  for (const ch of hay) if (i < needle.length && ch === needle[i]) i++;
  return i === needle.length;
};

export class FossuiMcp extends McpAgent {
  server = new McpServer({ name: "fossui", version: manifest.meta.version });

  async init() {
    // The flat overview, for clients that prefer reading the whole thing to
    // making tool calls.
    this.server.resource("llms.txt", "fossui://llms.txt", async (uri) => ({
      contents: [{ uri: uri.href, mimeType: "text/plain", text: llmsTxt }],
    }));

    this.server.registerTool(
      "list_components",
      {
        description:
          "List every fossui component with its category, one-line summary, and search tags. Call this first.",
      },
      async () =>
        json(
          manifest.components.map((c) => ({
            name: c.name,
            category: c.category,
            summary: c.summary,
            tags: c.tags ?? [],
          })),
        ),
    );

    this.server.registerTool(
      "get_component",
      {
        description:
          "Full API for one component: constructors, params, enums, companions, launcher functions (showFoss...), examples, urls, and the curated whenToUse, conventions, and commonMistakes.",
        inputSchema: {
          name: z.string().min(1).describe("Component name, e.g. FossButton"),
        },
      },
      async ({ name }) => {
        const found = find(name);
        if (found) return json(found);
        // A companion or enum: return its record and point at the owning component.
        const own = owned.get(name.toLowerCase());
        if (own)
          return json({
            name,
            kind: own.kind,
            component: own.component,
            note: `${name} belongs to ${own.component}. Call get_component("${own.component}") for the full picture.`,
            ...(own.record as Record<string, unknown>),
          });
        const q = name.toLowerCase();
        const contains = manifest.components.filter((c) => c.name.toLowerCase().includes(q));
        const near = (
          contains.length
            ? contains
            : manifest.components.filter((c) =>
                subsequence(q, c.name.toLowerCase().replace("foss", "")),
              )
        ).map((c) => c.name);
        return {
          ...json({
            error: `No component named ${name}. Call list_components to see them all.`,
            didYouMean: near,
          }),
          isError: true,
        };
      },
    );

    this.server.registerTool(
      "search",
      {
        description:
          "Keyword search across component names, summaries, tags, and whenToUse, the companion, enum, and launcher names they own, plus token family names. Returns ranked matches.",
        inputSchema: { query: z.string().min(1) },
      },
      async ({ query }) => {
        const q = query.toLowerCase();
        const components = manifest.components
          .map((c) => {
            let score = 0;
            if (c.name.toLowerCase().includes(q)) score += 3;
            if ((c.tags ?? []).some((t) => t.toLowerCase().includes(q))) score += 2;
            if (c.summary.toLowerCase().includes(q)) score += 1;
            if ((c.whenToUse ?? "").toLowerCase().includes(q)) score += 1;
            return { name: c.name, category: c.category, summary: c.summary, score };
          })
          .filter((x) => x.score > 0)
          .sort((a, b) => b.score - a.score);
        // Companions, enums, and launchers are not top-level, so a query like
        // "RadioGroup" would miss them. Surface each match routed to its owner.
        const related = [...owned.values()]
          .filter((o) => (o.record as { name?: string }).name?.toLowerCase().includes(q))
          .map((o) => ({ name: (o.record as { name?: string }).name, kind: o.kind, component: o.component }));
        const tokenFamilies = Object.keys(manifest.tokens)
          .filter((f) => f !== "access" && f !== "types" && f !== "units")
          .filter((f) => f.includes(q) || (tokenAliases[f] ?? []).some((a) => a.includes(q) || q.includes(a)));
        return json({ components, related, tokenFamilies });
      },
    );

    this.server.registerTool(
      "get_theme_tokens",
      {
        description:
          "The theme token families (colors, radii, spacing, typography, shadows, motion), read via context.fossTheme, each with its Dart type and unit. Omit family for all; pass token for one value, e.g. family 'radii' token 'md'.",
        inputSchema: {
          family: z
            .enum(["colors", "radii", "spacing", "typography", "shadows", "motion"])
            .optional(),
          token: z
            .string()
            .min(1)
            .optional()
            .describe("A single token in the family, e.g. 'md' for radii, 'primary' for colors. Requires family."),
        },
      },
      async ({ family, token }) => {
        const types = manifest.tokens.types as Record<string, string>;
        const units = manifest.tokens.units as Record<string, string>;
        if (token && !family) {
          return {
            ...json({ error: "token requires family. Pass family too, e.g. family 'radii' token 'md'." }),
            isError: true,
          };
        }
        if (!family) return json(manifest.tokens);
        const familyData = manifest.tokens[family] as Record<string, unknown>;
        if (token) {
          // colors nest under light/dark; a role resolves to both. Other
          // families are a flat step map.
          const light = family === "colors" ? (familyData.light as Record<string, unknown>) : familyData;
          if (!(token in light)) {
            return {
              ...json({
                error: `No token '${token}' in ${family}. Call get_theme_tokens with just family to see them.`,
                didYouMean: Object.keys(light),
              }),
              isError: true,
            };
          }
          const value =
            family === "colors"
              ? { light: light[token], dark: (familyData.dark as Record<string, unknown>)[token] }
              : familyData[token];
          return json({ access: manifest.tokens.access, family, token, type: types[family], unit: units[family], value });
        }
        return json({
          access: manifest.tokens.access,
          type: types[family],
          unit: units[family],
          [family]: familyData,
        });
      },
    );

    this.server.registerTool(
      "get_package",
      {
        description:
          "Package identity for pulling fossui into a project: name, version, pub.dev url, homepage, the install command, the pubspec dependency line, and the import. Call this to add the package; then get_setup for the theme wiring.",
      },
      async () => {
        const { package: name, version, import: importPath, homepage } = manifest.meta;
        return json({
          name,
          version,
          pubDev: `https://pub.dev/packages/${name}`,
          homepage,
          install: `flutter pub add ${name}`,
          pubspec: manifest.setup.pubspec,
          import: importPath,
          next: "Call get_setup for the theme wiring.",
        });
      },
    );

    this.server.registerTool(
      "get_setup",
      {
        description:
          "Once-per-project wiring: add the dependency and register the theme. Pass app_type for the matching wiring.",
        inputSchema: {
          app_type: z.enum(["material", "cupertino", "widgets"]).optional(),
        },
      },
      async ({ app_type }) => {
        const s = manifest.setup;
        // Cupertino and bare WidgetsApp use the nonMaterial FossTheme wrapper.
        const wiring = !app_type || app_type === "material" ? s.material : s.nonMaterial;
        return json({ pubspec: s.pubspec, wiring, access: s.access, note: s.note });
      },
    );

    this.server.registerTool(
      "build_custom_component",
      {
        description:
          "How to build your own widget that matches the fossui look and feel: the context.fossTheme access pattern, the customization layers, and a worked token-only example. Pair with get_theme_tokens for concrete values.",
      },
      async () => json(customComponentGuide),
    );
  }
}

export default {
  fetch(request: Request, env: Env, ctx: ExecutionContext): Response | Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/mcp") {
      return FossuiMcp.serve("/mcp", { binding: "FossuiMcp" }).fetch(request, env, ctx);
    }
    // Also accept MCP on the root, so a client that drops the /mcp path still
    // connects. A real MCP request is any non-GET method (POST messages, DELETE
    // teardown) or a GET that opens the SSE stream (Accept: text/event-stream);
    // a plain GET / stays the health string for browsers and the health check.
    if (url.pathname === "/") {
      const accept = request.headers.get("accept") ?? "";
      const wantsMcp = request.method !== "GET" || accept.includes("text/event-stream");
      if (wantsMcp) {
        return FossuiMcp.serve("/", { binding: "FossuiMcp" }).fetch(request, env, ctx);
      }
    }
    return new Response("fossui mcp server", { status: 200 });
  },
};
