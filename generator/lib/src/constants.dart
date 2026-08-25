/// The single import consumers use, stamped on the manifest and every component.
const packageImport = 'package:fossui/fossui.dart';

/// Known categories in display order. Anything a component declares outside
/// this list still renders, after these, so a new category cannot go missing.
const categoryOrder = [
  'Inputs',
  'Feedback',
  'Overlays',
  'Layout',
  'Typography',
];
