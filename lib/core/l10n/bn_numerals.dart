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
