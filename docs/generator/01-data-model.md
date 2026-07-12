# Inputs and outputs

What the generator reads, and the exact shape of what it writes. See
[overview.md](00-overview.md) for the overview and [pipeline.md](02-pipeline.md) for how
one becomes the other.

## Inputs

1. **The package** (`foss_ui_package/`, read-only). The public API is the ground
   truth: constructors, parameters, enums, dartdoc comments, the token classes,
   and the annotations. Because the package lints `public_member_api_docs` as an
   error, this raw material is guaranteed present and current.
2. **Sidecars** (`generator/meta/<Class>.yaml`). The only hand-authored
   input, one file per component, holding the judgment the API cannot express:
   `tags`, `whenToUse`, `conventions` (do/dont), `commonMistakes`. Reviewed like
   code. A missing sidecar yields a valid, judgment-light record. The schema is
   documented in `generator/meta/README.md`.

The generator reads the package as input and writes only into `generator/build/`. It never
edits the package.

## Outputs

Two files, both under `generator/build/`:

- **`registry.json`**: the structured manifest. Top level is `meta`, a
  `components` array, and a `tokens` object.
- **`llms.txt`**: a flat text overview rendered from the same records, so the two
  can never disagree.

### A component record

Every entry in `components[]` looks like this. Fields appear only when they apply.

```
name           FossButton
category       Inputs | Feedback | Overlays | Layout
import         package:fossui/fossui.dart
summary        first prose paragraph of the class dartdoc
constructors   [ { name, params: [ { name, type, required?, default?, doc? } ] } ]
enums          { FossButtonVariant: [ { value, doc? } ], ... }
companions     [ { name, kind: style|controller|item|scope|group, summary } ]
examples       [ fenced dart snippets from the dartdoc ]
urls           { docs, playground, preview: { light, dark } }
tags           from the sidecar
whenToUse      from the sidecar
conventions    { do: [...], dont: [...] }     from the sidecar
commonMistakes [ { wrong, right, why } ]      from the sidecar
```

The first eight fields are generated from the package and cannot drift. The last
four come from the reviewed sidecar. That line, generated versus curated, is the
core design boundary (see [design-decisions.md](03-design-decisions.md)).

### The token layer

`tokens` holds the six families, const-evaluated to plain JSON:

```
access       context.fossTheme
colors       { light: { role: "#AARRGGBB", ... }, dark: { ... } }
radii        { sm: 6, md: 8, lg: 10, xl: 14, xl2: 16 }
spacing      { unit: 4 }
typography   { xs: { fontFamily, fontSize, height, letterSpacing }, ... }
shadows      { xs: [ { color, offset: {dx,dy}, blur, spread } ], ... }
motion       { overlay: 200, drawer: 450, ... }   (milliseconds)
```

How these values are pulled out of Dart constants is covered in
[pipeline.md](02-pipeline.md#8-tokens).
