// lib/providers/prediction_provider.dart
//
// State management prediksi kualitas udara.
// Mengorkestrasikan DataService + OnnxService → menghasilkan AirQualityPrediction.
//
// Pola: ChangeNotifier (cocok dengan Provider package).
// Gunakan dengan:
//   ChangeNotifierProvider(create: (_) => PredictionProvider()..init())

import 'package:flutter/foundation.dart';
import 'package:jaksky_app/models/air_quality_model.dart';
import 'package:jaksky_app/services/data_service.dart';
import 'package:jaksky_app/services/onnx_service.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum PredictionStatus {
  idle, // belum ada prediksi
  loading, // sedang proses
  success, // prediksi berhasil
  error, // terjadi kesalahan
}

class PredictionState {
  final PredictionStatus status;
  final AirQualityPrediction? prediction;
  final String? errorMessage;

  // ── Pilihan saat ini ──
  final DateTime? selectedDate;
  final JakartaLocation selectedLocation;
  final AirQualityAlgorithm selectedAlgorithm;

  // ── Loading state inisialisasi ──
  final bool isInitializing;
  final bool isInitialized;

  const PredictionState({
    this.status = PredictionStatus.idle,
    this.prediction,
    this.errorMessage,
    this.selectedDate,
    this.selectedLocation = JakartaLocation.jakartaPusat,
    this.selectedAlgorithm = AirQualityAlgorithm.randomForest,
    this.isInitializing = true,
    this.isInitialized = false,
  });

  bool get isLoading => status == PredictionStatus.loading;
  bool get hasResult =>
      status == PredictionStatus.success && prediction != null;
  bool get hasError => status == PredictionStatus.error;

