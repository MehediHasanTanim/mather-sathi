import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_reporter.dart';
import 'data/kb_repository.dart';
import 'domain/kb_models.dart';

final kbRepositoryProvider =
    Provider<KbRepository>((ref) => KbRepository(reporter: ref.watch(errorReporterProvider)));

/// The loaded KB. Preloaded in `bootstrap()`; OTA updates (Phase 5+) will replace the state.
final kbProvider = AsyncNotifierProvider<KbNotifier, KnowledgeBase>(KbNotifier.new);

class KbNotifier extends AsyncNotifier<KnowledgeBase> {
  @override
  Future<KnowledgeBase> build() => ref.read(kbRepositoryProvider).load();
}
