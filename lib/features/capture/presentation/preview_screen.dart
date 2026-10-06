import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../crops/crop.dart';
import '../../diagnosis/domain/image_issue.dart';
import '../data/photo_picker.dart';
import '../providers/capture_provider.dart';
import '../../diagnosis/presentation/diagnosis_result_screen.dart';
import '../../diagnosis/providers/diagnosis_providers.dart';
import 'capture_actions.dart';

/// Shows the prepared photo, or a specific tip and a retake button.
class PreviewScreen extends ConsumerWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(captureProvider);
    final selection = state.selection;
    final cropLabel = selection == null
        ? ''
        : (selection.isOther ? selection.label! : cropName(l, selection.id));

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(captureProvider.notifier).reset();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l.previewTitle)),
        body: SafeArea(
          child: switch (state.status) {
            CaptureStatus.preparing => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l.preparing),
                ]),
              ),
            CaptureStatus.ready => _Ready(
                jpeg: state.prepared!.jpeg!,
                cropLabel: cropLabel,
                onAnalyze: () {
                  ref.read(diagnosisFlowProvider.notifier).submit(state.prepared!.jpeg!, selection!);
                  context.push(kDiagnosisRoute);
                },
                onRetake: () => startCapture(context, ref, PhotoSource.camera, pushPreview: false),
              ),
            CaptureStatus.retake => _Retake(
                tip: issueTip(l, state.prepared!.issue, cropLabel),
                onCamera: () => startCapture(context, ref, PhotoSource.camera, pushPreview: false),
                onGallery: () => startCapture(context, ref, PhotoSource.gallery, pushPreview: false),
              ),
            CaptureStatus.failed || CaptureStatus.idle => _Retake(
                tip: l.pickError,
                onCamera: () => startCapture(context, ref, PhotoSource.camera, pushPreview: false),
                onGallery: () => startCapture(context, ref, PhotoSource.gallery, pushPreview: false),
              ),
          },
        ),
      ),
    );
  }
}

/// One specific Bangla tip per issue.
String issueTip(AppLocalizations l, ImageIssue issue, String cropLabel) => switch (issue) {
      ImageIssue.blurry => l.tipBlurry,
      ImageIssue.tooDark => l.tipTooDark,
      ImageIssue.tooSmall => l.tipTooSmall,
      ImageIssue.notAPlant => l.tipNotAPlant,
      ImageIssue.wrongCrop => l.tipWrongCrop(cropLabel),
      ImageIssue.none => '',
    };

class _Ready extends StatelessWidget {
  const _Ready({required this.jpeg, required this.cropLabel, required this.onRetake, required this.onAnalyze});
  final Uint8List jpeg;
  final String cropLabel;
  final VoidCallback onRetake;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(jpeg, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
        ),
        Chip(label: Text(cropLabel)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('retake'),
                onPressed: onRetake,
                icon: const Icon(Icons.refresh),
                label: Text(l.retake),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: const Key('analyze'),
                onPressed: onAnalyze,
                icon: const Icon(Icons.search),
                label: Text(l.analyze),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _Retake extends StatelessWidget {
  const _Retake({required this.tip, required this.onCamera, required this.onGallery});
  final String tip;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.warning_amber_rounded, size: 72, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(tip,
              key: const Key('retake_tip'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 32),
          FilledButton.icon(
            key: const Key('retake_camera'),
            onPressed: onCamera,
            icon: const Icon(Icons.photo_camera),
            label: Text(l.retake),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('retake_gallery'),
            onPressed: onGallery,
            icon: const Icon(Icons.photo_library),
            label: Text(l.pickFromGallery),
          ),
        ],
      ),
    );
  }
}
