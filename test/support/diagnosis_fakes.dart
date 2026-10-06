import 'dart:convert';
import 'dart:typed_data';

import 'package:mather_sathi/core/errors/error_reporter.dart';
import 'package:mather_sathi/features/diagnosis/data/cloud_client.dart';
import 'package:mather_sathi/features/diagnosis/diagnosis_service.dart';
import 'package:mather_sathi/features/diagnosis/domain/diagnosis_models.dart';
import 'package:mather_sathi/features/kb/domain/kb_models.dart';

/// A small KB as JSON, in the shape tools/kb_build emits.
String kbJson({int seq = 1, int schema = 1, bool drafts = false, List<Map<String, Object?>>? entries}) {
  Map<String, Object?> entry(String id, String crop, String name, String urgency) => {
        'id': id, 'crop': crop, 'status': drafts ? 'draft' : 'published',
        'name_bn': name, 'name_en': id, 'ai_hint_en': 'x', 'description_bn': 'বিবরণ $name',
        'symptoms_bn': ['লক্ষণ ১', 'লক্ষণ ২'], 'cause_bn': 'কারণ', 'urgency': urgency,
        'immediate_bn': ['এখনই করুন'],
        'medicine': <Object?>[], 'prevention_bn': ['প্রতিরোধ ১'], 'see_expert': urgency == 'high',
        'source': 's', 'reviewed_by': 'r', 'reviewed_at': '2026-01-01',
      };
  final list = entries ??
      [
        entry('rice_blast', 'rice', 'ধানের ব্লাস্ট রোগ', 'high'),
        entry('potato_early_blight', 'potato', 'আলুর আর্লি ব্লাইট', 'medium'),
      ];
  return jsonEncode({
    'schema': schema, 'version': 't$seq', 'seq': seq, 'includes_drafts': drafts, 'entries': list,
  });
}

KnowledgeBase testKb({int seq = 1, bool drafts = false}) => KnowledgeBase.parse(kbJson(seq: seq, drafts: drafts));

class FakeReporter implements ErrorReporter {
  final reports = <String>[];
  @override
  Future<void> record(Object error, StackTrace? stack, {String? reason}) async => reports.add('$reason: $error');
}

class FakeConnectivity implements ConnectivityChecker {
  FakeConnectivity(this.online);
  bool online;
  @override
  Future<bool> isOnline() async => online;
}

class FakeAuth implements AuthGate {
  int calls = 0;
  Object? throws;
  @override
  Future<void> ensureSignedIn() async {
    calls++;
    if (throws != null) throw throws!;
  }
}

class FakeLocal implements LocalClassifier {
  FakeLocal({this.available = false, this.result});
  final bool available;
  DiagnosisResult? result;
  int calls = 0;
  @override
  bool get isAvailable => available;
  @override
  Future<DiagnosisResult> classify(Uint8List jpeg, String cropId) async {
    calls++;
    return result!;
  }
}

/// Cloud client whose "network" returns a canned response or throws.
CloudDiagnosisClient fakeCloud({Map<String, dynamic>? response, Object? throws, void Function(Map<String, dynamic>)? onCall}) =>
    CloudDiagnosisClient((payload) async {
      onCall?.call(payload);
      if (throws != null) throw throws;
      return response!;
    });

Map<String, dynamic> cloudClassified(String id, {String confidence = 'high', String issue = 'none', int kbSeq = 1}) =>
    {'mode': 'classified', 'disease_id': id, 'confidence': confidence, 'image_issue': issue, 'kb_seq': kbSeq};
