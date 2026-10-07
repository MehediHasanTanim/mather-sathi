import 'package:intl/intl.dart';

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

/// Replaces ASCII digits in [input] with Bangla digits.
String toBnDigits(String input) => input.replaceAllMapped(
      RegExp('[0-9]'),
      (m) => _bnDigits[int.parse(m[0]!)],
    );

/// Formats [n] with the `bn` locale (Bangla digits, no grouping surprises).
/// Requires no date-formatting init: number symbols are bundled with intl.
String formatBnNumber(num n) => NumberFormat.decimalPattern('bn').format(n);

/// e.g. `৬ অক্টোবর ২০২৬`. Falls back to `৬/১০/২০২৬` if the `bn` date data was not initialised.
String formatBnDate(DateTime d) {
  try {
    return DateFormat('d MMMM yyyy', 'bn').format(d);
  } catch (_) {
    return toBnDigits('${d.day}/${d.month}/${d.year}');
  }
}
