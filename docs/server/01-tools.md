# Tools and resource

Six tools, each a slice of `registry.json`. All read-only. Empty inputs are
rejected by the schema, not treated as match-all.

## list_components

No input. Returns every component as `{ name, category, summary, tags }`. The
cheap catalog an agent calls first.

## get_component

Input `{ name }`. Returns one component's full record: constructors, params,
enums, companions (with their constructors), launcher functions, examples, urls,
tags, whenToUse, conventions, commonMistakes.

Resolution order:

```
name
 ├─ exact component match          -> the full record
 ├─ a companion / enum / function  -> that record + its owning component
 └─ miss                           -> { error, didYouMean } , isError: true
```

The middle step means `get_component("FossRadioGroup")` or
`get_component("showFossDialog")` returns the real API and points at `FossRadio`
or `FossDialog`, instead of dead-ending. A true miss fuzzy-matches (substring,
then subsequence) so `Slidr` suggests `FossSlider`, without dumping the catalog.

## search

Input `{ query }`. Returns `{ components, tokenFamilies }`.

```
component score:  name match +3   tag match +2   summary +1   whenToUse +1
token family:     key substring, or a synonym (radius->radii, font->typography)
```

Components are filtered to a positive score and ranked. No match returns empty
arrays, not an error.

## get_theme_tokens

Input `{ family? }`. Omit `family` for all six families. Pass one
(`colors | radii | spacing | typography | shadows | motion`) for that family plus
its Dart `type` (`typography` is a `TextStyle`, `colors` a `Color`, and so on) and
the `access` string.

## get_package

No input. Returns the identity for pulling the package: `name`, `version`,
`pubDev`, `homepage`, the `install` command (`flutter pub add fossui`), the
`pubspec` line, and the `import`. The entry point for pulling the package; then
`get_setup` for the wiring.

## get_setup

Input `{ app_type? }`. Returns the once-per-project wiring: `pubspec`, the theme
`wiring`, `access`, and a `note`. `material` (default) gives the `MaterialApp`
form; `cupertino` and `widgets` give the `FossTheme` wrapper.

## Resource: fossui://llms.txt

The flat, whole-library overview, for clients that read one document instead of
calling tools. Carries the same token types, companion params, and launcher
signatures the tools do.