  PredictionState copyWith({
    PredictionStatus? status,
    AirQualityPrediction? prediction,
    String? errorMessage,
    DateTime? selectedDate,
    JakartaLocation? selectedLocation,
    AirQualityAlgorithm? selectedAlgorithm,
    bool? isInitializing,
    bool? isInitialized,
    bool clearPrediction = false,
    bool clearError = false,
  }) {
    return PredictionState(
      status: status ?? this.status,
      prediction: clearPrediction ? null : (prediction ?? this.prediction),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedDate: selectedDate ?? this.selectedDate,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      selectedAlgorithm: selectedAlgorithm ?? this.selectedAlgorithm,
      isInitializing: isInitializing ?? this.isInitializing,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

// ─── PredictionProvider ───────────────────────────────────────────────────────

class PredictionProvider extends ChangeNotifier {
  final DataService _dataService;
  final OnnxService _onnxService;

  PredictionState _state = const PredictionState();
  PredictionState get state => _state;

  // Shortcut getters untuk binding di UI
  PredictionStatus get status => _state.status;
  AirQualityPrediction? get prediction => _state.prediction;
  String? get errorMessage => _state.errorMessage;
  DateTime? get selectedDate => _state.selectedDate;
  JakartaLocation get selectedLocation => _state.selectedLocation;
  AirQualityAlgorithm get selectedAlgo => _state.selectedAlgorithm;
  bool get isLoading => _state.isLoading;
  bool get hasResult => _state.hasResult;
  bool get hasError => _state.hasError;
  bool get isInitializing => _state.isInitializing;
  bool get isInitialized => _state.isInitialized;

  PredictionProvider({DataService? dataService, OnnxService? onnxService})
    : _dataService = dataService ?? DataService(),
      _onnxService = onnxService ?? OnnxService();

  // ─── Init ────────────────────────────────────────────────────────────────

  /// Panggil setelah ChangeNotifierProvider dibuat.
  /// Memuat CSV + preload model default.
  Future<void> init() async {
    _setState(_state.copyWith(isInitializing: true));

    try {
      // Muat data CSV historis
      await _dataService.init();

      // Preload model default (Random Forest) agar prediksi pertama instan
      await _onnxService.preloadSession(_state.selectedAlgorithm);

      _setState(_state.copyWith(isInitializing: false, isInitialized: true));
      debugPrint('[PredictionProvider] Init selesai');
    } catch (e) {
      debugPrint('[PredictionProvider] Init error: $e');
      _setState(
        _state.copyWith(
          isInitializing: false,
          isInitialized: false,
          status: PredictionStatus.error,
          errorMessage: 'Gagal inisialisasi: $e',
        ),
      );
    }
  }

  // ─── Selection Setters ────────────────────────────────────────────────────

  void setDate(DateTime date) {
    // Validasi: tidak boleh hari ini atau sebelumnya
    final today = _today();
    if (!date.isAfter(today)) {
      debugPrint('[PredictionProvider] Tanggal harus setelah hari ini');
      return;
    }
    _setState(
      _state.copyWith(
        selectedDate: date,
        status: PredictionStatus.idle,
        clearPrediction: true,
        clearError: true,
      ),
    );
  }

  void setLocation(JakartaLocation location) {
    _setState(
      _state.copyWith(
        selectedLocation: location,
        status: PredictionStatus.idle,
        clearPrediction: true,
        clearError: true,
      ),
    );
  }

  void setAlgorithm(AirQualityAlgorithm algorithm) {
    _setState(
      _state.copyWith(
        selectedAlgorithm: algorithm,
        status: PredictionStatus.idle,
        clearPrediction: true,
        clearError: true,
      ),
    );
    // Preload sesi baru di background
    _onnxService.preloadSession(algorithm).catchError((e) {
      debugPrint('[PredictionProvider] Preload ${algorithm.key} error: $e');
    });
  }

  // ─── Predict ─────────────────────────────────────────────────────────────

  /// Jalankan prediksi dengan parameter yang diberikan langsung
  Future<AirQualityPrediction> predict({
    required DateTime targetDate,
    required JakartaLocation location,
    required AirQualityAlgorithm algorithm,
  }) async {
    // Validasi
    final today = _today();
    if (!targetDate.isAfter(today)) {
      throw PredictionValidationException('Tanggal harus setelah hari ini');
    }

    _setState(
      _state.copyWith(status: PredictionStatus.loading, clearError: true),
    );

    try {
      // Step 1: Bangun fitur dari data historis atau estimasi
      final featureResult = await _dataService.buildFeatures(
        targetDate,
        location,
      );
      final features = featureResult.features;

      // Step 2: Jalankan inferensi ONNX
      final inferenceResult = await _onnxService.predict(algorithm, features);

      // Step 3: Bangun info polutan untuk ditampilkan
      final pollutantInfoList = _dataService.buildPollutantInfo(features);

      // Step 4: Buat objek prediksi lengkap
      final prediction = AirQualityPrediction(
        targetDate: targetDate,
        location: location,
        algorithm: algorithm,
        category: inferenceResult.category,
        probabilities: inferenceResult.probabilityByLabel,
        features: features,
        dominantPollutants: pollutantInfoList,
        isEstimated: featureResult.isEstimated,
        predictedAt: DateTime.now(),
      );

      _setState(
        _state.copyWith(
          status: PredictionStatus.success,
          prediction: prediction,
        ),
      );

      debugPrint(
        '[PredictionProvider] Prediksi selesai: '
        '${prediction.category.displayName} '
        '(confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%)',
      );

      return prediction;
    } on PredictionValidationException {
      rethrow;
    } on OnnxServiceException catch (e) {
      _setState(
        _state.copyWith(
          status: PredictionStatus.error,
          errorMessage: e.message,
        ),
      );
      rethrow;
    } catch (e, st) {
      debugPrint('[PredictionProvider] predict() error: $e\n$st');
      _setState(
        _state.copyWith(
          status: PredictionStatus.error,
          errorMessage: 'Terjadi kesalahan: $e',
        ),
      );
      rethrow;
    }
  }

  /// Jalankan prediksi dengan pilihan saat ini.
  /// Melempar [PredictionValidationException] jika validasi gagal.
  Future<void> predictWithCurrentSelection() async {
    // Validasi
    if (_state.selectedDate == null) {
      throw PredictionValidationException(
        'Pilih tanggal prediksi terlebih dahulu',
      );
    }
    final today = _today();
    if (!_state.selectedDate!.isAfter(today)) {
      throw PredictionValidationException('Tanggal harus setelah hari ini');
    }

    _setState(
      _state.copyWith(status: PredictionStatus.loading, clearError: true),
    );

    try {
      final targetDate = _state.selectedDate!;
      final location = _state.selectedLocation;
      final algorithm = _state.selectedAlgorithm;

      // Step 1: Bangun fitur dari data historis atau estimasi
      final featureResult = await _dataService.buildFeatures(
        targetDate,
        location,
      );
      final features = featureResult.features;

      // Step 2: Jalankan inferensi ONNX
      final inferenceResult = await _onnxService.predict(algorithm, features);

      // Step 3: Bangun info polutan untuk ditampilkan
      final pollutantInfoList = _dataService.buildPollutantInfo(features);

      // Step 4: Buat objek prediksi lengkap
      final prediction = AirQualityPrediction(
        targetDate: targetDate,
        location: location,
        algorithm: algorithm,
        category: inferenceResult.category,
        probabilities: inferenceResult.probabilityByLabel,
        features: features,
        dominantPollutants: pollutantInfoList,
        isEstimated: featureResult.isEstimated,
        predictedAt: DateTime.now(),
      );

      _setState(
        _state.copyWith(
          status: PredictionStatus.success,
          prediction: prediction,
        ),
      );

      debugPrint(
        '[PredictionProvider] Prediksi selesai: '
        '${prediction.category.displayName} '
        '(confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%)',
      );
    } on PredictionValidationException {
      rethrow;
    } on OnnxServiceException catch (e) {
      _setState(
        _state.copyWith(
          status: PredictionStatus.error,
          errorMessage: e.message,
        ),
      );
    } catch (e, st) {
      debugPrint('[PredictionProvider] predict() error: $e\n$st');
      _setState(
        _state.copyWith(
          status: PredictionStatus.error,
          errorMessage: 'Terjadi kesalahan: $e',
        ),
      );
    }
  }

  /// Reset state ke idle (tanpa hapus pilihan)
  void reset() {
    _setState(
      _state.copyWith(
        status: PredictionStatus.idle,
        clearPrediction: true,
        clearError: true,
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _setState(PredictionState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Kembalikan DateTime awal hari ini (tanpa jam/menit/detik)
  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Tanggal minimum yang bisa dipilih (besok)
  DateTime get minimumDate {
    final today = _today();
    return today.add(const Duration(days: 1));
  }

  /// Tanggal maksimum yang bisa dipilih (1 tahun ke depan)
  DateTime get maximumDate {
    final today = _today();
    return today.add(const Duration(days: 365));
  }

  /// Apakah tanggal yang diberikan valid untuk dipilih
  bool isDateSelectable(DateTime date) {
    return date.isAfter(_today());
  }

  @override
  void dispose() {
    _onnxService.closeAllSessions();
    super.dispose();
  }
}

// ─── Exception ────────────────────────────────────────────────────────────────

class PredictionValidationException implements Exception {
  final String message;
  const PredictionValidationException(this.message);

  @override
  String toString() => 'PredictionValidationException: $message';
}
