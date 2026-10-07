import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/gen/app_localizations.dart';
import 'share_card.dart';
import 'share_content.dart';

/// The system share sheet; faked in tests.
abstract interface class Sharer {
  Future<void> share({required String text, Uint8List? png});
}

class SharePlusSharer implements Sharer {
  @override
  Future<void> share({required String text, Uint8List? png}) async {
    await SharePlus.instance.share(ShareParams(
      text: text,
      files: png == null ? null : [XFile.fromData(png, mimeType: 'image/png', name: 'krishi_sahay.png')],
    ));
  }
}

final sharerProvider = Provider<Sharer>((ref) => SharePlusSharer());

/// Renders the card off-screen. Null when rendering fails: the text alone is still worth sharing.
abstract interface class CardRenderer {
  Future<Uint8List?> render(BuildContext context, ShareContent content, AppLocalizations l);
}

class ScreenshotCardRenderer implements CardRenderer {
  @override
  Future<Uint8List?> render(BuildContext context, ShareContent content, AppLocalizations l) async {
    try {
      return await ScreenshotController().captureFromLongWidget(
        // Carries the app theme (Bangla font) into the off-screen tree.
        InheritedTheme.captureAll(context, Material(child: ShareCard(content: content, labels: l))),
        context: context,
        pixelRatio: 3,
        constraints: const BoxConstraints(maxWidth: ShareCard.width),
        delay: const Duration(milliseconds: 50),
      );
    } catch (_) {
      return null;
    }
  }
}

final cardRendererProvider = Provider<CardRenderer>((ref) => ScreenshotCardRenderer());
