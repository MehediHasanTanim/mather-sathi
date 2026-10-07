/// Opening hours of the helpline, from Remote Config (Design §11.4). Bangladesh has no daylight saving, so
/// Asia/Dhaka is always UTC+6 and no timezone database is needed.
class HelplineSchedule {
  const HelplineSchedule._(this._days, this._open, this._close);

  static const _dhaka = Duration(hours: 6);
  static const _names = {'mon': 1, 'tue': 2, 'wed': 3, 'thu': 4, 'fri': 5, 'sat': 6, 'sun': 7};

  final Set<int> _days; // DateTime.weekday values, 1 = Monday
  final int _open; // minutes after midnight, Dhaka time
  final int _close;

  /// `Sat,Sun,Mon 09:00-17:00` (day names are 3-letter English, case-insensitive). Null when it cannot be read:
  /// a wrong guess about opening hours is worse than showing none.
  static HelplineSchedule? parse(String text) {
    final m = RegExp(r'^\s*([A-Za-z]{3}(?:\s*,\s*[A-Za-z]{3})*)\s+(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})\s*$').firstMatch(text);
    if (m == null) return null;
    final days = <int>{};
    for (final d in m.group(1)!.split(',')) {
      final n = _names[d.trim().toLowerCase()];
      if (n == null) return null;
      days.add(n);
    }
    int minutes(String h, String mi) => int.parse(h) * 60 + int.parse(mi);
    final open = minutes(m.group(2)!, m.group(3)!);
    final close = minutes(m.group(4)!, m.group(5)!);
    if (open >= close || close > 24 * 60 || int.parse(m.group(3)!) > 59 || int.parse(m.group(5)!) > 59) return null;
    return HelplineSchedule._(days, open, close);
  }

  /// [instant] may be in any zone; it is converted to Dhaka time first.
  bool isOpenAt(DateTime instant) {
    final dhaka = instant.toUtc().add(_dhaka);
    if (!_days.contains(dhaka.weekday)) return false;
    final minute = dhaka.hour * 60 + dhaka.minute;
    return minute >= _open && minute < _close;
  }
}
