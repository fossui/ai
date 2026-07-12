// The fossui MCP server: serves the generated manifest over Streamable HTTP.
// Five read-only tools, each a slice of registry.json. The server holds no state;
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
  meta: { version: string };
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

const json = (data: unknown) => ({
  content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }],
});

const find = (name: string) =>
  manifest.components.find((c) => c.name.toLowerCase() === name.toLowerCase());

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
          "Full API for one component: constructors, params, enums, companions, examples, urls, and the curated whenToUse, conventions, and commonMistakes.",
        inputSchema: {
          name: z.string().min(1).describe("Component name, e.g. FossButton"),
        },
      },
      async ({ name }) => {
        const found = find(name);
        if (found) return json(found);
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
          "Keyword search across component names, summaries, tags, and whenToUse, plus token family names. Returns ranked matches.",
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
        const tokenFamilies = Object.keys(manifest.tokens).filter(
          (f) => f !== "access" && f.includes(q),
        );
        return json({ components, tokenFamilies });
      },
    );

    this.server.registerTool(
      "get_theme_tokens",
      {
        description:
          "The theme token families (colors, radii, spacing, typography, shadows, motion), read via context.fossTheme. Omit family to get all.",
        inputSchema: {
          family: z
            .enum(["colors", "radii", "spacing", "typography", "shadows", "motion"])
            .optional(),
        },
      },
      async ({ family }) => {
        if (!family) return json(manifest.tokens);
        return json({ access: manifest.tokens.access, [family]: manifest.tokens[family] });
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
  }
}

export default {
  fetch(request: Request, env: Env, ctx: ExecutionContext): Response | Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/mcp") {
      return FossuiMcp.serve("/mcp", { binding: "FossuiMcp" }).fetch(request, env, ctx);
    }
    return new Response("fossui mcp server", { status: 200 });
  },
};
