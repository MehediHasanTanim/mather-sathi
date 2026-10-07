import 'package:characters/characters.dart';

/// The crop chosen before capture: one of the launch crops, or free-text "other".
class CropSelection {
  const CropSelection(this.id, {this.label});

  static const otherId = 'other';
  static const maxLabelLength = 40;

  /// KB crop id, or [otherId].
  final String id;

  /// Free-text crop name; only for [otherId].
  final String? label;

  bool get isOther => id == otherId;

  /// Crop parameter sent to the `diagnose` Function: a KB id, or `other:<text>`.
  String get param => isOther ? 'other:$label' : id;

  /// Non-empty (after trim) and at most [maxLabelLength] characters.
  static bool isValidLabel(String? text) {
    final t = text?.trim() ?? '';
    return t.isNotEmpty && t.characters.length <= maxLabelLength;
  }

  factory CropSelection.other(String label) {
    assert(isValidLabel(label));
    return CropSelection(otherId, label: label.trim());
  }

  @override
  bool operator ==(Object other) =>
      other is CropSelection && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}
