// lib/services/onnx_service.dart
//
// Wrapper bersih di atas flutter_onnxruntime ^1.7.0.
// Mengelola siklus hidup sesi ONNX dan mengekspos satu metode prediksi.
//
// INPUT CONTRACT semua model:
//   float_input        float32[1, 6]   [pm10, pm25, so2, co, o3, no2]
// OUTPUT CONTRACT semua model:
//   output_label       int64[1]        indeks kelas 0-3
//   output_probability float32[1, 4]   probabilitas per kelas
//
// CLASS INDEX:
//   0 → BAIK
//   1 → SANGAT TIDAK SEHAT
//   2 → SEDANG
//   3 → TIDAK SEHAT

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../models/air_quality_model.dart';

// ─── Model Hasil Inference Mentah ─────────────────────────────────────────────

class OnnxInferenceResult {
  /// Indeks kelas prediksi (0-3)
  final int labelIndex;

  /// Probabilitas untuk setiap kelas; panjang 4, urutan sesuai CLASS INDEX
  final List<double> probabilities;

  const OnnxInferenceResult({
    required this.labelIndex,
    required this.probabilities,
  });

  AirQualityCategory get category => AirQualityCategory.fromIndex(labelIndex);

  /// Probabilitas per rawLabel ('BAIK', 'SANGAT TIDAK SEHAT', dst.)
  Map<String, double> get probabilityByLabel {
    final categories = AirQualityCategory.values;
    // values urut berdasarkan deklarasi enum; labelIndex sesuai CLASS INDEX
    // Kita map berdasarkan .index bukan posisi dalam values
    return {
      for (final cat in categories)
        cat.rawLabel: probabilities.length > cat.index
            ? probabilities[cat.index]
            : 0.0,
    };
  }

  @override
  String toString() =>
      'OnnxInferenceResult(label=$labelIndex, probs=$probabilities)';
}

// ─── OnnxService ──────────────────────────────────────────────────────────────

class OnnxService {
  final _ort = OnnxRuntime();

  /// Cache sesi per asset path agar tidak reload tiap prediksi
  final Map<String, OrtSession> _sessions = {};

  // ─── Session Management ───────────────────────────────────────────────────

  /// Preload sesi model tertentu. Panggil di init agar prediksi pertama cepat.
  Future<void> preloadSession(AirQualityAlgorithm algorithm) async {
    await _getOrCreateSession(algorithm.assetPath);
  }

  /// Preload semua sesi sekaligus (opsional; berguna di splashscreen).
  Future<void> preloadAllSessions() async {
    for (final algo in AirQualityAlgorithm.values) {
      await _getOrCreateSession(algo.assetPath);
    }
  }

  /// Tutup satu sesi dan hapus dari cache.
  Future<void> closeSession(AirQualityAlgorithm algorithm) async {
    final session = _sessions.remove(algorithm.assetPath);
    await session?.close();
  }

  /// Tutup semua sesi (panggil saat dispose provider / app exit).
  Future<void> closeAllSessions() async {
    for (final session in _sessions.values) {
      await session.close();
    }
    _sessions.clear();
  }

  // ─── Inference ────────────────────────────────────────────────────────────

  /// Jalankan inferensi dengan fitur yang diberikan menggunakan algoritma tertentu.
  /// Mengembalikan [OnnxInferenceResult] dengan label integer dan probabilitas float32.
  Future<OnnxInferenceResult> predict(
    AirQualityAlgorithm algorithm,
    AirQualityFeatures features,
  ) async {
    OrtValue? inputTensor;
    Map<String, OrtValue>? outputs;

    try {
      final session = await _getOrCreateSession(algorithm.assetPath);

      // ── Buat tensor input float32[1, 6] ──────────────────────────────────
      final inputData = Float32List.fromList(
        features.toInputList().map((v) => v.toDouble()).toList(),
      );
      inputTensor = await OrtValue.fromList(inputData, [1, 6]);

      // ── Jalankan inferensi ────────────────────────────────────────────────
      outputs = await session.run({'float_input': inputTensor});

      // ── Baca output_label (int64[1]) ──────────────────────────────────────
      final labelTensor = outputs['output_label'];
      if (labelTensor == null) {
        throw OnnxServiceException(
          'output_label tidak ditemukan dalam output model ${algorithm.key}',
        );
      }
      final labelRaw = await labelTensor.asFlattenedList();
      final labelIndex = (labelRaw.first as num).toInt();

      // ── Baca output_probability (float32[1, 4]) ───────────────────────────
      final probTensor = outputs['output_probability'];
      if (probTensor == null) {
        throw OnnxServiceException(
          'output_probability tidak ditemukan dalam output model ${algorithm.key}',
        );
      }
      final probRaw = await probTensor.asFlattenedList();
      final probabilities = probRaw.map((v) => (v as num).toDouble()).toList();

      if (probabilities.length != 4) {
        throw OnnxServiceException(
          'output_probability harus 4 elemen, got ${probabilities.length}',
        );
      }

      return OnnxInferenceResult(
        labelIndex: labelIndex,
        probabilities: probabilities,
      );
    } on OnnxServiceException {
      rethrow;
    } catch (e, st) {
      debugPrint('[OnnxService] Error prediksi ${algorithm.key}: $e\n$st');
      throw OnnxServiceException(
        'Gagal menjalankan model ${algorithm.displayName}: $e',
      );
    } finally {
      // ── Dispose tensor input ──────────────────────────────────────────────
      await inputTensor?.dispose();
      // ── Dispose tensor output ─────────────────────────────────────────────
      if (outputs != null) {
        for (final tensor in outputs.values) {
          await tensor.dispose();
        }
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<OrtSession> _getOrCreateSession(String assetPath) async {
    if (_sessions.containsKey(assetPath)) {
      return _sessions[assetPath]!;
    }

    debugPrint('[OnnxService] Memuat sesi: $assetPath');
    try {
      final session = await _ort.createSessionFromAsset(assetPath);
      _sessions[assetPath] = session;

      // Log info sesi (debug only)
      debugPrint(
        '[OnnxService] Sesi dimuat. Inputs: ${session.inputNames}, Outputs: ${session.outputNames}',
      );

      return session;
    } catch (e) {
      throw OnnxServiceException('Gagal memuat model "$assetPath": $e');
    }
  }
}

// ─── Exception ────────────────────────────────────────────────────────────────

class OnnxServiceException implements Exception {
  final String message;
  const OnnxServiceException(this.message);

  @override
  String toString() => 'OnnxServiceException: $message';
}
