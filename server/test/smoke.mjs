// End-to-end check of the MCP server over Streamable HTTP: every tool, the
// resource, and the branches the happy path misses. Run against `wrangler dev`:
// node test/smoke.mjs [url]

import assert from "node:assert";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const url = new URL(process.argv[2] ?? "http://localhost:8787/mcp");
const client = new Client({ name: "smoke", version: "0.0.0" });
await client.connect(new StreamableHTTPClientTransport(url));

const call = async (name, args = {}) => {
  const res = await client.callTool({ name, arguments: args });
  return JSON.parse(res.content[0].text);
};

// --- tools present ---
const { tools } = await client.listTools();
console.log("tools:", tools.map((t) => t.name).join(", "));
assert.equal(tools.length, 5, "expected 5 tools");

// --- list_components: shape ---
const list = await call("list_components");
assert.equal(list.length, 25);
for (const c of list) {
  assert.ok(c.name && c.category && c.summary && Array.isArray(c.tags), `bad row ${c.name}`);
}
console.log("list_components:", list.length, "components, all rows well-formed");

// --- get_component: full record + case-insensitive ---
const button = await call("get_component", { name: "fossbutton" });
assert.equal(button.name, "FossButton");
for (const field of ["constructors", "enums", "companions", "examples", "urls", "conventions", "commonMistakes", "tags", "whenToUse"]) {
  assert.ok(button[field] !== undefined, `FossButton missing ${field}`);
}
console.log("get_component(fossbutton): full record, all", 9, "field groups present");

// --- get_component: miss fuzzy-matches, does not dump the catalog ---
const missRes = await client.callTool({ name: "get_component", arguments: { name: "Slidr" } });
assert.equal(missRes.isError, true, "miss should set isError");
const miss = JSON.parse(missRes.content[0].text);
assert.ok(miss.didYouMean.includes("FossSlider"), "Slidr should fuzzy-match FossSlider");
assert.ok(miss.didYouMean.length < 25, "should not dump the whole catalog");
console.log("get_component(Slidr): isError, didYouMean =", miss.didYouMean.join(", "));

// --- empty inputs are rejected by the schema, not treated as match-all ---
for (const [tool, args] of [["search", { query: "" }], ["get_component", { name: "" }]]) {
  const res = await client.callTool({ name: tool, arguments: args });
  assert.equal(res.isError, true, `${tool} should reject empty input`);
}
console.log("empty query/name: rejected by schema");

// --- search: ranking, no-match, name beats summary ---
const byName = await call("search", { query: "button" });
assert.equal(byName.components[0]?.name, "FossButton", "name match should rank first");
console.log("search(button): top =", byName.components[0].name);

const none = await call("search", { query: "zzzznope" });
assert.deepEqual(none.components, []);
assert.deepEqual(none.tokenFamilies, []);
console.log("search(zzzznope): empty, no crash");

const tokenHit = await call("search", { query: "color" });
assert.ok(tokenHit.tokenFamilies.includes("colors"), "should surface the colors family");
console.log("search(color): tokenFamilies =", tokenHit.tokenFamilies.join(", "));

// --- get_theme_tokens: all vs one ---
const all = await call("get_theme_tokens");
for (const fam of ["colors", "radii", "spacing", "typography", "shadows", "motion"]) {
  assert.ok(all[fam] !== undefined, `all tokens missing ${fam}`);
}
console.log("get_theme_tokens(): all 6 families");

const radii = await call("get_theme_tokens", { family: "radii" });
assert.equal(radii.radii.md, 8);
assert.equal(radii.access, "context.fossTheme");
console.log("get_theme_tokens(radii): md=8, access present");

// --- get_setup: every app_type branch ---
const material = await call("get_setup", { app_type: "material" });
assert.ok(material.wiring.includes("MaterialApp"));
const cupertino = await call("get_setup", { app_type: "cupertino" });
assert.ok(cupertino.wiring.includes("FossTheme(") && !cupertino.wiring.includes("MaterialApp"));
const widgets = await call("get_setup", { app_type: "widgets" });
assert.ok(widgets.wiring.includes("FossTheme("));
const dflt = await call("get_setup");
assert.ok(dflt.wiring.includes("MaterialApp"), "no app_type defaults to material");
console.log("get_setup: material=MaterialApp, cupertino/widgets=FossTheme, default=material");

// --- resource ---
const { resources } = await client.listResources();
assert.ok(resources.some((r) => r.uri === "fossui://llms.txt"));
const doc = await client.readResource({ uri: "fossui://llms.txt" });
assert.ok(doc.contents[0].text.includes("FossButton"));
console.log("resource fossui://llms.txt:", doc.contents[0].text.length, "chars, has FossButton");

console.log("\nall checks passed");
await client.close();
