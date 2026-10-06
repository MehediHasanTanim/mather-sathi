import 'package:mather_sathi/core/flags/remote_flags.dart';
import 'package:mather_sathi/features/profile/data/profile_store.dart';
import 'package:mather_sathi/features/profile/domain/user_profile.dart';

class FakeProfileStore implements ProfileStore {
  FakeProfileStore([this.saved]);
  UserProfile? saved;

  @override
  Future<UserProfile?> load() async => saved;

  @override
  Future<void> save(UserProfile profile) async => saved = profile;
}

class FakeRemoteConfig implements RemoteConfigSource {
  FakeRemoteConfig({this.values = const {}, this.fails = false});
  final Map<String, Object?> values;
  final bool fails;

  @override
  Future<Map<String, Object?>> fetch() async {
    if (fails) throw Exception('offline');
    return values;
  }
}
