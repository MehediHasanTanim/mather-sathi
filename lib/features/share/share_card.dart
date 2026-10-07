import 'package:flutter/material.dart';

import '../../core/l10n/gen/app_localizations.dart';
import 'share_content.dart';

/// The picture that is shared. Fixed width so it looks the same on every phone, high contrast and large type so it
/// stays readable after WhatsApp compresses it.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.content, required this.labels});

  final ShareContent content;
  final AppLocalizations labels;

  static const width = 360.0;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1B5E20);
    return Container(
      key: const Key('share_card'),
      width: width,
      color: Colors.white,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: green,
          padding: const EdgeInsets.all(16),
          child: Text('🌿 ${content.title}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (content.action != null) ...[
              Text(labels.shareActionLabel, style: const TextStyle(color: green, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(content.action!, style: const TextStyle(color: Colors.black87, fontSize: 18)),
              const SizedBox(height: 12),
            ],
            if (content.medicine != null) ...[
              Text(labels.medicineLabel, style: const TextStyle(color: green, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(content.medicine!, style: const TextStyle(color: Colors.black87, fontSize: 18)),
              const SizedBox(height: 12),
            ],
            Text('⚠️ ${content.disclaimer}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ]),
        ),
        Container(
          color: const Color(0xFFE8F5E9),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(content.tagline, style: const TextStyle(color: green, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
