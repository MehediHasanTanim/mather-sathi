import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../domain/user_profile.dart';

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);

class ProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async =>
      await ref.read(profileStoreProvider).load() ?? UserProfile.initial;

  Future<void> change(UserProfile Function(UserProfile) edit) async {
    final next = edit(state.value ?? UserProfile.initial);
    await ref.read(profileStoreProvider).save(next);
    state = AsyncData(next);
  }

  /// Saves the onboarding choices and flips `onboardingDone`, which lets the router leave onboarding.
  Future<void> completeOnboarding(UserProfile chosen) =>
      change((_) => chosen.copyWith(onboardingDone: true));
}
