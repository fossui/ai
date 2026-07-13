---
name: fossui
description: Use when building or editing Flutter UI with the fossui package (any Foss-prefixed widget, FossThemeData, context.fossTheme, or an import of package:fossui/fossui.dart). Carries the library's idioms so the code compiles and stays on-theme the first time.
---

# Building UI with fossui

`fossui` is a Flutter UI library: one import (`package:fossui/fossui.dart`) gives
the theme system and every `Foss`-prefixed component. This skill keeps AI-written
fossui code compiling and idiomatic.

## Find the exact API

The full component reference is bundled beside this file at `reference.md`: every
component with its enums, companion params, launcher functions, and the token
families. Read it before writing code so you never guess a constructor. The
idioms below are the rules that hold across all of them.

If the fossui MCP server is also connected, prefer its tools for the freshest,
per-component detail: `get_setup` for wiring, `get_component(<name>)` for one
component's full API (it also resolves a companion or enum name like
`FossRadioGroup` back to its owner), `get_theme_tokens` for token types, and
`search` to find a component or token family. Server or bundled reference, the
content is the same; the server is just live and on demand.

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
