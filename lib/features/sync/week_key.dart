/// ISO-8601 week in Dhaka time (UTC+6), e.g. `2026-W41`. Part of the deterministic report id
/// `{uid}_{week}_{crop}_{disease}`, which makes an install report a given disease at most once per week.
String weekKey(DateTime t) {
  final d = t.toUtc().add(const Duration(hours: 6));
  final day = DateTime.utc(d.year, d.month, d.day);
  // The ISO week belongs to the year of its Thursday.
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final week = thursday.difference(DateTime.utc(thursday.year, 1, 1)).inDays ~/ 7 + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}
