import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/firebase/anonymous_auth.dart';
import '../../../core/l10n/bn_numerals.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../crops/crop.dart';
import '../../expert/expert_screen.dart';
import '../../geo/data/districts_repository.dart';
import '../../geo/domain/district.dart';
import '../../geo/presentation/search_picker.dart';
import '../../history/providers/history_provider.dart';
import '../../kb/kb_provider.dart';
import '../../privacy/data_deletion.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../../tts/tts_controller.dart';
import '../providers/app_info.dart';

/// Everything the farmer controls (Feature 7). Each change is written to the profile at once, so it takes effect
/// immediately: the district switches the push topic, the speed is read by the next TTS playback.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _deleting = false;

  void _edit(UserProfile Function(UserProfile) f) => ref.read(profileProvider.notifier).change(f);

  Future<void> _pickDistrict(List<District> list) async {
    final l = AppLocalizations.of(context);
    final slug = await showSearchPicker<String>(context,
        title: l.selectDistrict,
        items: [for (final d in list) PickerItem(value: d.slug, labelBn: d.nameBn, labelEn: d.nameEn)]);
    if (slug == null || !mounted) return;
    final current = ref.read(profileProvider).value?.district;
    if (slug != current) {
      _edit((p) => p.copyWith(district: slug, clearUpazila: true)); // the old upazila belongs to the old district
      final district = list.firstWhere((d) => d.slug == slug);
      await _pickUpazila(district);
    }
  }

  Future<void> _pickUpazila(District district) async {
    final l = AppLocalizations.of(context);
    final id = await showSearchPicker<String>(context,
        title: l.selectUpazila,
        items: [for (final u in district.upazilas) PickerItem(value: '${u.id}', labelBn: u.nameBn, labelEn: u.nameEn)]);
    if (id != null) _edit((p) => p.copyWith(upazila: id));
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteConfirmTitle),
        content: Text(l.deleteConfirmBody),
        actions: [
          TextButton(key: const Key('delete_cancel'), onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(key: const Key('delete_confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(l.deleteConfirm)),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _deleting = true);
    String message;
    try {
      await ref.read(dataDeletionProvider).run();
      ref.invalidate(historyProvider);
      message = l.deleteDone;
    } on DeletionFailed {
      message = l.deleteFailed;
    }
    if (mounted) setState(() => _deleting = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = ref.watch(profileProvider).value ?? UserProfile.initial;
    final districts = ref.watch(districtsProvider).value ?? const <District>[];
    District? district;
    for (final d in districts) {
      if (d.slug == p.district) district = d;
    }
    final upazila = district?.upazilaById(p.upazila);
    final kbVersion = ref.watch(kbProvider).value?.version;

    Widget header(String text) => Padding(padding: const EdgeInsets.fromLTRB(0, 24, 0, 8), child: Text(text, style: t.titleMedium));

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          header(l.settingsSectionLocation),
          Card(
            child: ListTile(
              key: const Key('settings_district'),
              leading: const Icon(Icons.location_city),
              title: Text(district?.nameBn ?? l.selectDistrict),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: districts.isEmpty ? null : () => _pickDistrict(districts),
            ),
          ),
          Card(
            child: ListTile(
              key: const Key('settings_upazila'),
              leading: const Icon(Icons.place),
              title: Text(upazila?.nameBn ?? (district == null ? l.selectDistrictFirst : l.selectUpazila)),
              trailing: const Icon(Icons.arrow_drop_down),
              enabled: district != null,
              onTap: district == null ? null : () => _pickUpazila(district!),
            ),
          ),
          Text(l.settingsLocationHint, style: t.bodySmall),
          const SizedBox(height: 12),
          Text(l.selectCrop, style: t.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final id in kLaunchCropIds)
              ChoiceChip(
                key: Key('settings_crop_$id'),
                label: Text('${cropEmoji(id)} ${cropName(l, id)}'),
                selected: p.defaultCrop == id,
                onSelected: (_) => _edit((x) => x.copyWith(defaultCrop: id)),
              ),
          ]),
          header(l.settingsSectionPrivacy),
          SwitchListTile(
            key: const Key('settings_notifications'),
            title: Text(l.settingsNotifications),
            subtitle: Text(l.settingsNotificationsDesc),
            value: p.notifications,
            onChanged: (v) => _edit((x) => x.copyWith(notifications: v)),
          ),
          SwitchListTile(
            key: const Key('settings_reports'),
            title: Text(l.consentReports),
            subtitle: Text(l.consentReportsDesc),
            value: p.shareReports,
            onChanged: (v) => _edit((x) => x.copyWith(shareReports: v)),
          ),
          SwitchListTile(
            key: const Key('settings_backup'),
            title: Text(l.consentBackup),
            subtitle: Text(l.consentBackupDesc),
            value: p.photoBackup,
            onChanged: (v) => _edit((x) => x.copyWith(photoBackup: v)),
          ),
          SwitchListTile(
            key: const Key('settings_contribute'),
            title: Text(l.consentContribute),
            subtitle: Text(l.consentContributeDesc),
            value: p.photoContribute,
            onChanged: (v) => _edit((x) => x.copyWith(photoContribute: v)),
          ),
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('ℹ️ ${l.aiDisclosure}', style: t.bodySmall)),
          ListTile(
            key: const Key('settings_delete'),
            leading: const Icon(Icons.delete_outline),
            title: Text(l.deleteHistory),
            subtitle: Text(_deleting ? l.deleting : l.deleteHistoryDesc),
            enabled: !_deleting,
            trailing: _deleting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : null,
            onTap: _deleting ? null : _delete,
          ),
          header(l.settingsSectionVoice),
          Text(l.ttsSpeedLabel),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            key: const Key('settings_tts_speed'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'slow', label: Text(l.ttsSlow, key: const Key('tts_slow'))),
              ButtonSegment(value: 'normal', label: Text(l.ttsNormal, key: const Key('tts_normal'))),
              ButtonSegment(value: 'fast', label: Text(l.ttsFast, key: const Key('tts_fast'))),
            ],
            selected: {p.ttsSpeed},
            onSelectionChanged: (s) async {
              await ref.read(profileProvider.notifier).change((x) => x.copyWith(ttsSpeed: s.first));
              // Let the farmer hear the new speed right away.
              ref.read(ttsControllerProvider.notifier).speak(l.ttsTrySample);
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('settings_tts_try'),
              onPressed: () => ref.read(ttsControllerProvider.notifier).speak(l.ttsTrySample),
              icon: const Icon(Icons.volume_up),
              label: Text(l.ttsTry),
            ),
          ),
          header(l.expertTitle),
          ListTile(
            key: const Key('settings_expert'),
            leading: const Icon(Icons.call),
            title: Text(l.seeExpert),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(kExpertRoute),
          ),
          header(l.settingsSectionAbout),
          Text(l.aboutApp(ref.watch(appVersionProvider).value ?? '…'), key: const Key('about_app')),
          if (kbVersion != null) Text(l.aboutKb(kbVersion), key: const Key('about_kb')),
          if (kDebugMode) ...[
            const Divider(height: 32),
            Text(l.banglaCheckSample, key: const Key('bangla_sample'), style: t.bodyLarge),
            Text(l.banglaCheckDigits(formatBnNumber(1234567890)), style: t.bodyLarge),
            Text(toBnDigits('০১২৩৪৫৬৭৮৯ → 0123456789'), style: t.bodyLarge),
            Text(ref.watch(anonymousUidProvider).when(
                  data: (v) => 'uid: $v',
                  loading: () => 'signing in…',
                  error: (e, _) => 'sign-in failed: $e',
                )),
          ],
        ],
      ),
    );
  }
}
