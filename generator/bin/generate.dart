// Phase-2 spike: extract FossButton from foss_ui_package via the analyzer and
// emit one registry.json component record. Proves the analyzer-source decision
// (generator-plan.md 3) on real output before fanning out to every component.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;

const _packageRoot = '/Users/narayan/projects/narayann7/foss_ui/foss_ui_package';

Future<void> main() async {
  final buttonPath = p.join(_packageRoot, 'lib/src/components/button/foss_button.dart');
  final themePath = p.join(_packageRoot, 'lib/src/theme/foss_theme.dart');

  final collection = AnalysisContextCollection(includedPaths: [buttonPath, themePath]);
  final session = collection.contextFor(buttonPath).currentSession;

  final buttonLib = await _library(session, buttonPath);
  final themeLib = await _library(session, themePath);

  // Stage 3: build the {@template name} -> body table across both libraries so
  // {@macro} references (foss.button.preview here, foss.customize in the theme
  // lib) resolve. The raw documentationComment leaves them unexpanded.
  final templates = <String, String>{}
    ..addAll(_templates(buttonLib))
    ..addAll(_templates(themeLib));

  final button = buttonLib.classes.firstWhere((c) => c.name == 'FossButton');
  final record = _component(button, buttonLib, templates);

  final json = const JsonEncoder.withIndent('  ').convert(record);
  final out = File(p.join('build', 'button.generated.json'));
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('$json\n');
  stdout.writeln(json);
  stdout.writeln('\nwrote ${out.path}');
}

Future<LibraryElement> _library(dynamic session, String path) async {
  final result = await session.getResolvedUnit(path);
  if (result is! ResolvedUnitResult) {
    throw StateError('could not resolve $path: $result');
  }
  return result.libraryElement;
}

Map<String, String> _templates(LibraryElement lib) {
  final table = <String, String>{};
  final docs = <String?>[
    for (final c in lib.classes) c.documentationComment,
    for (final e in lib.enums) e.documentationComment,
  ];
  final re = RegExp(r'\{@template\s+([\w.]+)\}(.*?)\{@endtemplate\}', dotAll: true);
  for (final doc in docs) {
    if (doc == null) continue;
    for (final m in re.allMatches(_strip(doc))) {
      table[m.group(1)!] = m.group(2)!.trim();
    }
  }
  return table;
}

Map<String, Object?> _component(
  ClassElement cls,
  LibraryElement lib,
  Map<String, String> templates,
) {
  final raw = _strip(cls.documentationComment ?? '');
  final doc = _expand(raw, templates);
  return {
    'name': cls.name,
    'category': _category(raw),
    'import': 'package:fossui/fossui.dart',
    'summary': _summary(_withoutTemplates(raw)),
    'constructors': [
      for (final ctor in cls.constructors)
        if (ctor.isPublic) _constructor(ctor, cls),
    ],
    'enums': _enums(lib, ['FossButtonVariant', 'FossButtonSize']),
    'examples': _examples(doc),
  };
}

// A component's own summary lives after its inline preview template; drop
// {@template}...{@endtemplate} and {@macro} lines before reading it.
String _withoutTemplates(String doc) => doc
    .replaceAll(RegExp(r'\{@template.*?\{@endtemplate\}', dotAll: true), '')
    .replaceAll(RegExp(r'\{@macro[^}]*\}'), '');

Map<String, Object?> _constructor(ConstructorElement ctor, ClassElement cls) {
  final unnamed = ctor.isDefaultConstructor || (ctor.name ?? 'new') == 'new';
  final name = unnamed ? cls.name : '${cls.name}.${ctor.name}';
  return {
    'name': name,
    'params': [
      for (final param in ctor.formalParameters)
        if (param.name != 'key')
          {
          'name': param.name,
          'type': param.type.getDisplayString(),
          if (param.isRequiredNamed || param.isRequiredPositional) 'required': true,
          if (param.defaultValueCode != null) 'default': param.defaultValueCode,
          if (_paramDoc(param, cls) case final d?) 'doc': d,
        },
    ],
  };
}

// A `this.child` param carries no doc of its own; the doc lives on the field.
String? _paramDoc(FormalParameterElement param, ClassElement cls) {
  final field = cls.fields.where((f) => f.name == param.name).firstOrNull;
  final doc = field?.documentationComment;
  return doc == null ? null : _summary(_strip(doc));
}

Map<String, Object?> _enums(LibraryElement lib, List<String> names) {
  final out = <String, Object?>{};
  for (final name in names) {
    final e = lib.enums.where((x) => x.name == name).firstOrNull;
    if (e == null) continue;
    out[name] = [
      for (final v in e.constants)
        {
          'value': v.name,
          if (v.documentationComment case final d?) 'doc': _summary(_strip(d)),
        },
    ];
  }
  return out;
}

String _category(String doc) =>
    RegExp(r'\{@category\s+(\w+)\}').firstMatch(doc)?.group(1) ?? 'Uncategorized';

// First real prose line, skipping dartdoc tags and image/link HTML.
String _summary(String doc) {
  for (final line in doc.split('\n')) {
    final t = line.trim();
    if (t.isEmpty) continue;
    if (t.startsWith('{@') || t.startsWith('<') || t.startsWith('```') || t.startsWith('See ')) {
      continue;
    }
    return t;
  }
  return '';
}

List<String> _examples(String doc) {
  final re = RegExp(r'```dart\s*(.*?)```', dotAll: true);
  return [for (final m in re.allMatches(doc)) m.group(1)!.trim()];
}

String _expand(String doc, Map<String, String> templates) {
  final re = RegExp(r'\{@macro\s+([\w.]+)\}');
  var text = doc;
  for (var i = 0; i < 5 && re.hasMatch(text); i++) {
    text = text.replaceAllMapped(re, (m) => templates[m.group(1)] ?? m.group(0)!);
  }
  return text;
}

// Strip leading `/// ` from each dartdoc line.
String _strip(String doc) =>
    doc.split('\n').map((l) => l.replaceFirst(RegExp(r'^\s*///\s?'), '')).join('\n');
