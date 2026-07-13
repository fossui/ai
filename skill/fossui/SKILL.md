---
name: fossui
description: Use when building or editing Flutter UI with the fossui package (any Foss-prefixed widget, FossThemeData, context.fossTheme, or an import of package:fossui/fossui.dart). Carries the library's idioms so the code compiles and stays on-theme the first time.
---

# Building UI with fossui

`fossui` is a Flutter UI library: one import (`package:fossui/fossui.dart`) gives
the theme system and every `Foss`-prefixed component. This skill keeps AI-written
fossui code compiling and idiomatic.

## First, reach for the manifest

If the fossui MCP server is connected, use its tools before writing code. They
carry the exact, version-accurate API, so you never guess:

1. `get_setup` for the once-per-project wiring (dependency and theme).
2. `list_components`, then `get_component(<name>)` for a component's real
   constructors, params, enums, companions, and launcher functions. It also
   resolves a companion or enum name (`FossRadioGroup`, `FossButtonVariant`) back
   to its owning component.
3. `get_theme_tokens` for token values and the Dart type each family resolves to.
4. `search` to find a component or token family by keyword.

If the server is not connected, the rules below are the same guidance, distilled.

## The idioms

- **Theme once, read everywhere.** Register `FossThemeData` on the app
  (`MaterialApp(theme: FossThemeData.light.toThemeData(), darkTheme: FossThemeData.dark.toThemeData())`,
  or `FossTheme(data: ..., child: ...)` off Material), then read tokens through
  `context.fossTheme`. There is no `FossApp`.
- **Tokens are typed.** `context.fossTheme.typography.lg` is a `TextStyle`,
  `colors.primary` a `Color`, `radii.md` a `double`, `motion.overlay` a
  `Duration`. Use them directly; do not call a converter.
- **Variants and sizes are enums**, passed as named params
  (`variant: FossButtonVariant.primary`, `size: FossButtonSize.md`). Never a
  string.
- **No per-instance token props.** There is no `color`, `borderRadius`, or
  `padding` on a component. Retheme globally through `FossThemeData`, or pass the
  component's `style` object for a one-off.
- **Icon slots take any `Widget`.** The package has no icon dependency; examples
  use Lucide.
- **Groups own the selection.** `FossRadioGroup(groupValue:, onChanged:, children:)`
  wrapping `FossRadio`s; `FossCheckboxGroup(values:, onChanged:, children:)`
  wrapping `FossCheckboxItem`s. Typed pick controls take typed items
  (`FossSelectItem`, `FossComboboxItem`), not raw strings.
- **Overlays open with a launcher function**, not a constructor:
  `showFossDialog`, `showFossDrawer`, `showFossAlertDialog`. `showFossToast`
  requires a `FossToaster` near the app root.
- **Horizontal `FossTabs` do not scroll.** On a phone keep labels short and few,
  or use the vertical orientation.

## Before you finish

Read back the diff and check: no string where an enum belongs, no `color`,
`borderRadius`, or `padding` param, groups use `groupValue` / `values` with
`children`, overlays use their `show...` launcher. Then run `flutter analyze`.
