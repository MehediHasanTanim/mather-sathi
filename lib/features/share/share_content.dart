import '../../core/l10n/gen/app_localizations.dart';
import '../kb/domain/kb_models.dart';

/// What a shared diagnosis says. Every line comes from the reviewed KB entry (or the fixed UI strings), never from the
/// AI: the receiver may act on this text.
class ShareContent {
  const ShareContent({required this.title, required this.action, required this.medicine, required this.tagline, required this.disclaimer});

  final String title;
  final String? action; // first immediate step
  final String? medicine; // "name — dose", only for a published entry
  final String tagline;
  final String disclaimer;

  factory ShareContent.fromDisease(AppLocalizations l, Disease d) {
    final med = d.published && d.medicine.isNotEmpty ? d.medicine.first : null;
    return ShareContent(
      title: d.nameBn,
      action: d.immediateBn.isEmpty ? null : d.immediateBn.first,
      medicine: med == null ? null : '${med.nameBn} — ${med.doseBn}',
      tagline: l.shareCardTagline,
      disclaimer: l.aiDisclaimer,
    );
  }

  /// Plain text for WhatsApp and SMS.
  String toText(AppLocalizations l) => [
        '🌿 $title',
        if (action != null) '${l.shareActionLabel}: $action',
        if (medicine != null) '${l.medicineLabel}: $medicine',
        '',
        '⚠️ $disclaimer',
        '— $tagline',
      ].join('\n');
}
