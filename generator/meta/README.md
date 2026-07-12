# Component sidecars

One `meta/<Class>.yaml` per component, holding the curated fields the API cannot
carry. Everything else in `registry.json` is generated from the package; these
files are the only hand-authored input, and are reviewed like code.

The generator merges a sidecar's top-level keys into that component's record. All
keys are optional; a missing sidecar yields a valid, judgment-light record.

## Schema

```yaml
tags: [action, form, cta]        # search keywords, lowercase
whenToUse: >                     # one or two lines: when to reach for this
  A short sentence on when this component fits and what to prefer instead.
conventions:
  do:
    - Short imperative guidance grounded in the real API.
  dont:
    - The specific wrong move, stated plainly.
commonMistakes:                  # the wrong code models actually emit, plus the fix
  - wrong: "FossButton(color: Colors.red, ...)"
    right: "FossButton(variant: FossButtonVariant.destructive, ...)"
    why: A one-line reason the wrong form fails.
```

## Rules

- Ground every line in the component's actual API and the library's architecture
  (look flows from the theme, not per-instance props; variants and sizes are
  enums; icon slots take any `Widget`). Do not invent props.
- No em dashes. No external names (design tools, other libraries). Terse and
  factual. Write against the current API, not an aspirational one.
