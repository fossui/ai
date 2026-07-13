# fossui

Rules for writing Flutter UI with the `fossui` package. Paste this section into
your project's `CLAUDE.md` or `AGENTS.md`.

## Import and theme

- One import gives you everything: `import 'package:fossui/fossui.dart';`.
- Register the theme once, then read tokens through `context.fossTheme`. There is
  no `FossApp` wrapper.
  - Material: `MaterialApp(theme: FossThemeData.light.toThemeData(), darkTheme: FossThemeData.dark.toThemeData())`.
  - Cupertino or bare Widgets: `FossTheme(data: FossThemeData.light, child: ...)`.
- Tokens resolve to real Dart types at the access site: `context.fossTheme.typography.lg`
  is a `TextStyle`, `colors.primary` is a `Color`, `radii.md` is a `double`,
  `motion.overlay` is a `Duration`. Do not call a converter on them.

## The rules that keep code compiling

- Variants and sizes are enums, never strings: `FossButtonVariant.primary`,
  `FossButtonSize.md`. Passing `'primary'` will not compile.
- Do not pass `color`, `borderRadius`, or `padding` to a component. They do not
  exist. Change the look through the theme (`FossThemeData`) globally, or the
  component's `style` object for a one-off.
- Icon slots (`leading`, `trailing`, `icon`) take any `Widget`. The package takes
  no icon dependency; examples use Lucide.
- Selection groups own the selection, not the individual option:
  - `FossRadioGroup(groupValue: ..., onChanged: ..., children: [FossRadio(...)])`.
  - `FossCheckboxGroup(values: <Set>, onChanged: ..., children: [FossCheckboxItem(...)])`.
- Typed pick controls take typed items: `FossSelect<T>(items: [FossSelectItem(value: ..., label: ...)])`,
  not a list of raw strings.
- Overlays open through a launcher function, not a constructor:
  `showFossDialog(context: ..., builder: ...)`, `showFossDrawer(...)`,
  `showFossAlertDialog(...)`. `showFossToast` needs a `FossToaster` mounted near
  the app root.
- Horizontal `FossTabs` do not scroll. On a phone, keep labels short and few, or
  use the vertical orientation.

## When the fossui MCP is connected

Prefer its tools over guessing: `get_setup` for wiring, `list_components` then
`get_component(<name>)` for the exact constructor, enums, companions, and
launcher functions, `get_theme_tokens` for token values and their Dart types, and
`search` to find a component or token family. `get_component` also resolves a
companion or enum name (`FossRadioGroup`, `FossButtonVariant`) to its owner.
