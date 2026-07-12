import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';

/// Const-evaluates the six token families from their canonical instances and
/// maps each value to plain JSON. Colors carry a light and a dark instance; the
/// rest a single `standard`.
Map<String, Object?> extractTokens(List<ClassElement> classes) {
  ClassElement byName(String n) => classes.firstWhere((c) => c.name == n);
  return {
    'access': 'context.fossTheme',
    'colors': {
      'light': _instance(byName('FossColors'), 'light'),
      'dark': _instance(byName('FossColors'), 'dark'),
    },
    'radii': _instance(byName('FossRadii'), 'standard'),
    'spacing': _instance(byName('FossSpacing'), 'standard'),
    'typography': _instance(byName('FossTypography'), 'standard'),
    'shadows': _instance(byName('FossShadows'), 'standard'),
    'motion': _instance(byName('FossMotion'), 'standard'),
  };
}

// Evaluates the named static-const instance and maps each of its instance fields
// to a plain JSON value.
Map<String, Object?> _instance(ClassElement cls, String instance) {
  final obj = cls.fields
      .firstWhere((f) => f.name == instance)
      .computeConstantValue();
  final out = <String, Object?>{};
  for (final f in cls.fields) {
    if (f.isStatic || f.isSynthetic) continue;
    final value = _valueOrNull(obj?.getField(f.name!));
    if (value != null) out[f.name!] = value;
  }
  return out;
}

Object? _valueOrNull(DartObject? o) => o == null ? null : _value(o);

Object? _value(DartObject o) {
  if (o.toDoubleValue() case final d?) return d;
  if (o.toIntValue() case final i?) return i;
  if (o.toBoolValue() case final b?) return b;
  if (o.toStringValue() case final s?) return s;
  switch (o.type?.getDisplayString()) {
    case 'Color':
      return _hex(o);
    case 'Duration':
      return (o.getField('_duration')?.toIntValue() ?? 0) ~/ 1000;
    case 'FontWeight':
      return ((o.getField('index')?.toIntValue() ?? 0) + 1) * 100;
    case 'Offset':
      // dx/dy are getters over the private _dx/_dy backing fields.
      return {
        'dx': _field(o, '_dx')?.toDoubleValue(),
        'dy': _field(o, '_dy')?.toDoubleValue(),
      };
    case 'TextStyle':
      return _drop({
        'fontFamily': o.getField('fontFamily')?.toStringValue(),
        'fontSize': o.getField('fontSize')?.toDoubleValue(),
        'height': o.getField('height')?.toDoubleValue(),
        'letterSpacing': o.getField('letterSpacing')?.toDoubleValue(),
        'fontWeight': _valueOrNull(o.getField('fontWeight')),
      });
    case 'BoxShadow':
      // color/offset/blurRadius are inherited from Shadow; reach them through
      // the (super) chain since getField only surfaces the object's own fields.
      return _drop({
        'color': _hexOrNull(_field(o, 'color')),
        'offset': _valueOrNull(_field(o, 'offset')),
        'blur': _field(o, 'blurRadius')?.toDoubleValue(),
        'spread': _field(o, 'spreadRadius')?.toDoubleValue(),
      });
  }
  if (o.toListValue() case final list?) {
    return [for (final e in list) _value(e)];
  }
  return null;
}

String? _hexOrNull(DartObject? o) => o == null ? null : _hex(o);

// Rebuilds #AARRGGBB from the Color's floating-point channels (a/r/g/b in 0..1).
String _hex(DartObject color) {
  int ch(String f) => ((_field(color, f)?.toDoubleValue() ?? 0) * 255).round();
  final bytes = [ch('a'), ch('r'), ch('g'), ch('b')];
  return '#${bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';
}

// getField only exposes an object's own fields; follow the (super) chain to
// reach fields declared on a superclass.
DartObject? _field(DartObject o, String name) {
  final own = o.getField(name);
  if (own != null) return own;
  final sup = o.getField('(super)');
  return sup == null ? null : _field(sup, name);
}

Map<String, Object?> _drop(Map<String, Object?> m) => {
  for (final e in m.entries)
    if (e.value != null) e.key: e.value,
};
