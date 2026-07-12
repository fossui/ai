import 'dart:io';

import 'package:path/path.dart' as p;

import 'api_surface.dart';
import 'component_extractor.dart';
import 'constants.dart';
import 'sidecar.dart';
import 'token_extractor.dart';

/// Builds the full registry map from the package and the sidecars. The generated
/// component fields come from [componentRecord]; the curated fields are merged on
/// from each component's sidecar.
Future<Map<String, Object?>> buildRegistry({
  required String packageRoot,
  required String metaDir,
}) async {
  final api = await ApiSurface.load(packageRoot);
  final components = [
    for (final primary in api.primaries)
      {
        ...componentRecord(primary, api),
        ...loadSidecar(metaDir, primary.name!),
      },
  ];
  return {
    'meta': {
      'package': 'fossui',
      'version': _version(packageRoot),
      'import': packageImport,
      'homepage': 'https://fossui.org',
    },
    'components': components,
    'tokens': extractTokens(api.classes),
  };
}

String _version(String packageRoot) {
  final pubspec = File(p.join(packageRoot, 'pubspec.yaml')).readAsStringSync();
  return RegExp(
        r'^version:\s*(.+)$',
        multiLine: true,
      ).firstMatch(pubspec)?.group(1)?.trim() ??
      '';
}
