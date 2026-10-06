import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/domain/user_profile.dart';

/// Choices made during onboarding; written to the profile on completion.
class OnboardingDraft {
  const OnboardingDraft({
    this.districtSlug,
    this.upazilaId,
    this.crop,
    this.shareReports = true,
    this.photoBackup = false,
    this.photoContribute = false,
  });

  final String? districtSlug;
  final String? upazilaId;
  final String? crop;
  final bool shareReports;
  final bool photoBackup;
  final bool photoContribute;

  bool get locationAndCropChosen =>
      districtSlug != null && upazilaId != null && crop != null;

  OnboardingDraft copyWith({
    String? districtSlug,
    String? upazilaId,
    bool clearUpazila = false,
    String? crop,
    bool? shareReports,
    bool? photoBackup,
    bool? photoContribute,
  }) =>
      OnboardingDraft(
        districtSlug: districtSlug ?? this.districtSlug,
        upazilaId: clearUpazila ? null : (upazilaId ?? this.upazilaId),
        crop: crop ?? this.crop,
        shareReports: shareReports ?? this.shareReports,
        photoBackup: photoBackup ?? this.photoBackup,
        photoContribute: photoContribute ?? this.photoContribute,
      );

  UserProfile toProfile() => UserProfile(
        district: districtSlug,
        upazila: upazilaId,
        defaultCrop: crop,
        shareReports: shareReports,
        photoBackup: photoBackup,
        photoContribute: photoContribute,
      );
}

final onboardingDraftProvider =
    NotifierProvider.autoDispose<OnboardingDraftNotifier, OnboardingDraft>(
        OnboardingDraftNotifier.new);

class OnboardingDraftNotifier extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  /// Picking a different district clears the upazila, which belonged to the old one.
  void selectDistrict(String slug) {
    if (slug == state.districtSlug) return;
    state = state.copyWith(districtSlug: slug, clearUpazila: true);
  }

  void selectUpazila(String id) => state = state.copyWith(upazilaId: id);
  void selectCrop(String id) => state = state.copyWith(crop: id);
  void setShareReports(bool v) => state = state.copyWith(shareReports: v);
  void setPhotoBackup(bool v) => state = state.copyWith(photoBackup: v);
  void setPhotoContribute(bool v) => state = state.copyWith(photoContribute: v);
}
