import 'package:analyzer/dart/element/element.dart';

import 'api_surface.dart';
import 'constants.dart';
import 'dartdoc.dart';

/// Builds the generated half of a component record: everything derivable from
/// the source. The curated sidecar fields are merged on separately.
Map<String, Object?> componentRecord(ClassElement cls, ApiSurface api) {
  final name = cls.name!;
  final raw = strip(cls.documentationComment ?? '');
  final doc = expandMacros(raw, api.templates);

  return {
    'name': name,
    'category': category(raw),
    'import': packageImport,
    'summary': firstParagraph(withoutTemplates(raw)),
    'constructors': [
      for (final ctor in cls.constructors)
        if (ctor.isPublic) _constructor(ctor, cls),
    ],
    if (_ownedEnums(cls, api) case final e when e.isNotEmpty) 'enums': e,
    if (_ownedCompanions(cls, api) case final c when c.isNotEmpty)
      'companions': c,
    'examples': examples(doc),
    if (_urls(doc) case final u when u.isNotEmpty) 'urls': u,
  };
}

// A component claims the companions and enums its name prefixes, but only when
// no longer-named component also prefixes them, so FossTabsVariant binds to
// FossTabs, not FossTab.
bool _owns(String owner, String other, List<String> primaryNames) {
  if (other == owner || !other.startsWith(owner)) return false;
  return !primaryNames.any(
    (p) => p.length > owner.length && other.startsWith(p),
  );
}

Map<String, Object?> _ownedEnums(ClassElement cls, ApiSurface api) => {
  for (final e in api.enums)
    if (_owns(cls.name!, e.name!, api.primaryNames)) e.name!: _enumValues(e),
};

List<Map<String, Object?>> _ownedCompanions(ClassElement cls, ApiSurface api) {
  final name = cls.name!;
  return [
    for (final c in api.companions)
      if (_owns(name, c.name!, api.primaryNames))
        {
          'name': c.name,
          'kind': _kind(c.name!),
          'summary': firstParagraph(strip(c.documentationComment ?? '')),
        },
    for (final o in api.orphanItems)
      if (name != o.name && name.startsWith(o.name!))
        {
          'name': o.name,
          'kind': 'item',
          'summary': firstParagraph(strip(o.documentationComment ?? '')),
        },
  ];
}

String _kind(String name) =>
    companionSuffix.firstMatch(name)?.group(1)?.toLowerCase() ?? 'companion';

Map<String, Object?> _constructor(ConstructorElement ctor, ClassElement cls) {
  final unnamed = ctor.isDefaultConstructor || (ctor.name ?? 'new') == 'new';
  return {
    'name': unnamed ? cls.name : '${cls.name}.${ctor.name}',
    'params': [
      for (final param in ctor.formalParameters)
        if (param.name != 'key')
          {
            'name': param.name,
            'type': param.type.getDisplayString(),
            if (param.isRequiredNamed || param.isRequiredPositional)
              'required': true,
            if (param.defaultValueCode != null)
              'default': param.defaultValueCode,
            if (_paramDoc(param, cls) case final d?) 'doc': d,
          },
    ],
  };
}

// A `this.child` param carries no doc of its own; the doc lives on the field.
String? _paramDoc(FormalParameterElement param, ClassElement cls) {
  final doc = cls.fields
      .where((f) => f.name == param.name)
      .firstOrNull
      ?.documentationComment;
  return doc == null ? null : firstParagraph(strip(doc));
}

List<Map<String, Object?>> _enumValues(EnumElement e) => [
  for (final v in e.constants)
    {
      'value': v.name,
      if (v.documentationComment case final d?) 'doc': firstParagraph(strip(d)),
    },
];

// Reads the doc-site URLs straight from the dartdoc, so the frozen asset paths
// are reproduced exactly and secondary components without a preview get none.
Map<String, Object?> _urls(String doc) {
  final images = RegExp(
    r'<img\s+src="([^"]+)"',
  ).allMatches(doc).map((m) => m.group(1)!);
  final preview = {
    for (final url in images)
      if (url.contains('light.'))
        'light': url
      else if (url.contains('dark.'))
        'dark': url,
  };
  final docs = RegExp(
    r'https://fossui\.org/docs/[^)\s"]+',
  ).firstMatch(doc)?.group(0);
  final play = RegExp(
    r'https://play\.fossui\.org/[^)\s"]+',
  ).firstMatch(doc)?.group(0);
  return {
    if (docs != null) 'docs': docs,
    if (play != null) 'playground': play,
    if (preview.isNotEmpty) 'preview': preview,
  };
}
