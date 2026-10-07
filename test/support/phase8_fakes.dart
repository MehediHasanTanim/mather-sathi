import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:mather_sathi/core/analytics/analytics.dart';
import 'package:mather_sathi/core/l10n/gen/app_localizations.dart';
import 'package:mather_sathi/features/expert/expert_providers.dart';
import 'package:mather_sathi/features/privacy/data_deletion.dart';
import 'package:mather_sathi/features/share/share_content.dart';
import 'package:mather_sathi/features/share/share_service.dart';
import 'package:mather_sathi/features/sync/sync_service.dart';

class FakeDialer implements Dialer {
  final dialed = <String>[];
  bool works = true;
  @override
  Future<bool> dial(String number) async {
    dialed.add(number);
    return works;
  }
}

class FakeSharer implements Sharer {
  final shared = <({String text, Uint8List? png})>[];
  Object? throws;
  @override
  Future<void> share({required String text, Uint8List? png}) async {
    if (throws != null) throw throws!;
    shared.add((text: text, png: png));
  }
}

class FakeCardRenderer implements CardRenderer {
  FakeCardRenderer([this.png]);
  Uint8List? png;
  int renders = 0;
  @override
  Future<Uint8List?> render(BuildContext context, ShareContent content, AppLocalizations l) async {
    renders++;
    return png;
  }
}

class FakeRemoteEraser implements RemoteEraser {
  Object? throws;
  int calls = 0;
  void Function()? during;
  @override
  Future<void> deleteMyData() async {
    calls++;
    during?.call();
    if (throws != null) throw throws!;
  }
}

/// Records the order of suspend/resume so tests can prove sync is stopped for the whole deletion.
class RecordingSync implements SyncRunner {
  final log = <String>[];
  @override
  Future<void> flush() async => log.add('flush');
  @override
  Future<void> suspend() async => log.add('suspend');
  @override
  void resume() => log.add('resume');
}

class RecordingAnalytics implements Analytics {
  final events = <({String name, Map<String, Object> params})>[];
  @override
  void log(String name, [Map<String, Object> params = const {}]) => events.add((name: name, params: params));
  List<String> get names => [for (final e in events) e.name];
  Map<String, Object> only(String name) => events.singleWhere((e) => e.name == name).params;
}
