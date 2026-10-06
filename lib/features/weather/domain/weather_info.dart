enum RiskLevel { watch, high }

/// One crop's warning from the `refreshWeather` Function. The text is written and owned by the agronomist.
class WeatherRisk {
  const WeatherRisk({
    required this.crop,
    required this.level,
    required this.messageBn,
  });
  final String crop;
  final RiskLevel level;
  final String messageBn;
}

/// The cached outlook for a district: `weather/{slug}`.
class WeatherInfo {
  const WeatherInfo({required this.fetchedAt, required this.risks});
  final DateTime fetchedAt;
  final List<WeatherRisk> risks;

  /// Builds from a Firestore doc's fields; null when the doc is not usable. Malformed risks are skipped.
  static WeatherInfo? tryParse(Map<String, Object?> d) {
    final at = d['fetchedAt'];
    if (at is! DateTime) return null;
    final risks = <WeatherRisk>[];
    for (final r in (d['risks'] as List? ?? const [])) {
      if (r is! Map) continue;
      final level = switch (r['level']) {
        'watch' => RiskLevel.watch,
        'high' => RiskLevel.high,
        _ => null,
      };
      final crop = r['crop'];
      final msg = r['message_bn'];
      if (level != null && crop is String && msg is String && msg.isNotEmpty) {
        risks.add(WeatherRisk(crop: crop, level: level, messageBn: msg));
      }
    }
    return WeatherInfo(fetchedAt: at, risks: risks);
  }

  /// The risk that applies to [crop], if any.
  WeatherRisk? forCrop(String? crop) =>
      risks.where((r) => r.crop == crop).firstOrNull;
}
