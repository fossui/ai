# fossui

An open-source Flutter UI library, inspired by Cal.com's design system. One import gives you the theme system and every component.

```dart
import 'package:fossui/fossui.dart';
```

## Setup

Register the theme once, then read tokens through `context.fossTheme`. There is no `FossApp` wrapper.

- Material: `MaterialApp(theme: FossThemeData.light.toThemeData(), darkTheme: FossThemeData.dark.toThemeData())`.
- Non-Material: `FossTheme(data: FossThemeData.light, child: ...)`.

## Theme tokens

Read via `context.fossTheme`. Families:

- colors: 26 semantic roles, light and dark.
- radii: sm 6, md 8, lg 10, xl 14, xl2 16.
- spacing: unit 4; `context.fossTheme.spacing(2)` is 8.
- typography: xs, sm, base, lg, xl, xl2 (Geist).
- shadows: xs, sm, md, lg.
- motion: named durations in `context.fossTheme.motion`.

Each family resolves to a Dart type at the access site: colors `Color`, radii `double`, spacing `double`, typography `TextStyle`, shadows `List<BoxShadow>`, motion `Duration`.

## Components

All are `Foss`-prefixed. Variants and sizes are enums passed as named params; a single `style` object per component is the one-off override escape hatch. Icon slots take any `Widget`.

### Inputs

- FossAutocomplete: A text field whose dropdown filters a list of suggestions as you type.
- FossButton: A pressable button in the fossui style. (Variant: primary | secondary | outline | ghost | destructive | link. Size: sm | md | lg. Status: idle | loading | disabled)
  - controller FossButtonController(status)
  - style FossButtonStyle(backgroundColor, foregroundColor, side, borderRadius, padding, minHeight, textStyle, shadow, iconSize, gap, disabledOpacity)
- FossCheckbox: A checkbox: an independent on / off toggle that can also show an indeterminate state. (GroupVariant: plain | card)
  - group FossCheckboxGroup(children, values, onChanged, label, errorText, variant, enabled)
  - item FossCheckboxItem(value, label, description, enabled, style)
  - style FossCheckboxStyle(backgroundColor, checkedColor, checkColor, borderColor, shadow, boxSize, glyphSize, gap, labelStyle, descriptionStyle)
- FossCombobox: A text field with a filtered dropdown of predefined items, each carrying a check when picked.
  - item FossComboboxItem(value, label, icon, enabled)
  - style FossComboboxStyle(backgroundColor, borderColor, borderRadius, textStyle, shadow)
- FossMultiCombobox: A combobox that holds several picks at once, shown as removable chips.
- FossMultiSelect: A pick-several-from-list control with no typing.
- FossRadio: A single option within a [FossRadioGroup]. (GroupVariant: plain | card)
  - group FossRadioGroup(children, groupValue, onChanged, label, errorText, variant, enabled)
  - style FossRadioStyle(backgroundColor, checkedColor, dotColor, borderColor, shadow, circleSize, dotSize, gap, labelStyle, descriptionStyle)
- FossSelect: A pick-from-list control with no typing. (Size: sm | md | lg)
  - item FossSelectItem(value, label, icon, enabled)
  - style FossSelectStyle(backgroundColor, foregroundColor, placeholderColor, borderColor, borderRadius, padding, minHeight, textStyle, shadow, iconSize, gap)
- FossSlider: A horizontal slider: a track with a draggable thumb that picks a [double] from `[min, max]`.
  - style FossSliderStyle(trackColor, rangeColor, thumbColor, borderColor, shadow, trackHeight, thumbSize)
- FossSwitch: An instant on / off toggle: a pill track with a sliding thumb that commits a boolean the moment it is flipped.
  - style FossSwitchStyle(activeTrackColor, inactiveTrackColor, thumbColor, shadow, trackWidth, trackHeight, thumbSize)
- FossTextField: A text field in the fossui style. (Size: sm | md | lg)
  - style FossTextFieldStyle(backgroundColor, borderColor, borderRadius, contentPadding, minHeight, textStyle, labelStyle, helperStyle, iconSize, gap, shadow)

### Feedback

- FossAlert: A static inline callout: a leading status glyph, a title, an optional description, and optional actions, on a bordered surface tinted by the [variant]. (Variant: neutral | info | success | warning | error)
  - style FossAlertStyle(backgroundColor, borderColor, iconColor, borderRadius, titleStyle, descriptionStyle)
