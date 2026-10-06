import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../crops/crop.dart';
import '../../geo/data/districts_repository.dart';
import '../../geo/domain/district.dart';
import '../../geo/presentation/search_picker.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/onboarding_draft.dart';

const _setupPage = 4;
const _consentPage = 5;
const _pageCount = 6;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) => _controller.animateToPage(page,
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  Future<void> _finish() async {
    setState(() => _saving = true);
    final chosen = ref.read(onboardingDraftProvider).toProfile();
    await ref.read(profileProvider.notifier).completeOnboarding(chosen);
    // The router redirect moves us to the home tab once the profile says done.
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final draft = ref.watch(onboardingDraftProvider);
    final canNext = _page != _setupPage || draft.locationAndCropChosen;
    final last = _page == _consentPage;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                // Setup is gated by "Next"; swiping past it would skip the required choices.
                physics: _page >= _setupPage
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                children: [
                  _Slide(icon: Icons.agriculture, text: l.onboardingSlide1),
                  _Slide(icon: Icons.photo_camera, text: l.onboardingSlide2),
                  _Slide(icon: Icons.record_voice_over, text: l.onboardingSlide3),
                  _Slide(icon: Icons.location_on, text: l.onboardingSlide4),
                  const _SetupPage(),
                  const _ConsentPage(),
                ],
              ),
            ),
            _Dots(count: _pageCount, index: _page),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_page > 0)
                    OutlinedButton(
                      onPressed: _saving ? null : () => _go(_page - 1),
                      child: Text(l.back),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: !canNext || _saving
                        ? null
                        : (last ? _finish : () => _go(_page + 1)),
                    child: Text(last ? l.start : l.next),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 96, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 32),
            Text(text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              margin: const EdgeInsets.all(4),
              width: i == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: i == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
        ],
      );
}

class _SetupPage extends ConsumerWidget {
  const _SetupPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);
    final districts = ref.watch(districtsProvider);

    return districts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l.loadError)),
      data: (list) {
        District? district;
        for (final d in list) {
          if (d.slug == draft.districtSlug) district = d;
        }
        final upazila = district?.upazilaById(draft.upazilaId);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.onboardingSlide4, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _PickerTile(
              key: const Key('pick_district'),
              icon: Icons.location_city,
              label: district?.nameBn ?? l.selectDistrict,
              onTap: () async {
                final slug = await showSearchPicker<String>(context,
                    title: l.selectDistrict,
                    items: [
                      for (final d in list)
                        PickerItem(value: d.slug, labelBn: d.nameBn, labelEn: d.nameEn),
                    ]);
                if (slug != null) notifier.selectDistrict(slug);
              },
            ),
            _PickerTile(
              key: const Key('pick_upazila'),
              icon: Icons.place,
              label: upazila?.nameBn ??
                  (district == null ? l.selectDistrictFirst : l.selectUpazila),
              onTap: district == null
                  ? null
                  : () async {
                      final id = await showSearchPicker<String>(context,
                          title: l.selectUpazila,
                          items: [
                            for (final u in district!.upazilas)
                              PickerItem(
                                  value: '${u.id}', labelBn: u.nameBn, labelEn: u.nameEn),
                          ]);
                      if (id != null) notifier.selectUpazila(id);
                    },
            ),
            const SizedBox(height: 16),
            Text(l.selectCrop, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in kLaunchCropIds)
                  ChoiceChip(
                    key: Key('crop_$id'),
                    label: Text('${cropEmoji(id)} ${cropName(l, id)}'),
                    selected: draft.crop == id,
                    onSelected: (_) => notifier.selectCrop(id),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({super.key, required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          minVerticalPadding: 16,
          leading: Icon(icon),
          title: Text(label),
          trailing: const Icon(Icons.arrow_drop_down),
          enabled: onTap != null,
          onTap: onTap,
        ),
      );
}

class _ConsentPage extends ConsumerWidget {
  const _ConsentPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final draft = ref.watch(onboardingDraftProvider);
    final n = ref.read(onboardingDraftProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.consentTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        // Disclosure is information, not a toggle (Design §11.2).
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 12),
                Expanded(child: Text(l.aiDisclosure, key: const Key('ai_disclosure'))),
              ],
            ),
          ),
        ),
        SwitchListTile(
          key: const Key('consent_reports'),
          title: Text(l.consentReports),
          subtitle: Text(l.consentReportsDesc),
          value: draft.shareReports,
          onChanged: n.setShareReports,
        ),
        SwitchListTile(
          key: const Key('consent_backup'),
          title: Text(l.consentBackup),
          subtitle: Text(l.consentBackupDesc),
          value: draft.photoBackup,
          onChanged: n.setPhotoBackup,
        ),
        SwitchListTile(
          key: const Key('consent_contribute'),
          title: Text(l.consentContribute),
          subtitle: Text(l.consentContributeDesc),
          value: draft.photoContribute,
          onChanged: n.setPhotoContribute,
        ),
      ],
    );
  }
}
