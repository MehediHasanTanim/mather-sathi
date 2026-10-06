import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import 'tts_controller.dart';

/// 📢 শুনুন, with pause/resume/stop while playing. [script] is built lazily on tap.
class ListenButton extends ConsumerWidget {
  const ListenButton({super.key, required this.script});
  final String Function() script;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final status = ref.watch(ttsControllerProvider);
    final tts = ref.read(ttsControllerProvider.notifier);

    ref.listen(ttsControllerProvider, (_, next) {
      if (next == TtsStatus.unavailable) {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(l.ttsUnavailableTitle),
            content: Text(l.ttsUnavailableBody),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.ok))],
          ),
        ).then((_) => tts.acknowledgeUnavailable());
      }
    });

    return switch (status) {
      TtsStatus.speaking => Row(mainAxisSize: MainAxisSize.min, children: [
          FilledButton.icon(
            key: const Key('tts_pause'),
            onPressed: tts.pause,
            icon: const Icon(Icons.pause),
            label: Text(l.pauseListening),
          ),
          IconButton(key: const Key('tts_stop'), tooltip: l.stopListening, onPressed: tts.stop, icon: const Icon(Icons.stop)),
        ]),
      TtsStatus.paused => Row(mainAxisSize: MainAxisSize.min, children: [
          FilledButton.icon(
            key: const Key('tts_resume'),
            onPressed: tts.resume,
            icon: const Icon(Icons.play_arrow),
            label: Text(l.resumeListening),
          ),
          IconButton(key: const Key('tts_stop'), tooltip: l.stopListening, onPressed: tts.stop, icon: const Icon(Icons.stop)),
        ]),
      _ => FilledButton.icon(
          key: const Key('tts_listen'),
          onPressed: () => tts.speak(script()),
          icon: const Icon(Icons.volume_up),
          label: Text('📢 ${l.listen}'),
        ),
    };
  }
}
