import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/gen/app_localizations.dart';

const kGuidanceDuration = Duration(seconds: 3);

/// Pre-capture tips. Closes by itself after 3 s, or sooner when dismissed
/// (button, swipe or tap outside). Either way the caller continues to the camera.
Future<void> showGuidanceSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      builder: (_) => const _GuidanceSheet(),
    );

class _GuidanceSheet extends StatefulWidget {
  const _GuidanceSheet();

  @override
  State<_GuidanceSheet> createState() => _GuidanceSheetState();
}

class _GuidanceSheetState extends State<_GuidanceSheet> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(kGuidanceDuration, () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget row(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
          ]),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📸 ${l.guidanceTitle}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            row(Icons.check_circle, Colors.green, l.guidanceClose),
            row(Icons.check_circle, Colors.green, l.guidanceLight),
            row(Icons.check_circle, Colors.green, l.guidanceFrame),
            row(Icons.cancel, Colors.red, l.guidanceBlur),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(l.ok),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
