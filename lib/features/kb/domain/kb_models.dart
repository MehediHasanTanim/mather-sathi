import 'dart:convert';

enum Urgency { high, medium, low }

class Medicine {
  const Medicine({
    required this.nameBn,
    required this.activeIngredient,
    required this.doseBn,
    required this.intervalBn,
    this.preHarvestIntervalDays,
  });

  final String nameBn;
  final String activeIngredient;
  final String doseBn;
  final String intervalBn;
  final int? preHarvestIntervalDays;

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
        nameBn: _str(j, 'name_bn'),
        activeIngredient: _str(j, 'active_ingredient'),
        doseBn: _str(j, 'dose_bn'),
        intervalBn: _str(j, 'interval_bn'),
        preHarvestIntervalDays: j['pre_harvest_interval_days'] as int?,
      );
}

/// One KB entry: the only source of disease names, symptoms, treatment and doses the farmer sees.
class Disease {
  const Disease({
    required this.id,
    required this.crop,
    required this.published,
    required this.nameBn,
    required this.descriptionBn,
    required this.symptomsBn,
    required this.causeBn,
    required this.urgency,
    required this.immediateBn,
    required this.medicine,
    required this.preventionBn,
    required this.seeExpert,
  });

  final String id;
  final String crop;
  final bool published;
  final String nameBn;
  final String descriptionBn;
  final List<String> symptomsBn;
  final String causeBn;
  final Urgency urgency;
  final List<String> immediateBn;
  final List<Medicine> medicine;
  final List<String> preventionBn;
  final bool seeExpert;

  factory Disease.fromJson(Map<String, dynamic> j) => Disease(
        id: _str(j, 'id'),
        crop: _str(j, 'crop'),
        published: _str(j, 'status') == 'published',
        nameBn: _str(j, 'name_bn'),
        descriptionBn: _str(j, 'description_bn'),
        symptomsBn: _strList(j, 'symptoms_bn'),
        causeBn: _str(j, 'cause_bn'),
        urgency: _urgency(_str(j, 'urgency')),
        immediateBn: _strList(j, 'immediate_bn'),
        medicine: [
          for (final m in _list(j, 'medicine')) Medicine.fromJson(m as Map<String, dynamic>),
        ],
        preventionBn: _strList(j, 'prevention_bn'),
        seeExpert: _bool(j, 'see_expert'),
      );
}

Urgency _urgency(String v) {
  final u = Urgency.values.asNameMap()[v];
  if (u == null) throw FormatException('unknown urgency "$v"');
  return u;
}

String _str(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is String) return v;
  throw FormatException('missing or invalid "$k"');
}

bool _bool(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is bool) return v;
  throw FormatException('missing or invalid "$k"');
}

List<dynamic> _list(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is List) return v;
  throw FormatException('missing or invalid "$k"');
}

List<String> _strList(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is List && v.every((e) => e is String)) return v.cast<String>();
  throw FormatException('missing or invalid "$k"');
}

class KbFormatException implements Exception {
  const KbFormatException(this.message);
  final String message;
  @override
  String toString() => 'KbFormatException: $message';
}

class KnowledgeBase {
  KnowledgeBase({
    required this.version,
    required this.seq,
    required this.schema,
    required this.includesDrafts,
    required List<Disease> diseases,
  }) : _byId = {for (final d in diseases) d.id: d};

  /// Highest KB schema this app understands; a newer KB is refused (the app needs updating).
  static const supportedSchema = 1;

  final String version;

  /// Monotonic; used to compare KB versions.
  final int seq;
  final int schema;

  /// True for dev builds that include unreviewed draft entries.
  final bool includesDrafts;
  final Map<String, Disease> _byId;

  Disease? operator [](String id) => _byId[id];
  Iterable<Disease> get all => _byId.values;
  Iterable<Disease> forCrop(String crop) => _byId.values.where((d) => d.crop == crop);
  bool supportsCrop(String crop) => _byId.values.any((d) => d.crop == crop);

  /// Throws [KbFormatException] on anything unexpected, so a bad file can never half-load.
  factory KnowledgeBase.parse(String json) {
    try {
      final j = jsonDecode(json);
      if (j is! Map<String, dynamic>) throw const FormatException('root is not an object');
      final schema = j['schema'];
      if (schema is! int) throw const FormatException('missing "schema"');
      if (schema > supportedSchema) {
        throw FormatException('KB schema $schema is newer than supported $supportedSchema');
      }
      final seq = j['seq'];
      final version = j['version'];
      final entries = j['entries'];
      if (seq is! int || version is! String || entries is! List) {
        throw const FormatException('missing "seq", "version" or "entries"');
      }
      final diseases = [for (final e in entries) Disease.fromJson(e as Map<String, dynamic>)];
      if (diseases.map((d) => d.id).toSet().length != diseases.length) {
        throw const FormatException('duplicate disease ids');
      }
      return KnowledgeBase(
        version: version,
        seq: seq,
        schema: schema,
        includesDrafts: j['includes_drafts'] as bool? ?? false,
        diseases: diseases,
      );
    } on FormatException catch (e) {
      throw KbFormatException(e.message);
    } on TypeError catch (e) {
      throw KbFormatException('wrong field type: $e');
    }
  }
}
