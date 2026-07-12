# The pipeline

`main()` in `bin/generate.dart` runs these stages in order. Each maps to a small
set of functions. For the shape of the output see
[data-model.md](01-data-model.md); for the rationale see
[design-decisions.md](03-design-decisions.md).

```
1. load      resolve the barrel lib/fossui.dart into an analyzed library
2. enumerate walk exportNamespace to the full public Foss* class/enum set
3. templates build the {@template name} -> body table across the whole API
4. classify  split into components, companions, and orphan items
5. extract   per component: constructors, params, enums, examples, companions
6. expand    substitute {@macro} in doc text from the template table
7. urls      pull the doc-site links straight from the dartdoc
8. tokens    const-evaluate the six families to plain values
9. merge     fold each component's sidecar into its record
10. emit      write registry.json, then render llms.txt from the same records
```

## 1-2. Load and enumerate

`AnalysisContextCollection` resolves the barrel `lib/fossui.dart`. Its
`exportNamespace.definedNames2` is the entire public surface as analyzer
elements. Filtering to names starting with `Foss` gives every public class and
enum in one pass, regardless of how the package splits files with `part` or
`export`.

## 3. Template table

Component previews and the shared customization note are dartdoc
`{@template name} ... {@endtemplate}` blocks, referenced elsewhere with
`{@macro name}`. The analyzer returns documentation comments with these markers
unexpanded, so the generator scans every class and enum comment once and builds a
`name -> body` map (`_templates`). Stage 6 uses it.

## 4. Classify

Three buckets, decided by name and category:

- **Components**: classes that carry a `{@category}` and whose name does not end
  in a companion suffix. The token and theme types (`FossColors`, `FossMotion`,
  `FossThemeData`, and the rest) carry no category, so they fall out here and are
  picked up by the tokens stage instead.
- **Companions**: classes whose name ends in `Style`, `Controller`, `Item`,
  `Scope`, `Entry`, or `Group`.
- **Orphan items**: classes with no companion suffix that are not components, but
  whose name a component extends. `FossTab` is the case: it is the item type for
  `FossTabs`, carries no suffix, and is shorter than `FossTabs`, so it is bound as
  an item companion by the name-extension rule rather than by suffix or prefix.

## 5. Extract

For each component (`_component`):

- **Constructors** (`_constructor`): the default constructor reports its analyzer
  name as `new`, normalized back to the class name; named constructors become
  `FossButton.icon`. The `key` parameter is dropped as noise. Each parameter
  carries name, type, a `required` flag, and its default expression verbatim.
- **Parameter docs** (`_paramDoc`): a `this.child` parameter has no doc of its
  own, so the generator reads the doc off the backing field.
- **Enums** (`_enumValues`): every value with its per-value dartdoc.
- **Ownership** (`ownsName`): a component claims the companions and enums its name
  prefixes, but only when no longer-named component also prefixes them, so
  `FossTabsVariant` binds to `FossTabs`, not `FossTab`.

## 6. Expand macros

`_expand` substitutes every `{@macro name}` with its template body from the
table, repeating a few times so a macro nested inside a template also resolves.
The result feeds summary and example extraction, so the manifest carries no raw
`{@macro}` or `{@template}` markers.

## 7. URLs

Rather than derive doc-site links from the component name (which breaks on
compound names and secondary widgets), `_urls` reads them straight out of the
expanded dartdoc: the `<img>` sources for the light and dark previews, the docs
link, and the playground link. This reproduces the frozen asset paths exactly and
naturally emits nothing for a component that embeds no preview.

## 8. Tokens

The const-evaluation pass (`_tokens`, `_instance`, `_tokenValue`) does the most
type-specific work. Each family exposes a canonical static-const instance
(`FossColors.light` and `.dark`, the rest `standard`). The generator evaluates it
with `computeConstantValue()` and maps each instance field to plain JSON by type:

- **Color** to `#AARRGGBB`. The current Flutter `Color` stores floating-point
  `a/r/g/b` channels in 0..1, so `_hex` rebuilds each byte as
  `round(channel * 255)`. Alpha is preserved, so alpha-composited roles keep their
  exact hex.
- **Duration** to integer milliseconds.
- **TextStyle** and **BoxShadow** to sub-objects; **Offset** to `{dx, dy}`.
- Plain doubles and ints pass through.

One analyzer quirk shapes this code: `getField` exposes only an object's own
fields. `BoxShadow` inherits `color`, `offset`, and `blurRadius` from `Shadow`,
and `Offset` stores private `_dx`/`_dy` behind getters, so `_field` walks the
`(super)` chain to reach inherited and backing fields.

## 9. Merge sidecars

`_sidecar` loads `meta/<Class>.yaml`, normalizes the YAML to plain maps and lists
(`_plain`, which also trims folded-scalar whitespace), and the record spreads
those keys in. This is the single place hand-authored content enters, keeping the
generated-versus-curated boundary sharp.

## 10. Emit

`registry.json` is written pretty-printed. `_llmsTxt` then renders the flat
overview from the in-memory records: setup, the token families with real values,
and every component grouped by category with its summary and inline enums.
