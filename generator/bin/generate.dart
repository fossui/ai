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
  File('build/llms.txt').writeAsStringSync(renderLlmsTxt(registry));

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
