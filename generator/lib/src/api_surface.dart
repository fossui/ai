import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;

import 'dartdoc.dart';

/// Suffixes that mark a class as a companion of its prefix, not a component.
final companionSuffix = RegExp(r'(Style|Controller|Item|Scope|Entry|Group)$');

bool _isFoss(Element e) => (e.name ?? '').startsWith('Foss');

/// The resolved public API of the package, classified into the buckets the
/// extractor works from. Load it with [ApiSurface.load].
class ApiSurface {
  ApiSurface._({
    required this.classes,
    required this.enums,
    required this.primaries,
    required this.companions,
    required this.orphanItems,
    required this.templates,
  }) : primaryNames = [for (final c in primaries) c.name!];

  /// Every public `Foss*` class, including components, companions, and token
  /// and theme types.
  final List<ClassElement> classes;

  /// Every public `Foss*` enum.
  final List<EnumElement> enums;

  /// Components: categorized classes that are not companions.
  final List<ClassElement> primaries;

  /// Companion classes (Style, Controller, Item, Scope, Entry, Group).
  final List<ClassElement> companions;

  /// Item classes with no companion suffix that a component's name extends,
  /// such as `FossTab` under `FossTabs`.
  final List<ClassElement> orphanItems;

  /// The `{@template name}` to body table across the whole API.
  final Map<String, String> templates;

  /// Names of every component, in sorted order.
  final List<String> primaryNames;

  /// Resolves the package barrel and classifies its public API.
  static Future<ApiSurface> load(String packageRoot) async {
    final barrel = p.join(packageRoot, 'lib/fossui.dart');
    final collection = AnalysisContextCollection(includedPaths: [barrel]);
    final result = await collection
        .contextFor(barrel)
        .currentSession
        .getResolvedUnit(barrel);
    if (result is! ResolvedUnitResult) {
      throw StateError('could not resolve barrel: $result');
    }
    final api = result.libraryElement.exportNamespace.definedNames2.values;
    final classes = api.whereType<ClassElement>().where(_isFoss).toList();
    final enums = api.whereType<EnumElement>().where(_isFoss).toList();

    // Components carry a {@category}; token and theme types do not, so they fall
    // out here for the separate tokens pass.
    final primaries =
        classes
            .where((c) => !companionSuffix.hasMatch(c.name ?? ''))
            .where(
              (c) =>
                  category(strip(c.documentationComment ?? '')) !=
                  'Uncategorized',
            )
            .toList()
          ..sort((a, b) => a.name!.compareTo(b.name!));
    final companions = classes
        .where((c) => companionSuffix.hasMatch(c.name ?? ''))
        .toList();
    final primaryNames = {for (final c in primaries) c.name!};

    // Item classes like FossTab carry no companion suffix and are not
    // components, but a component's name extends theirs (FossTabs over FossTab).
    final orphanItems = classes.where((c) {
      final n = c.name!;
      return !companionSuffix.hasMatch(n) &&
          !primaryNames.contains(n) &&
          primaryNames.any((pn) => pn != n && pn.startsWith(n));
    }).toList();

    return ApiSurface._(
      classes: classes,
      enums: enums,
      primaries: primaries,
      companions: companions,
      orphanItems: orphanItems,
      templates: templateTable([...classes, ...enums]),
    );
  }
}
