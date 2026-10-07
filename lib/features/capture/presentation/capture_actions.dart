import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/photo_picker.dart';
import '../providers/capture_provider.dart';
import 'guidance_sheet.dart';

const kPreviewRoute = '/capture/preview';

/// Guidance (camera only) → system camera or gallery → prepare. The picked
/// file goes to the provider, never through route arguments.
/// Set [pushPreview] to false when already on the preview screen (retake).
Future<void> startCapture(BuildContext context, WidgetRef ref, PhotoSource source,
    {bool pushPreview = true}) async {
  final notifier = ref.read(captureProvider.notifier);
  if (ref.read(captureProvider).selection == null) return;

  if (source == PhotoSource.camera) {
    await showGuidanceSheet(context);
    if (!context.mounted) return;
  }
  final file = await notifier.pick(source);
  if (file == null || !context.mounted) return;

  unawaited(notifier.prepare(file));
  if (pushPreview) unawaited(context.push(kPreviewRoute));
}
