// Reads foss_ui_package via the analyzer and writes build/registry.json and
// build/llms.txt. The package location comes from the first argument, then the
// FOSSUI_PACKAGE environment variable, then the default below.

import 'dart:convert';
import 'dart:io';

import 'package:fossui_generator/src/generator.dart';
import 'package:fossui_generator/src/llms_txt.dart';

const _defaultPackageRoot =
    '/Users/narayan/projects/narayann7/foss_ui/foss_ui_package';

Future<void> main(List<String> args) async {
  final packageRoot = args.isNotEmpty
      ? args.first
      : Platform.environment['FOSSUI_PACKAGE'] ?? _defaultPackageRoot;
  const metaDir = 'meta';

  final registry = await buildRegistry(
    packageRoot: packageRoot,
    metaDir: metaDir,
  );

  Directory('build').createSync(recursive: true);
  final json = const JsonEncoder.withIndent('  ').convert(registry);
  File('build/registry.json').writeAsStringSync('$json\n');

  // The flat overview, and the standalone reference bundled with the skill and
  // the rules so both work with no MCP server. One rendering, so they agree.
  final llms = renderLlmsTxt(registry);
  File('build/llms.txt').writeAsStringSync(llms);
  _writeReference('../skill/fossui/reference.md', llms);
  _writeReference('../rules/reference.md', llms);

  final components = (registry['components']! as List)
      .cast<Map<String, Object?>>();
  stdout.writeln('${components.length} components -> build/registry.json');
  for (final c in components) {
    final enums = (c['enums'] as Map?)?.length ?? 0;
    final comp = (c['companions'] as List?)?.length ?? 0;
    stdout.writeln(
      '  ${(c['name'] as String).padRight(22)} '
      '${(c['category'] as String).padRight(14)} '
      '${(c['constructors'] as List).length} ctor  $enums enum  $comp companion',
    );
  }
}

// Writes a generated reference beside a delivery vehicle, creating its folder if
// the vehicle has not been scaffolded yet.
void _writeReference(String path, String contents) {
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
  stdout.writeln('reference -> $path');
}