- FossBadge: A compact status pill: a content-hugging, single-line label that tags a count, a state, or a category. Static and non-interactive. (Variant: primary | secondary | outline | destructive | info | success | warning | error. Size: sm | md | lg)
  - style FossBadgeStyle(backgroundColor, borderColor, foregroundColor, borderRadius, labelStyle)
- FossProgress: A determinate progress bar: a full-width track with a leading fill that grows from the start to show how far a long task has run. It is static and non-interactive.
  - style FossProgressStyle(trackColor, fillColor, labelStyle, valueLabelStyle)
- FossSpinner: A circular loading indicator: an open arc that spins continuously.

### Overlays

- FossAlertDialog: A non-dismissible modal that interrupts to require a decision.
  - showFossAlertDialog(context, builder, presentation, barrierLabel, useRootNavigator)
  - style FossAlertDialogStyle(backgroundColor, borderColor, borderRadius, maxWidth, shadows, titleStyle, descriptionStyle)
- FossDialog: A modal surface with slots for a title, description, body, and actions, plus a default close affordance. Presents as a bottom sheet by default, or a centered card via [presentation]. (FooterVariant: bare | filled. Presentation: centered | bottomSheet)
  - showFossDialog(context, builder, presentation, barrierDismissible, barrierLabel, useRootNavigator)
  - style FossDialogStyle(backgroundColor, borderColor, borderRadius, maxWidth, shadows, titleStyle, descriptionStyle)
- FossDrawer: An edge-anchored modal panel with slots for a title, description, body, and actions, plus an optional drag handle and close affordance. (Side: bottom | top | left | right. Variant: rounded | straight. FooterVariant: bare | filled)
  - showFossDrawer(context, builder, side, barrierDismissible, barrierLabel, useRootNavigator)
  - style FossDrawerStyle(backgroundColor, borderColor, borderRadius, shadows, titleStyle, descriptionStyle)
- FossPopover: An interactive floating panel anchored to a [child] trigger. Tapping the trigger opens a surface built by [builder] on the preferred [side] and [align]; the surface flips and clamps to stay on screen, and an outside tap or `Escape` dismisses it (when [dismissible]). (Side: top | bottom | left | right. Align: start | center | end)
  - controller FossPopoverController()
  - style FossPopoverStyle(backgroundColor, borderColor, foregroundColor, borderRadius, padding, shadows)
- FossToast: One transient notification. Enqueue it with `showFossToast` or a `FossToastController`; the surface stays on the `popover` role for every [variant], which tints only the leading glyph. (Variant: neutral | loading | info | success | warning | error)
  - showFossToast(context, toast)
  - style FossToastStyle(backgroundColor, borderColor, borderRadius, titleStyle, descriptionStyle)
  - entry FossToastEntry(id, toast)
  - controller FossToastController()
- FossToaster: Hosts transient toasts over its [child]. Mount it once near the app root, above everything that needs to raise a toast.
- FossTooltip: Wraps a [child] trigger and shows a small floating hint next to it on hover, keyboard focus, or long-press, dismissing on exit, blur, `Escape`, or after [hideDelay]. (Side: top | bottom | left | right)
  - style FossTooltipStyle(backgroundColor, borderColor, foregroundColor, borderRadius, shadows, textStyle)

### Layout

- FossAvatar: A user's stand-in: a fixed-size circle that shows a profile [image] and falls back to a [fallback] glyph (usually initials) while the image loads, when it is absent, or when it fails to load. Static and non-interactive. (Size: xs | sm | md | lg | xl | xl2)
  - style FossAvatarStyle(backgroundColor, fallbackColor, fallbackTextStyle)
- FossCard: A static content container: a bordered, rounded surface that groups an optional header (title, description, trailing action), an optional content body, and an optional footer. Every slot is optional and content-agnostic; the surface renders, it does not respond.
  - style FossCardStyle(backgroundColor, borderColor, borderRadius, shadows, titleStyle, descriptionStyle)
- FossSeparator: A hairline rule that divides content along a row or a column. Static and non-interactive: a 1 logical pixel line in the `border` role. (Orientation: horizontal | vertical)
- FossTabs: A row or column of tabs that toggle between sibling panels, with an animated indicator marking the active tab. (Variant: segmented | underline. Orientation: horizontal | vertical)
  - style FossTabsStyle(barColor, indicatorColor, indicatorShadow, hoverColor, activeForeground, inactiveForeground, labelStyle)
  - item FossTab(value, label, icon, content, enabled)

## Links

- Homepage: https://fossui.org
- License: MIT (see NOTICE for attribution)
