import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

// Regenerates the manifest, then asserts the invariants the MCP server relies
// on. The generator runs under the same SDK that runs this test.
void main() {
  late Map<String, Object?> registry;
  late String rawJson;
  late String llms;

  setUpAll(() {
    final run = Process.runSync(Platform.resolvedExecutable, [
      'bin/generate.dart',
    ]);
    expect(run.exitCode, 0, reason: 'generator failed: ${run.stderr}');
    rawJson = File('build/registry.json').readAsStringSync();
    registry = jsonDecode(rawJson) as Map<String, Object?>;
    llms = File('build/llms.txt').readAsStringSync();
  });

  List<Map<String, Object?>> components() =>
      (registry['components']! as List).cast<Map<String, Object?>>();

  const categories = {'Inputs', 'Feedback', 'Overlays', 'Layout'};
  final emDash = String.fromCharCode(0x2014);
  final hex = RegExp(r'^#[0-9A-F]{8}$');

  test('meta is complete', () {
    final meta = registry['meta']! as Map<String, Object?>;
    expect(meta['package'], 'fossui');
    expect(meta['import'], 'package:fossui/fossui.dart');
    expect(meta['version']! as String, isNotEmpty);
  });

  test('has the expected component set', () {
    expect(components(), hasLength(26));
    for (final c in components()) {
      expect(c['name']! as String, startsWith('Foss'));
    }
  });

  test('no unexpanded dartdoc directives leak into the manifest', () {
    expect(rawJson, isNot(contains(r'{@template')));
    expect(rawJson, isNot(contains(r'{@macro')));
    expect(rawJson, isNot(contains(r'{@category')));
  });

  test('no em dashes anywhere', () {
    expect(rawJson.contains(emDash), isFalse);
    expect(llms.contains(emDash), isFalse);
  });

  group('every component', () {
    test('has a category, summary, a constructor, and an example', () {
      for (final c in components()) {
        final name = c['name'];
        expect(categories, contains(c['category']), reason: '$name category');
        expect(c['summary']! as String, isNotEmpty, reason: '$name summary');
        expect(c['constructors']! as List, isNotEmpty, reason: '$name ctors');
        expect(c['examples']! as List, isNotEmpty, reason: '$name examples');
      }
    });

    test('carries the four curated sidecar fields', () {
      for (final c in components()) {
        final name = c['name'];
        expect(c['tags'], isA<List<Object?>>(), reason: '$name tags');
        expect(c['whenToUse'], isA<String>(), reason: '$name whenToUse');
        expect(
          c['conventions'],
          isA<Map<Object?, Object?>>(),
          reason: '$name conventions',
        );
        for (final m
            in (c['commonMistakes']! as List).cast<Map<String, Object?>>()) {
          expect(m['wrong'], isA<String>(), reason: '$name mistake.wrong');
          expect(m['right'], isA<String>(), reason: '$name mistake.right');
          expect(m['why'], isA<String>(), reason: '$name mistake.why');
        }
      }
    });

    test('companions carry the constructors an agent must call', () {
      final radio = components().firstWhere((c) => c['name'] == 'FossRadio');
      final companions =
          (radio['companions']! as List).cast<Map<String, Object?>>();
      final group = companions.firstWhere((c) => c['name'] == 'FossRadioGroup');
      final params = ((group['constructors']! as List).first
              as Map<String, Object?>)['params']!
          as List;
      final names = [for (final p in params) (p as Map)['name']];
      expect(names, containsAll(<String>['groupValue', 'children']));
    });

    test('overlays carry their launcher function with full params', () {
      final dialog = components().firstWhere((c) => c['name'] == 'FossDialog');
      final fns = (dialog['functions']! as List).cast<Map<String, Object?>>();
      final show = fns.firstWhere((f) => f['name'] == 'showFossDialog');
      expect(show['returns'], startsWith('Future'));
      final names = [
        for (final p in show['params']! as List) (p as Map)['name'],
      ];
      expect(names, containsAll(<String>['context', 'builder']));
    });

    test('has non-empty enum values and https urls', () {
      for (final c in components()) {
        for (final values in (c['enums'] as Map?)?.values ?? const []) {
          for (final v in values as List) {
            expect(
              (v as Map)['value'],
              isNotEmpty,
              reason: '${c['name']} enum value',
            );
          }
        }
        for (final u in (c['urls'] as Map?)?.values ?? const []) {
          if (u is String) expect(u, startsWith('https://'));
        }
      }
    });
  });

  group('tokens', () {
    Map<String, Object?> tokens() =>
        registry['tokens']! as Map<String, Object?>;

    test('light and dark colors share the same roles and are valid hex', () {
      final colors = tokens()['colors']! as Map<String, Object?>;
      final light = (colors['light']! as Map).cast<String, Object?>();
      final dark = (colors['dark']! as Map).cast<String, Object?>();
      expect(light.keys.toSet(), dark.keys.toSet());
      expect(light, isNotEmpty);
      for (final entry in [...light.entries, ...dark.entries]) {
        expect(
          hex.hasMatch(entry.value! as String),
          isTrue,
          reason: 'bad hex for ${entry.key}: ${entry.value}',
        );
      }
    });

    test('each family reports the Dart type it resolves to', () {
      expect(tokens()['types'], {
        'colors': 'Color',
        'radii': 'double',
        'spacing': 'double',
        'typography': 'TextStyle',
        'shadows': 'List<BoxShadow>',
        'motion': 'Duration',
      });
    });

    test('each family reports the unit its values carry', () {
      final units = (tokens()['units']! as Map).cast<String, Object?>();
      expect(units.keys.toSet(), {
        'colors',
        'radii',
        'spacing',
        'typography',
        'shadows',
        'motion',
      });
      expect(units['motion'], 'milliseconds');
      expect(units['radii'], 'logical pixels');
    });

    test('radii are the expected scale', () {
      expect(tokens()['radii'], {
        'sm': 6,
        'md': 8,
        'lg': 10,
        'xl': 14,
        'xl2': 16,
      });
    });

    test('motion durations are integer milliseconds', () {
      final motion = (tokens()['motion']! as Map).cast<String, Object?>();
      expect(motion, isNotEmpty);
      for (final v in motion.values) {
        expect(v, isA<int>());
      }
    });

    test('shadows carry color, offset, and blur', () {
      final shadows = (tokens()['shadows']! as Map).cast<String, Object?>();
      for (final layers in shadows.values) {
        for (final layer in layers as List) {
          final s = layer as Map;
          expect(hex.hasMatch(s['color']! as String), isTrue);
          expect(s['offset'], isA<Map<Object?, Object?>>());
          expect(s['blur'], isA<double>());
        }
      }
    });
  });

  test('setup wires the dep and theme', () {
    final setup = registry['setup']! as Map<String, Object?>;
    expect(setup['pubspec'], startsWith('fossui: ^'));
    expect(setup['material'], contains('FossThemeData.light.toThemeData()'));
    expect(setup['nonMaterial'], contains('FossTheme('));
    expect(setup['access'], 'context.fossTheme');
  });

  test('llms.txt names every component', () {
    for (final c in components()) {
      expect(llms, contains(c['name']! as String));
    }
  });

  test('the skill and rules ship a generated reference', () {
    for (final path in ['../skill/fossui/reference.md', '../rules/reference.md']) {
      final ref = File(path).readAsStringSync();
      expect(ref, equals(llms), reason: '$path should match llms.txt');
      expect(ref, contains('FossButton'));
    }
  });

  test('llms.txt carries the data the tools carry', () {
    // Token types, a group companion with its real param, and an overlay launcher
    // so a client that reads the flat file is not behind the tool records.
    expect(llms, contains('typography `TextStyle`'));
    expect(llms, contains('FossRadioGroup(children, groupValue'));
    expect(llms, contains('showFossDialog(context, builder'));
  });
}
