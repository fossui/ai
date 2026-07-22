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
assert.equal(tools.length, 7, "expected 7 tools");

// --- list_components: shape ---
const list = await call("list_components");
assert.ok(list.length > 0, "no components");
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

// --- companions carry the constructors an agent must call, not just prose ---
const radio = await call("get_component", { name: "FossRadio" });
const group = radio.companions.find((c) => c.name === "FossRadioGroup");
assert.ok(group?.constructors?.[0], "FossRadioGroup should carry a constructor");
const groupParams = group.constructors[0].params.map((p) => p.name);
assert.ok(groupParams.includes("groupValue") && groupParams.includes("children"),
  "FossRadioGroup constructor should expose groupValue and children");
console.log("get_component(FossRadio): FossRadioGroup params =", groupParams.join(", "));

// --- get_component resolves a companion by name to its owner + full record ---
const rg = await call("get_component", { name: "FossRadioGroup" });
assert.equal(rg.component, "FossRadio", "companion should name its owner");
assert.ok(rg.constructors?.[0]?.params.some((p) => p.name === "groupValue"),
  "companion lookup should carry its constructor params");
const bv = await call("get_component", { name: "FossButtonVariant" });
assert.equal(bv.component, "FossButton", "enum should route to its owner");
assert.ok(Array.isArray(bv.values), "enum lookup should carry its values");
console.log("get_component(FossRadioGroup/FossButtonVariant): routed to owner with full record");

// --- overlay launcher functions are documented on their component and routable ---
const dialog = await call("get_component", { name: "FossDialog" });
const launcher = (dialog.functions ?? []).find((f) => f.name === "showFossDialog");
assert.ok(launcher?.params.some((p) => p.name === "context"), "FossDialog should carry showFossDialog");
const byFn = await call("get_component", { name: "showFossDialog" });
assert.equal(byFn.component, "FossDialog", "a launcher name should route to its component");
console.log("get_component(showFossDialog): routed to FossDialog with params");

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
assert.deepEqual(none.related, []);
console.log("search(zzzznope): empty, no crash");

// a companion name surfaces, routed to its owner, even though it is not top-level
const rel = await call("search", { query: "radiogroup" });
const radioRel = rel.related.find((r) => r.name === "FossRadioGroup");
assert.ok(radioRel && radioRel.component === "FossRadio", "RadioGroup should route to FossRadio");
console.log("search(radiogroup): related ->", radioRel.name, "owned by", radioRel.component);

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
assert.equal(radii.type, "double", "radii family should report its Dart type");
assert.equal(radii.unit, "logical pixels", "radii family should report its unit");
console.log("get_theme_tokens(radii): md=8, type=double, unit=logical pixels");

const typo = await call("get_theme_tokens", { family: "typography" });
assert.equal(typo.type, "TextStyle", "typography should resolve to TextStyle");
console.log("get_theme_tokens(typography): type =", typo.type);

// --- single-token lookup: type + unit + value for one token ---
const one = await call("get_theme_tokens", { family: "radii", token: "md" });
assert.equal(one.value, 8, "radii.md value is 8");
assert.equal(one.type, "double");
assert.equal(one.unit, "logical pixels");
console.log("get_theme_tokens(radii, md): value=8, type=double, unit present");

const color = await call("get_theme_tokens", { family: "colors", token: "primary" });
assert.ok(color.value.light && color.value.dark, "a color role resolves to light + dark");
console.log("get_theme_tokens(colors, primary): light + dark present");

const motionTok = await call("get_theme_tokens", { family: "motion", token: "toast" });
assert.equal(motionTok.unit, "milliseconds", "motion values are milliseconds");
console.log("get_theme_tokens(motion, toast):", motionTok.value, motionTok.unit);

// token without family is rejected; an unknown token suggests the real ones
const noFam = await client.callTool({ name: "get_theme_tokens", arguments: { token: "md" } });
assert.equal(noFam.isError, true, "token without family should error");
const badTok = await client.callTool({ name: "get_theme_tokens", arguments: { family: "radii", token: "huge" } });
assert.equal(badTok.isError, true, "unknown token should error");
assert.ok(JSON.parse(badTok.content[0].text).didYouMean.includes("md"), "should suggest real tokens");
console.log("get_theme_tokens: token needs family; unknown token -> didYouMean");

// --- token search matches on synonyms, not just the family key ---
const radiusHit = await call("search", { query: "radius" });
assert.ok(radiusHit.tokenFamilies.includes("radii"), "'radius' should find radii");
const fontHit = await call("search", { query: "font" });
assert.ok(fontHit.tokenFamilies.includes("typography"), "'font' should find typography");
console.log("search(radius/font): tokenFamilies resolve via synonyms");

// --- get_package: identity an agent needs to pull the package ---
const pkg = await call("get_package");
assert.equal(pkg.name, "fossui");
assert.equal(pkg.install, "flutter pub add fossui");
assert.equal(pkg.pubDev, "https://pub.dev/packages/fossui");
assert.ok(pkg.version && pkg.pubspec.includes(pkg.version), "pubspec should carry the version");
assert.ok(pkg.import.startsWith("package:fossui/"), "import should be the package uri");
console.log("get_package:", pkg.name, pkg.version, "install =", pkg.install);

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

// --- build_custom_component: composition guidance + worked example ---
const guide = await call("build_custom_component");
assert.ok(guide.access.includes("context.fossTheme"), "guide should name the accessor");
assert.equal(guide.layers.length, 3, "three customization layers");
assert.ok(guide.example.includes("context.fossTheme") && guide.example.includes("t.radii.lg"),
  "example should read tokens, not hardcode values");
assert.ok(guide.tokens.includes("get_theme_tokens"), "guide should point at get_theme_tokens");
console.log("build_custom_component: access + 3 layers + token example");

// --- resource ---
const { resources } = await client.listResources();
assert.ok(resources.some((r) => r.uri === "fossui://llms.txt"));
const doc = await client.readResource({ uri: "fossui://llms.txt" });
assert.ok(doc.contents[0].text.includes("FossButton"));
console.log("resource fossui://llms.txt:", doc.contents[0].text.length, "chars, has FossButton");

// --- the bare root speaks MCP too, so a client that drops /mcp still connects ---
// Edge propagation can lag a fresh deploy at the root path, so retry a few times
// before asserting rather than racing the very first request.
const rootUrl = new URL("/", url);
let rootTools;
for (let attempt = 1; attempt <= 5; attempt += 1) {
  const rootClient = new Client({ name: "smoke-root", version: "0.0.0" });
  await rootClient.connect(new StreamableHTTPClientTransport(rootUrl));
  rootTools = await rootClient.listTools();
  await rootClient.close();
  if (rootTools.tools.length === 7) break;
  if (attempt < 5) await new Promise((resolve) => setTimeout(resolve, 3000));
}
assert.equal(rootTools.tools.length, 7, "root endpoint should expose the same tools");
console.log("root endpoint:", rootUrl.href, "->", rootTools.tools.length, "tools");

console.log("\nall checks passed");
await client.close();
