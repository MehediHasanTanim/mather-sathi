/// A regional outbreak alert written by the `aggregateReports` Function: at least 3 distinct installs reported
/// the same crop and disease in the same upazila in the same week.
class Alert {
  const Alert({
    required this.id,
    required this.district,
    required this.upazila,
    required this.crop,
    required this.diseaseId,
    required this.count,
    required this.lastReportAt,
  });

  final String id;
  final String district; // slug
  final String upazila; // upazila id as text
  final String crop;
  final String diseaseId;
  final int count;
  final DateTime lastReportAt;

  /// Builds an alert from a Firestore document's fields. Returns null for a malformed doc so one bad doc never breaks the feed.
  static Alert? tryParse(String id, Map<String, Object?> d) {
    final last = d['lastReportAt'];
    final count = d['count'];
    if (d['district'] is! String ||
        d['upazila'] is! String ||
        d['crop'] is! String ||
        d['diseaseId'] is! String)
      return null;
    if (count is! int || last is! DateTime) return null;
    return Alert(
      id: id,
      district: d['district']! as String,
      upazila: d['upazila']! as String,
      crop: d['crop']! as String,
      diseaseId: d['diseaseId']! as String,
      count: count,
      lastReportAt: last,
    );
  }
}
