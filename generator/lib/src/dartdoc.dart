import 'package:analyzer/dart/element/element.dart';

/// Utilities for reading dartdoc comment text: stripping the `///` prefix,
/// expanding `{@macro}` references, and pulling out the summary, examples, and
/// category.

/// Removes the leading `/// ` from every line of a raw documentation comment.
String strip(String doc) => doc
    .split('\n')
    .map((l) => l.replaceFirst(RegExp(r'^\s*///\s?'), ''))
    .join('\n');

/// Builds the `{@template name}` to body table across the given elements, so
/// `{@macro name}` references can be resolved. The analyzer leaves these markers
/// unexpanded in the raw comment.
Map<String, String> templateTable(Iterable<Element> elements) {
  final table = <String, String>{};
  final re = RegExp(
    r'\{@template\s+([\w.]+)\}(.*?)\{@endtemplate\}',
    dotAll: true,
  );
  for (final e in elements) {
    final doc = e.documentationComment;
    if (doc == null) continue;
    for (final m in re.allMatches(strip(doc))) {
      table[m.group(1)!] = m.group(2)!.trim();
    }
  }
  return table;
}

/// Substitutes every `{@macro name}` with its template body, repeating so a
/// macro nested inside a template also resolves.
String expandMacros(String doc, Map<String, String> templates) {
  final re = RegExp(r'\{@macro\s+([\w.]+)\}');
  var text = doc;
  for (var i = 0; i < 5 && re.hasMatch(text); i++) {
    text = text.replaceAllMapped(
      re,
      (m) => templates[m.group(1)] ?? m.group(0)!,
    );
  }
  return text;
}

/// The first prose paragraph: skips dartdoc tags, image and link HTML, and
/// fences to the first real line, then accumulates until the blank-line break so
/// a wrapped sentence is not cut mid-clause.
String firstParagraph(String doc) {
  final para = <String>[];
  for (final line in doc.split('\n')) {
    final t = line.trim();
    if (para.isEmpty) {
      if (t.isEmpty ||
          t.startsWith('{@') ||
          t.startsWith('<') ||
          t.startsWith('```') ||
          t.startsWith('See ') ||
          t.contains('="')) {
        continue;
      }
      para.add(t);
    } else {
      if (t.isEmpty) break;
      para.add(t);
    }
  }
  return para.join(' ');
}

/// Drops `{@template}...{@endtemplate}` blocks and `{@macro}` lines, so a
/// component's own summary is read past its inline preview template.
String withoutTemplates(String doc) => doc
    .replaceAll(RegExp(r'\{@template.*?\{@endtemplate\}', dotAll: true), '')
    .replaceAll(RegExp(r'\{@macro[^}]*\}'), '');

/// The fenced `dart` code blocks in a comment.
List<String> examples(String doc) {
  final re = RegExp(r'```dart\s*(.*?)```', dotAll: true);
  return [for (final m in re.allMatches(doc)) m.group(1)!.trim()];
}

/// The `{@category X}` tag, or `Uncategorized` when absent.
String category(String doc) =>
    RegExp(r'\{@category\s+(\w+)\}').firstMatch(doc)?.group(1) ??
    'Uncategorized';
