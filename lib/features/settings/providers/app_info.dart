import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// "version+build" of the installed app, for the About section.
final appVersionProvider = FutureProvider<String>((ref) async {
  final i = await PackageInfo.fromPlatform();
  return i.buildNumber.isEmpty ? i.version : '${i.version}+${i.buildNumber}';
});
