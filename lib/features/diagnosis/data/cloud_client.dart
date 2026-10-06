import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import '../domain/diagnosis_models.dart';
import '../domain/image_issue.dart';

sealed class CloudResponse {
  const CloudResponse();
}

class CloudClassified extends CloudResponse {
  const CloudClassified({required this.diseaseId, required this.confidence, required this.imageIssue, required this.kbSeq});
  final String diseaseId;
  final Confidence confidence;
  final ImageIssue imageIssue;
  final int kbSeq;
}

class CloudGeneral extends CloudResponse {
  const CloudGeneral({required this.summaryBn, required this.preventionBn, required this.imageIssue});
  final String summaryBn;
  final List<String> preventionBn;
  final ImageIssue imageIssue;
}

/// Cloud wire value (`not_a_plant`) to the app's enum. Unknown values mean no issue.
ImageIssue parseImageIssue(Object? v) => switch (v) {
      'blurry' => ImageIssue.blurry,
      'not_a_plant' => ImageIssue.notAPlant,
      'wrong_crop' => ImageIssue.wrongCrop,
      'too_dark' => ImageIssue.tooDark,
      _ => ImageIssue.none,
    };

Confidence parseConfidence(Object? v) => switch (v) {
      'high' => Confidence.high,
      'medium' => Confidence.medium,
      _ => Confidence.low,
    };

/// Maps a `FirebaseFunctionsException.code` per Design §6.5.
DiagnosisFailure mapFunctionsCode(String code) => switch (code) {
      'deadline-exceeded' => const CloudTimeout(),
      'resource-exhausted' => const DailyCapReached(),
      'unauthenticated' || 'permission-denied' => const ServiceRejected(),
      _ => ServerError(code),
    };

CloudResponse parseCloudResponse(Map<String, dynamic> j) {
  switch (j['mode']) {
    case 'classified':
      return CloudClassified(
        diseaseId: j['disease_id'] as String,
        confidence: parseConfidence(j['confidence']),
        imageIssue: parseImageIssue(j['image_issue']),
        kbSeq: (j['kb_seq'] as num?)?.toInt() ?? 0,
      );
    case 'general':
      return CloudGeneral(
        summaryBn: j['summary_bn'] as String,
        preventionBn: [for (final s in (j['prevention_bn'] as List? ?? const [])) s as String],
        imageIssue: parseImageIssue(j['image_issue']),
      );
  }
  throw FormatException('unexpected cloud response mode "${j['mode']}"');
}

/// The one network call the app makes for diagnosis. Injectable so tests need no Firebase.
typedef CallableInvoke = Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);

CallableInvoke firebaseCallable({Duration timeout = const Duration(seconds: 8)}) {
  final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
      .httpsCallable('diagnose', options: HttpsCallableOptions(timeout: timeout));
  return (payload) async {
    final res = await callable.call<Object?>(payload);
    return Map<String, dynamic>.from(res.data! as Map);
  };
}

class CloudDiagnosisClient {
  CloudDiagnosisClient(this._invoke, {this.timeout = const Duration(seconds: 8)});
  final CallableInvoke _invoke;

  /// Hard client-side limit, in addition to the callable's own timeout.
  final Duration timeout;

  /// [crop] is a KB crop id, or `other:<free text>`.
  Future<CloudResponse> diagnose(Uint8List jpeg, String crop) async {
    try {
      return parseCloudResponse(await _invoke({'image': base64Encode(jpeg), 'crop': crop}).timeout(timeout));
    } on TimeoutException {
      throw const CloudTimeout();
    } on FirebaseFunctionsException catch (e) {
      throw mapFunctionsCode(e.code);
    } on FormatException {
      throw const ServerError('bad-response');
    }
  }
}
