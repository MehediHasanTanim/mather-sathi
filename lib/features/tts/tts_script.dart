import '../../core/l10n/gen/app_localizations.dart';
import '../kb/domain/kb_models.dart';

final _emoji = RegExp('[\u{1F300}-\u{1FAFF}☀-➿️‍]', unicode: true);

/// Removes emoji and symbols the TTS engine would read aloud by name.
String cleanForSpeech(String s) => s.replaceAll(_emoji, '').replaceAll(RegExp(r'\s+'), ' ').trim();

String _sentence(String t) {
  final s = cleanForSpeech(t);
  if (s.isEmpty) return '';
  return RegExp(r'[।.?!]$').hasMatch(s) ? s : '$s।';
}

String _join(Iterable<String> parts) => parts.map(_sentence).where((s) => s.isNotEmpty).join(' ');

/// Spec 3.2 template: name, description, immediate actions, medicine + dose + interval, safety line.
/// Medicine is read only for reviewed (published) entries, and the safety line only when a medicine is read.
String buildDiseaseScript(AppLocalizations l, Disease d) {
  final immediate = d.immediateBn.take(2).toList();
  final med = d.published && d.medicine.isNotEmpty ? d.medicine.first : null;
  return _join([
    '${l.ttsDiseaseName}: ${d.nameBn}',
    d.descriptionBn,
    if (immediate.isNotEmpty) '${l.ttsImmediate}: ${immediate.map(_sentence).join(' ')}',
    if (med != null) '${l.medicineLabel}: ${med.nameBn}। ${l.doseLabel}: ${med.doseBn}',
    if (med != null) med.intervalBn,
    if (med != null) l.safetyLine,
  ]);
}

String buildMessageScript(String message, [List<String> extra = const []]) => _join([message, ...extra]);

/// Engines cap utterance length; split on sentence ends and pack sentences up to [maxLen].
List<String> splitSentences(String text, {int maxLen = 300}) {
  final pieces = <String>[];
  for (final m in RegExp(r'[^।.?!\n]+[।.?!]?').allMatches(text)) {
    final s = m.group(0)!.trim();
    if (s.isEmpty) continue;
    if (s.length <= maxLen) {
      pieces.add(s);
    } else {
      var cur = '';
      for (final w in s.split(' ')) {
        if (cur.isNotEmpty && cur.length + 1 + w.length > maxLen) {
          pieces.add(cur);
          cur = w;
        } else {
          cur = cur.isEmpty ? w : '$cur $w';
        }
      }
      if (cur.isNotEmpty) pieces.add(cur);
    }
  }
  final chunks = <String>[];
  for (final s in pieces) {
    if (chunks.isNotEmpty && chunks.last.length + 1 + s.length <= maxLen) {
      chunks[chunks.length - 1] = '${chunks.last} $s';
    } else {
      chunks.add(s);
    }
  }
  return chunks;
}
