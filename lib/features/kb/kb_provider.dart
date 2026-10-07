import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_reporter.dart';
import 'data/kb_repository.dart';
import 'data/kb_updater.dart';
import 'domain/kb_models.dart';

final kbRepositoryProvider =
    Provider<KbRepository>((ref) => KbRepository(reporter: ref.watch(errorReporterProvider)));

/// The loaded KB. Preloaded in `bootstrap()`; OTA updates (Phase 5+) will replace the state.
final kbProvider = AsyncNotifierProvider<KbNotifier, KnowledgeBase>(KbNotifier.new);

class KbNotifier extends AsyncNotifier<KnowledgeBase> {
  @override
  Future<KnowledgeBase> build() => ref.read(kbRepositoryProvider).load();
}

/// Dev builds may receive KBs that include draft entries; stg and prod never (overridden in bootstrap).
final allowDraftKbProvider = Provider<bool>((ref) => false);

final kbSourceProvider = Provider<KbSource>((ref) => FirebaseKbSource());

final kbUpdaterProvider = Provider<KbUpdater>((ref) => KbUpdater(
      source: ref.watch(kbSourceProvider),
      reporter: ref.watch(errorReporterProvider),
      currentSeq: () => ref.read(kbProvider).value?.seq ?? 0,
      allowDrafts: ref.watch(allowDraftKbProvider),
    ));

/// Checks for a newer KB and, if one was installed, reloads it so open screens show the new content.
Future<KbUpdateResult> updateKb(ProviderContainer container) async {
  final r = await container.read(kbUpdaterProvider).check();
  if (r == KbUpdateResult.updated) container.invalidate(kbProvider);
  return r;
}
