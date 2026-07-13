# Running, testing, and extending

## Running

```
cd generator
dart run bin/generate.dart      # writes build/registry.json, build/llms.txt, and the skill and rules references
dart test                       # regenerates, then asserts the invariants
```

The generator reads the package through the SDK pinned by `.fvmrc`. Run it with
that SDK (for example `fvm dart run bin/generate.dart`).

## Testing

`test/registry_test.dart` regenerates the manifest under the same SDK and checks
the invariants the server relies on:

- the component count,
- the four curated fields on every component,
- no unexpanded `{@macro}`, `{@template}`, or `{@category}` directives leak
  through,
- valid `#AARRGGBB` for every color role, with matching light and dark keys,
- the radii scale and integer-millisecond motion,
- `llms.txt` names every component.

Because the test regenerates first, it doubles as a smoke test that the generator
still runs against the current package.

## Extending it

- **New component**: build it in the package with its dartdoc, `{@category}`, and
  a fenced example (the package already requires these). The generator picks it up
  with no change. Add a `meta/<Class>.yaml` to give it conventions and mistakes.
- **New token or field**: add it to the token class or the constructor in the
  package; the extraction stages surface it automatically. A genuinely new value
  type in the tokens (something other than Color, Duration, TextStyle, BoxShadow,
  Offset, or a plain number) needs a case in `_tokenValue`.
- **New sidecar field**: add the key to `meta/README.md` and to the record spread
  in `_component`, then author it in the sidecars.
