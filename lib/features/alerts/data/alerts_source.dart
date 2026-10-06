import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/alert.dart';

/// Feed window: alerts older than this expire from the feed (spec: 14 days).
const kAlertFeedDays = 14;
const kAlertFeedLimit = 20;

abstract interface class AlertsSource {
  Stream<List<Alert>> watch(String districtSlug);
}

/// Reads `alerts/` only (never raw `reports/`). Needs the composite index
/// (district ASC, visible ASC, lastReportAt DESC) from firebase/firestore.indexes.json.
class FirestoreAlertsSource implements AlertsSource {
  FirestoreAlertsSource([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  @override
  Stream<List<Alert>> watch(String districtSlug) {
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: kAlertFeedDays)),
    );
    return _db
        .collection('alerts')
        .where('district', isEqualTo: districtSlug)
        .where('visible', isEqualTo: true)
        .where('lastReportAt', isGreaterThan: cutoff)
        .orderBy('lastReportAt', descending: true)
        .limit(kAlertFeedLimit)
        .snapshots()
        .map(
          (s) => [
            for (final doc in s.docs)
              ?Alert.tryParse(doc.id, _plain(doc.data())),
          ],
        );
  }

  /// Firestore Timestamps become DateTimes so the domain stays Firebase-free.
  static Map<String, Object?> _plain(Map<String, dynamic> d) => {
    for (final e in d.entries)
      e.key: e.value is Timestamp ? (e.value as Timestamp).toDate() : e.value,
  };
}
