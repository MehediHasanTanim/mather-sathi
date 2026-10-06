import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../geo/presentation/search_picker.dart';
import '../../history/domain/diagnosis_record.dart';
import '../../history/providers/history_provider.dart';
import '../../kb/domain/kb_models.dart';

/// "ফলাফলটি কি সঠিক ছিল?" 👍/👎. A 👎 optionally asks for the real disease from this crop's list.
class FeedbackRow extends ConsumerWidget {
  const FeedbackRow({super.key, required this.record, required this.kb});
  final DiagnosisRecord record;
  final KnowledgeBase? kb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final notifier = ref.read(historyProvider.notifier);
    final given = record.feedback;

    Widget choice({required Key key, required String emoji, required String label, required bool selected, required VoidCallback onTap}) =>
        ChoiceChip(key: key, label: Text('$emoji $label'), selected: selected, onSelected: (_) => onTap());

    Future<void> wrong() async {
      final options = [
        for (final d in kb?.forCrop(record.cropType) ?? const <Disease>[]) PickerItem<String>(value: d.id, labelBn: d.nameBn),
        PickerItem<String>(value: '', labelBn: l.dontKnow),
      ];
      final picked = await showSearchPicker<String>(context, title: l.whatWasIt, items: options);
      // Dismissing the sheet still records "incorrect"; the real disease is optional.
      await notifier.setFeedback(record.id, correct: false, actual: (picked == null || picked.isEmpty) ? null : picked);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.wasCorrect, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          choice(
            key: const Key('feedback_yes'), emoji: '👍', label: l.yes, selected: given == 'correct',
            onTap: () => notifier.setFeedback(record.id, correct: true),
          ),
          choice(key: const Key('feedback_no'), emoji: '👎', label: l.no, selected: given == 'incorrect', onTap: wrong),
        ]),
        if (given != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.feedbackThanks, key: const Key('feedback_thanks'))),
      ],
    );
  }
}
