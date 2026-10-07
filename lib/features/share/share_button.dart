import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../kb/domain/kb_models.dart';
import 'share_content.dart';
import 'share_service.dart';
import '../../core/analytics/analytics.dart';

/// Shares the diagnosis as a card image plus text, through the system share sheet.
class ShareButton extends ConsumerStatefulWidget {
  const ShareButton({super.key, required this.disease});
  final Disease disease;

  @override
  ConsumerState<ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends ConsumerState<ShareButton> {
  bool _busy = false;

  Future<void> _share() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final content = ShareContent.fromDisease(l, widget.disease);
    Ev.shareTapped(ref.read(analyticsProvider));
    setState(() => _busy = true);
    try {
      final png = await ref.read(cardRendererProvider).render(context, content, l);
      await ref.read(sharerProvider).share(text: content.toText(l), png: png);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.shareFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return OutlinedButton.icon(
      key: const Key('share_button'),
      onPressed: _busy ? null : _share,
      icon: const Icon(Icons.share),
      label: Text(l.shareResult),
    );
  }
}
