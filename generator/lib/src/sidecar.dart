import 'dart:io';

import 'package:yaml/yaml.dart';

/// Loads the curated `<metaDir>/<Class>.yaml` sidecar (conventions, tags,
/// whenToUse, commonMistakes). An absent sidecar yields an empty map, so the
/// generator never blocks on one.
Map<String, Object?> loadSidecar(String metaDir, String name) {
  final file = File('$metaDir/$name.yaml');
  if (!file.existsSync()) return const {};
  final data = _toPlain(loadYaml(file.readAsStringSync()));
  return data is Map ? data.cast<String, Object?>() : const {};
}

// Normalizes YAML nodes to plain maps, lists, and trimmed strings so they encode
// cleanly and folded scalars carry no trailing newline.
Object? _toPlain(Object? node) => switch (node) {
  final Map<Object?, Object?> m => {
    for (final e in m.entries) '${e.key}': _toPlain(e.value),
  },
  final List<Object?> l => [for (final e in l) _toPlain(e)],
  final String s => s.trim(),
  _ => node,
};
