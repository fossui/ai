import 'constants.dart';

/// Renders `llms.txt` from the registry records: the flat, always-current
/// overview any tool can load. Grouped by category, each component carrying its
/// summary and its variant and size enums inline.
String renderLlmsTxt(Map<String, Object?> registry) {
  final meta = registry['meta']! as Map<String, Object?>;
  final components = (registry['components']! as List)
      .cast<Map<String, Object?>>();
  final tokens = registry['tokens']! as Map<String, Object?>;
  final radii = (tokens['radii']! as Map).cast<String, Object?>();
  final types = (tokens['types']! as Map).cast<String, Object?>();

  final b = StringBuffer()
    ..writeln('# fossui')
    ..writeln()
    ..writeln(
      "An open-source Flutter UI library, inspired by Cal.com's design "
      'system. One import gives you the theme system and every component.',
    )
    ..writeln()
    ..writeln('```dart')
    ..writeln("import '${meta['import']}';")
    ..writeln('```')
    ..writeln()
    ..writeln('## Setup')
    ..writeln()
    ..writeln(
      'Register the theme once, then read tokens through '
      '`context.fossTheme`. There is no `FossApp` wrapper.',
    )
    ..writeln()
    ..writeln(
      '- Material: `MaterialApp(theme: FossThemeData.light.toThemeData(), '
      'darkTheme: FossThemeData.dark.toThemeData())`.',
    )
    ..writeln(
      '- Non-Material: `FossTheme(data: FossThemeData.light, child: ...)`.',
    )
    ..writeln()
    ..writeln('## Theme tokens')
    ..writeln()
    ..writeln('Read via `context.fossTheme`. Families:')
    ..writeln()
    ..writeln(
      '- colors: ${((tokens['colors']! as Map)['light']! as Map).length} '
      'semantic roles, light and dark.',
    )
    ..writeln(
      '- radii: ${radii.entries.map((e) => '${e.key} ${_num(e.value)}').join(', ')}.',
    )
    ..writeln(
      '- spacing: unit ${_num((tokens['spacing']! as Map)['unit'])}; '
      '`context.fossTheme.spacing(2)` is 8.',
    )
    ..writeln(
      '- typography: ${(tokens['typography']! as Map).keys.join(', ')} (Geist).',
    )
    ..writeln('- shadows: ${(tokens['shadows']! as Map).keys.join(', ')}.')
    ..writeln('- motion: named durations in `context.fossTheme.motion`.')
    ..writeln()
    ..writeln(
      'Each family resolves to a Dart type at the access site: '
      '${types.entries.map((e) => '${e.key} `${e.value}`').join(', ')}.',
    )
    ..writeln()
    ..writeln('## Components')
    ..writeln()
    ..writeln(
      'All are `Foss`-prefixed. Variants and sizes are enums passed as '
      'named params; a single `style` object per component is the one-off '
      'override escape hatch. Icon slots take any `Widget`.',
    );

  for (final category in categoryOrder) {
    final inCategory = components.where((c) => c['category'] == category);
    if (inCategory.isEmpty) continue;
    b
      ..writeln()
      ..writeln('### $category')
      ..writeln();
    for (final c in inCategory) {
      b.writeln('- ${_componentLine(c)}');
      for (final sub in _support(c)) {
        b.writeln('  - $sub');
      }
    }
  }

  b
    ..writeln()
    ..writeln('## Links')
    ..writeln()
    ..writeln('- Homepage: ${meta['homepage']}')
    ..writeln('- License: MIT (see NOTICE for attribution)');
  return b.toString();
}

String _componentLine(Map<String, Object?> c) {
  final name = c['name']! as String;
  final summary = c['summary'];
  final enums = (c['enums'] as Map?)?.cast<String, Object?>() ?? {};
  final inline = [
    for (final entry in enums.entries)
      '${_enumLabel(entry.key, name)}: '
          '${(entry.value! as List).map((v) => (v as Map)['value']).join(' | ')}',
  ].join('. ');
  return inline.isEmpty ? '$name: $summary' : '$name: $summary ($inline)';
}

// The launcher functions and companion classes a component needs, each with its
// param names, so a reader of the flat file is not left to guess the group,
// item, or show-function API the tool records carry.
List<String> _support(Map<String, Object?> c) {
  final out = <String>[];
  for (final fn in (c['functions'] as List?)?.cast<Map<String, Object?>>() ??
      const []) {
    out.add('${fn['name']}(${_paramNames(fn['params'])})');
  }
  for (final comp in (c['companions'] as List?)?.cast<Map<String, Object?>>() ??
      const []) {
    final ctors = (comp['constructors'] as List?)?.cast<Map<String, Object?>>();
    if (ctors == null || ctors.isEmpty) continue;
    // Skip a private scope; it is an implementation detail, not a call site.
    if (comp['kind'] == 'scope') continue;
    out.add(
      '${comp['kind']} ${comp['name']}(${_paramNames(ctors.first['params'])})',
    );
  }
  return out;
}

String _paramNames(Object? params) =>
    ((params as List?) ?? const [])
        .cast<Map<String, Object?>>()
        .map((p) => p['name'])
        .join(', ');

// FossButtonVariant -> Variant, FossButtonSize -> Size.
String _enumLabel(String enumName, String component) =>
    enumName.startsWith(component)
    ? enumName.substring(component.length)
    : enumName;

String _num(Object? v) =>
    v is num && v == v.roundToDouble() ? '${v.toInt()}' : '$v';
