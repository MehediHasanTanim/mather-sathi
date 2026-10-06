import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/alerts_source.dart';
import '../domain/alert.dart';

final alertsSourceProvider = Provider<AlertsSource>(
  (ref) => FirestoreAlertsSource(),
);

/// Live alerts for one district. Auto-disposes when the Alerts tab is not on screen.
final alertsProvider = StreamProvider.autoDispose.family<List<Alert>, String>(
  (ref, district) => ref.watch(alertsSourceProvider).watch(district),
);
