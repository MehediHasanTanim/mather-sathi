import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../capture/data/photo_picker.dart';
import '../../capture/domain/crop_selection.dart';
import '../../capture/presentation/capture_actions.dart';
import '../../capture/providers/capture_provider.dart';
import '../../crops/crop.dart';
import '../../update/app_update.dart';
import '../../weather/presentation/weather_banner.dart';

/// Crop selection (8 launch crops + "other") and the entry to capture.
class ScanHomeScreen extends ConsumerStatefulWidget {
  const ScanHomeScreen({super.key});

  @override
  ConsumerState<ScanHomeScreen> createState() => _ScanHomeScreenState();
}

class _ScanHomeScreenState extends ConsumerState<ScanHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumeLostPhoto());
  }

  /// If Android killed us while the system camera was open, continue with that photo.
  Future<void> _resumeLostPhoto() async {
    final notifier = ref.read(captureProvider.notifier);
    final file = await notifier.recoverLostPhoto();
    if (file == null || !mounted) return;
    unawaited(notifier.prepare(file));
    unawaited(context.push(kPreviewRoute));
  }

  Future<void> _pickOther() async {
    final label = await showDialog<String>(
      context: context,
      builder: (_) => const _OtherCropDialog(),
    );
    if (label != null) ref.read(captureProvider.notifier).selectOther(label);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selection = ref.watch(captureProvider.select((s) => s.selection));
    final notifier = ref.read(captureProvider.notifier);
    final canCapture = selection != null;

    return Scaffold(
      appBar: AppBar(title: Text(l.appName)),
      body: Column(
        children: [
          const UpdateBanner(),
          const WeatherBannerView(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l.selectCrop,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.4,
                  children: [
                    for (final id in kLaunchCropIds)
                      _CropTile(
                        key: Key('crop_$id'),
                        emoji: cropEmoji(id),
                        label: cropName(l, id),
                        selected: selection?.id == id,
                        onTap: () => notifier.selectCrop(id),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _CropTile(
                  key: const Key('crop_other'),
                  emoji: '🌱',
                  label: selection?.isOther == true
                      ? selection!.label!
                      : l.otherCrop,
                  selected: selection?.isOther == true,
                  onTap: _pickOther,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const Key('take_photo'),
                    onPressed: canCapture
                        ? () => startCapture(context, ref, PhotoSource.camera)
                        : null,
                    icon: const Icon(Icons.photo_camera),
                    label: Text(l.takePhoto),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('pick_gallery'),
                    onPressed: canCapture
                        ? () => startCapture(context, ref, PhotoSource.gallery)
                        : null,
                    icon: const Icon(Icons.photo_library),
                    label: Text(l.pickFromGallery),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CropTile extends StatelessWidget {
  const _CropTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtherCropDialog extends StatefulWidget {
  const _OtherCropDialog();

  @override
  State<_OtherCropDialog> createState() => _OtherCropDialogState();
}

class _OtherCropDialogState extends State<_OtherCropDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.otherCrop),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLength: CropSelection.maxLabelLength,
        decoration: InputDecoration(hintText: l.otherCropHint),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: CropSelection.isValidLabel(_c.text)
              ? () => Navigator.pop(context, _c.text.trim())
              : null,
          child: Text(l.ok),
        ),
      ],
    );
  }
}
