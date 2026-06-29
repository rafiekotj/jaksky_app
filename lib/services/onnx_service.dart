import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../models/air_quality_model.dart';

class OnnxInferenceResult {
  // Indeks kategori dari output model (0-3)
  final int labelIndex;
  // Probabilitas untuk tiap kategori
  final List<double> probabilities;

  const OnnxInferenceResult({
    required this.labelIndex,
    required this.probabilities,
  });

  AirQualityCategory get category => AirQualityCategory.fromIndex(labelIndex);

  // Map probabilitas ke label kategori (BAIK, SEDANG, dst)
  Map<String, double> get probabilityByLabel {
    final categories = AirQualityCategory.values;
    // Map index ke raw label untuk UI
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

class OnnxService {
  // Wrapper untuk ONNX Runtime (library ML inference)
  final _ort = OnnxRuntime();

  // Simpan session model agar tidak reload
  final Map<String, OrtSession> _sessions = {};

  // Siapkan satu model sebelum digunakan
  Future<void> preloadSession(AirQualityAlgorithm algorithm) async {
    await _getOrCreateSession(algorithm.assetPath);
  }

  // Siapkan semua 5 model sekaligus di startup
  Future<void> preloadAllSessions() async {
    for (final algo in AirQualityAlgorithm.values) {
      await _getOrCreateSession(algo.assetPath);
    }
  }

  Future<void> closeSession(AirQualityAlgorithm algorithm) async {
    final session = _sessions.remove(algorithm.assetPath);
    await session?.close();
  }

  // Tutup semua sesi & bersihkan memory
  Future<void> closeAllSessions() async {
    for (final session in _sessions.values) {
      await session.close();
    }
    _sessions.clear();
  }

  // Jalankan model ML dengan fitur polutan
  Future<OnnxInferenceResult> predict(
    AirQualityAlgorithm algorithm,
    AirQualityFeatures features,
  ) async {
    // Simpan resource untuk cleanup nanti
    OrtValue? inputTensor;
    Map<String, OrtValue>? outputs;

    try {
      // Step 1: Siapkan session model (cache atau buat baru)
      final session = await _getOrCreateSession(algorithm.assetPath);
      // Step 2: Konversi fitur jadi tensor (array 1x6)
      final inputData = Float32List.fromList(
        features.toInputList().map((v) => v.toDouble()).toList(),
      );
      inputTensor = await OrtValue.fromList(inputData, [1, 6]);
      // Step 3: Jalankan model & dapat output
      outputs = await session.run({'float_input': inputTensor});

      // Step 4: Parse output label (kategori 0-3)
      final labelTensor = outputs['output_label'];
      if (labelTensor == null) {
        throw OnnxServiceException(
          'output_label tidak ditemukan dalam output model ${algorithm.key}',
        );
      }
      final labelRaw = await labelTensor.asFlattenedList();
      final labelIndex = (labelRaw.first as num).toInt();

      // Step 5: Parse output probabilitas (4 nilai, 1 per kategori)
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
    } catch (e) {
      throw OnnxServiceException(
        'Gagal menjalankan model ${algorithm.displayName}: $e',
      );
    } finally {
      // Bersihkan tensor dari GPU memory
      await inputTensor?.dispose();
      if (outputs != null) {
        for (final tensor in outputs.values) {
          await tensor.dispose();
        }
      }
    }
  }

  // Ambil session atau buat baru (caching)
  Future<OrtSession> _getOrCreateSession(String assetPath) async {
    // Jika sudah ada di cache, pakai yang lama
    if (_sessions.containsKey(assetPath)) {
      return _sessions[assetPath]!;
    }

    try {
      // Load model dari asset folder
      final session = await _ort.createSessionFromAsset(assetPath);
      // Simpan ke cache untuk pakai lagi
      _sessions[assetPath] = session;
      return session;
    } catch (e) {
      throw OnnxServiceException('Gagal memuat model "$assetPath": $e');
    }
  }
}

class OnnxServiceException implements Exception {
  final String message;
  const OnnxServiceException(this.message);

  @override
  String toString() => 'OnnxServiceException: $message';
}
