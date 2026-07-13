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
    'constructors': _constructors(cls),
    if (_ownedEnums(cls, api) case final e when e.isNotEmpty) 'enums': e,
    if (_ownedCompanions(cls, api) case final c when c.isNotEmpty)
      'companions': c,
    if (_ownedFunctions(cls, api) case final f when f.isNotEmpty)
      'functions': f,
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
      if (_owns(name, c.name!, api.primaryNames)) _companion(c, _kind(c.name!)),
    for (final o in api.orphanItems)
      if (name != o.name && name.startsWith(o.name!)) _companion(o, 'item'),
  ];
}

// A companion record: its summary plus the constructors an agent must call to
// build it, so a group, item, style, or controller is never a guess.
Map<String, Object?> _companion(ClassElement cls, String kind) => {
  'name': cls.name,
  'kind': kind,
  'summary': firstParagraph(strip(cls.documentationComment ?? '')),
  if (_constructors(cls) case final ctors when ctors.isNotEmpty)
    'constructors': ctors,
};

String _kind(String name) =>
    companionSuffix.firstMatch(name)?.group(1)?.toLowerCase() ?? 'companion';

// The component a top-level function belongs to: the longest component name its
// own name contains, so showFossAlertDialog binds to FossAlertDialog over
// FossDialog. A launcher like showFossModal matches no component and is unowned.
String? functionOwner(String fnName, List<String> primaryNames) {
  final f = fnName.toLowerCase();
  String? best;
  for (final p in primaryNames) {
    if (f.contains(p.toLowerCase()) &&
        (best == null || p.length > best.length)) {
      best = p;
    }
  }
  return best;
}

List<Map<String, Object?>> _ownedFunctions(ClassElement cls, ApiSurface api) => [
  for (final fn in api.functions)
    if (functionOwner(fn.name!, api.primaryNames) == cls.name)
      functionRecord(fn),
];

/// The callable shape of a top-level function: its name, return type, and
/// params, so an overlay launcher is documented like a constructor.
Map<String, Object?> functionRecord(TopLevelFunctionElement fn) => {
  'name': fn.name,
  'returns': fn.returnType.getDisplayString(),
  'params': _params(fn.formalParameters, null),
};

List<Map<String, Object?>> _constructors(ClassElement cls) => [
  for (final ctor in cls.constructors)
    if (ctor.isPublic) _constructor(ctor, cls),
];

Map<String, Object?> _constructor(ConstructorElement ctor, ClassElement cls) {
  final unnamed = ctor.isDefaultConstructor || (ctor.name ?? 'new') == 'new';
  return {
    'name': unnamed ? cls.name : '${cls.name}.${ctor.name}',
    'params': _params(ctor.formalParameters, cls),
  };
}

// The shared param shape for a constructor or a function. [cls] carries the
// field docs a `this.x` param inherits; a top-level function passes null.
List<Map<String, Object?>> _params(
  List<FormalParameterElement> params,
  ClassElement? cls,
) => [
  for (final param in params)
    if (param.name != 'key')
      {
        'name': param.name,
        'type': param.type.getDisplayString(),
        if (param.isRequiredNamed || param.isRequiredPositional) 'required': true,
        if (param.defaultValueCode != null) 'default': param.defaultValueCode,
        if (_docFor(param, cls) case final d?) 'doc': d,
      },
];

String? _docFor(FormalParameterElement param, ClassElement? cls) =>
    cls == null ? null : _paramDoc(param, cls);

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
