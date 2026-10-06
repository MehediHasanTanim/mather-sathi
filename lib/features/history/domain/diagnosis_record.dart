class DiagnosisRecord {
  const DiagnosisRecord({
    required this.id,
    required this.cropType,
    required this.source,
    required this.diagnosedAt,
    this.cropLabel,
    this.diseaseId,
    this.diseaseNameBn,
    this.kbSeq,
    this.adviceJson,
    this.confidence,
    this.photoPath,
    this.district,
    this.upazila,
    this.feedback,
    this.feedbackActual,
    this.isSynced = false,
    this.reportState = 0,
    this.photoSynced = false,
  });

  final String id;
  final String cropType;
  final String? cropLabel;
  final String? diseaseId;
  final String? diseaseNameBn;
  final int? kbSeq;
  final String? adviceJson;
  final String? confidence; // high | medium | low
  final String source; // cloud | on_device
  final String? photoPath;
  final DateTime diagnosedAt; // stored as ISO 8601 UTC
  final String? district;
  final String? upazila;
  final String? feedback; // correct | incorrect
  final String? feedbackActual;
  final bool isSynced;
  final int reportState; // 0 pending | 1 sent | 2 not eligible
  final bool photoSynced;

  Map<String, Object?> toMap() => {
        'id': id,
        'crop_type': cropType,
        'crop_label': cropLabel,
        'disease_id': diseaseId,
        'disease_name_bn': diseaseNameBn,
        'kb_seq': kbSeq,
        'advice_json': adviceJson,
        'confidence': confidence,
        'source': source,
        'photo_path': photoPath,
        'diagnosed_at': diagnosedAt.toUtc().toIso8601String(),
        'district': district,
        'upazila': upazila,
        'feedback': feedback,
        'feedback_actual': feedbackActual,
        'is_synced': isSynced ? 1 : 0,
        'report_state': reportState,
        'photo_synced': photoSynced ? 1 : 0,
      };

  /// What is pushed to `users/{uid}/history/{id}`: metadata and feedback only. No photo bytes or local paths,
  /// and none of the local sync flags.
  Map<String, Object?> toFirestore() => toMap()
    ..removeWhere((k, _) => const {'photo_path', 'is_synced', 'report_state', 'photo_synced'}.contains(k));

  factory DiagnosisRecord.fromMap(Map<String, Object?> m) => DiagnosisRecord(
        id: m['id']! as String,
        cropType: m['crop_type']! as String,
        cropLabel: m['crop_label'] as String?,
        diseaseId: m['disease_id'] as String?,
        diseaseNameBn: m['disease_name_bn'] as String?,
        kbSeq: m['kb_seq'] as int?,
        adviceJson: m['advice_json'] as String?,
        confidence: m['confidence'] as String?,
        source: m['source']! as String,
        photoPath: m['photo_path'] as String?,
        diagnosedAt: DateTime.parse(m['diagnosed_at']! as String),
        district: m['district'] as String?,
        upazila: m['upazila'] as String?,
        feedback: m['feedback'] as String?,
        feedbackActual: m['feedback_actual'] as String?,
        isSynced: m['is_synced'] == 1,
        reportState: (m['report_state'] as int?) ?? 0,
        photoSynced: m['photo_synced'] == 1,
      );
}
