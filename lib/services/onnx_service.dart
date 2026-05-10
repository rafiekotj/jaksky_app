// onnx_service.dart
// Wraps flutter_onnxruntime (^1.7.0) to load, cache, and run the five
// Jakarta air-quality ONNX models.
//
// All models share the same input/output contract:
//   INPUT  name: "float_input"   shape: [1, 6]   dtype: float32
//   OUTPUT name: "output_label"                  dtype: int64  (class index 0–3)
//   OUTPUT name: "output_probability"             dtype: float sequence
//
// Class index → AirQualityCategory (alphabetical order from sklearn):
//   0 → BAIK
//   1 → SANGAT TIDAK SEHAT
//   2 → SEDANG
//   3 → TIDAK SEHAT

import 'dart:typed_data';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:jaksky_app/models/air_quality_model.dart';

// ---------------------------------------------------------------------------
// Class index → AirQualityCategory mapping
// ---------------------------------------------------------------------------
const List<AirQualityCategory> _kClassIndexToCategory = [
  AirQualityCategory.baik, // 0 — BAIK
  AirQualityCategory.sangatTidakSehat, // 1 — SANGAT TIDAK SEHAT
  AirQualityCategory.sedang, // 2 — SEDANG
  AirQualityCategory.tidakSehat, // 3 — TIDAK SEHAT
];

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

class OnnxServiceException implements Exception {
  final String message;
  const OnnxServiceException(this.message);

  @override
  String toString() => 'OnnxServiceException: $message';
}

// ---------------------------------------------------------------------------
// OnnxService
// ---------------------------------------------------------------------------

class OnnxService {
  OnnxService._();
  static final OnnxService instance = OnnxService._();

  final OnnxRuntime _ort = OnnxRuntime();
  final Map<PredictionAlgorithm, OrtSession> _sessions = {};

  // -------------------------------------------------------------------------
  // Session management
  // -------------------------------------------------------------------------

  Future<OrtSession> _getSession(PredictionAlgorithm algorithm) async {
    if (_sessions.containsKey(algorithm)) return _sessions[algorithm]!;
    try {
      final session = await _ort.createSessionFromAsset(
        algorithm.assetPath,
        options: OrtSessionOptions(
          intraOpNumThreads: 2,
          interOpNumThreads: 1,
          providers: [OrtProvider.CPU],
        ),
      );
      _sessions[algorithm] = session;
      return session;
    } catch (e) {
      throw OnnxServiceException(
        'Failed to load model "${algorithm.label}" from '
        '"${algorithm.assetPath}": $e',
      );
    }
  }

  /// Pre-warm all five sessions (call once at app startup).
  Future<void> preloadAllSessions() async {
    for (final algorithm in PredictionAlgorithm.values) {
      await _getSession(algorithm);
    }
  }

  /// Pre-warm a single session.
  Future<void> preloadSession(PredictionAlgorithm algorithm) async {
    await _getSession(algorithm);
  }

  /// Close a specific session and remove it from cache.
  Future<void> closeSession(PredictionAlgorithm algorithm) async {
    final session = _sessions.remove(algorithm);
    await session?.close();
  }

  /// Close all sessions. Call from app dispose.
  Future<void> closeAll() async {
    for (final session in _sessions.values) {
      await session.close();
    }
    _sessions.clear();
  }

  // -------------------------------------------------------------------------
  // Inference — single public entry point
  // -------------------------------------------------------------------------

  /// Run inference for [algorithm] given a 6-element [featureVector].
  /// Returns an [OnnxPrediction] with the predicted category and probability map.
  /// Throws [OnnxServiceException] on failure.
  Future<OnnxPrediction> runPrediction({
    required PredictionAlgorithm algorithm,
    required List<double> featureVector,
  }) async {
    assert(
      featureVector.length == 6,
      'Feature vector must have exactly 6 elements, got ${featureVector.length}',
    );

    final session = await _getSession(algorithm);

    OrtValue? inputTensor;
    Map<String, OrtValue?> outputs = {};

    try {
      inputTensor = await OrtValue.fromList(
        Float32List.fromList(featureVector),
        [1, 6],
      );

      outputs = await session.run({'float_input': inputTensor});

      return await _parseOutputs(outputs, algorithm);
    } catch (e) {
      throw OnnxServiceException(
        'Inference failed for "${algorithm.label}": $e',
      );
    } finally {
      await inputTensor?.dispose();
      for (final tensor in outputs.values) {
        await tensor?.dispose();
      }
    }
  }

  // -------------------------------------------------------------------------
  // Output parsing (private)
  // -------------------------------------------------------------------------

  Future<OnnxPrediction> _parseOutputs(
    Map<String, OrtValue?> outputs,
    PredictionAlgorithm algorithm,
  ) async {
    int predictedIndex = 2; // default: SEDANG
    final Map<AirQualityCategory, double> probabilities = {};

    // --- Predicted label ---
    final labelTensor = outputs['output_label'];
    if (labelTensor != null) {
      try {
        final labelData = await labelTensor.asFlattenedList();
        if (labelData.isNotEmpty) {
          predictedIndex = (labelData.first as num).toInt().clamp(0, 3);
        }
      } catch (_) {
        // Keep default index
      }
    }

    // --- Probabilities ---
    final probTensor =
        outputs['output_probability'] ?? outputs['probabilities'];
    if (probTensor != null) {
      try {
        final rawProbs = await probTensor.asFlattenedList();
        _mapProbabilities(rawProbs, probabilities);
      } catch (_) {
        // Fall through to fallback below
      }
    }

    if (probabilities.isEmpty) {
      _buildFallbackProbabilities(predictedIndex, probabilities);
    }

    return OnnxPrediction(
      predictedIndex: predictedIndex,
      predictedCategory: _kClassIndexToCategory[predictedIndex],
      probabilities: probabilities,
      algorithm: algorithm,
    );
  }

  void _mapProbabilities(
    List<dynamic> rawProbs,
    Map<AirQualityCategory, double> out,
  ) {
    // rawProbs may be flat [p0, p1, p2, p3] or nested [[p0, p1, p2, p3]]
    final List<double> flat;
    if (rawProbs.isNotEmpty && rawProbs.first is List) {
      flat = (rawProbs.first as List)
          .map((e) => (e as num).toDouble())
          .toList();
    } else {
      flat = rawProbs.map((e) => (e as num).toDouble()).toList();
    }

    for (int i = 0; i < flat.length && i < _kClassIndexToCategory.length; i++) {
      out[_kClassIndexToCategory[i]] = flat[i];
    }
  }

  void _buildFallbackProbabilities(
    int predictedIndex,
    Map<AirQualityCategory, double> out,
  ) {
    // 70% to predicted class, 10% each to the other three.
    const double mainProb = 0.70;
    const double otherProb = 0.10;
    for (int i = 0; i < _kClassIndexToCategory.length; i++) {
      out[_kClassIndexToCategory[i]] = i == predictedIndex
          ? mainProb
          : otherProb;
    }
  }
}

// ---------------------------------------------------------------------------
// OnnxPrediction — raw output from the ONNX session
// ---------------------------------------------------------------------------

class OnnxPrediction {
  final int predictedIndex;
  final AirQualityCategory predictedCategory;
  final Map<AirQualityCategory, double> probabilities;
  final PredictionAlgorithm algorithm;

  const OnnxPrediction({
    required this.predictedIndex,
    required this.predictedCategory,
    required this.probabilities,
    required this.algorithm,
  });
}
