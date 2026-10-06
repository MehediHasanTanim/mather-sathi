/// Local profile (single row). [district] is the district slug, [upazila] the upazila id (as text).
class UserProfile {
  const UserProfile({
    this.district,
    this.upazila,
    this.defaultCrop,
    this.shareReports = true,
    this.photoBackup = false,
    this.photoContribute = false,
    this.notifications = true,
    this.ttsSpeed = 'normal',
    this.onboardingDone = false,
  });

  /// Defaults per the consent spec: reports on, backup off, contribution off.
  static const initial = UserProfile();

  final String? district;
  final String? upazila;
  final String? defaultCrop;
  final bool shareReports;
  final bool photoBackup;
  final bool photoContribute;
  final bool notifications;
  final String ttsSpeed; // slow | normal | fast
  final bool onboardingDone;

  UserProfile copyWith({
    String? district,
    String? upazila,
    String? defaultCrop,
    bool? shareReports,
    bool? photoBackup,
    bool? photoContribute,
    bool? notifications,
    String? ttsSpeed,
    bool? onboardingDone,
  }) =>
      UserProfile(
        district: district ?? this.district,
        upazila: upazila ?? this.upazila,
        defaultCrop: defaultCrop ?? this.defaultCrop,
        shareReports: shareReports ?? this.shareReports,
        photoBackup: photoBackup ?? this.photoBackup,
        photoContribute: photoContribute ?? this.photoContribute,
        notifications: notifications ?? this.notifications,
        ttsSpeed: ttsSpeed ?? this.ttsSpeed,
        onboardingDone: onboardingDone ?? this.onboardingDone,
      );

  Map<String, Object?> toMap() => {
        'id': 1,
        'district': district,
        'upazila': upazila,
        'default_crop': defaultCrop,
        'share_reports': shareReports ? 1 : 0,
        'photo_backup': photoBackup ? 1 : 0,
        'photo_contribute': photoContribute ? 1 : 0,
        'notifications': notifications ? 1 : 0,
        'tts_speed': ttsSpeed,
        'onboarding_done': onboardingDone ? 1 : 0,
      };

  factory UserProfile.fromMap(Map<String, Object?> m) => UserProfile(
        district: m['district'] as String?,
        upazila: m['upazila'] as String?,
        defaultCrop: m['default_crop'] as String?,
        shareReports: m['share_reports'] != 0,
        photoBackup: m['photo_backup'] == 1,
        photoContribute: m['photo_contribute'] == 1,
        notifications: m['notifications'] != 0,
        ttsSpeed: (m['tts_speed'] as String?) ?? 'normal',
        onboardingDone: m['onboarding_done'] == 1,
      );

  @override
  bool operator ==(Object other) =>
      other is UserProfile && _mapEq(other.toMap(), toMap());

  @override
  int get hashCode => Object.hashAll(toMap().values);

  static bool _mapEq(Map<String, Object?> a, Map<String, Object?> b) =>
      a.length == b.length && a.keys.every((k) => a[k] == b[k]);
}
