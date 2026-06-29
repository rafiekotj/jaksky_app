import 'package:flutter/foundation.dart';
import 'package:jaksky_app/models/air_quality_model.dart';
import 'package:jaksky_app/services/data_service.dart';
import 'package:jaksky_app/services/onnx_service.dart';

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

  final DateTime? selectedDate;
  final JakartaLocation selectedLocation;
  final AirQualityAlgorithm selectedAlgorithm;

  final bool isInitializing;
  final bool isInitialized;

  const PredictionState({
    this.status = PredictionStatus.idle,
    this.prediction,
    this.errorMessage,
    this.selectedDate,
    this.selectedLocation = JakartaLocation.jakartaPusat,
    this.selectedAlgorithm = AirQualityAlgorithm.randomForest,
    this.isInitializing = true, // Sedang proses muat data
    this.isInitialized = false, // Data siap untuk prediksi
  });

  bool get isLoading => status == PredictionStatus.loading;
  bool get hasResult =>
      status == PredictionStatus.success && prediction != null;
  bool get hasError => status == PredictionStatus.error;

  // Update sebagian state, sisanya tetap lama
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

class PredictionProvider extends ChangeNotifier {
  final DataService _dataService;
  final OnnxService _onnxService;

  PredictionState _state = const PredictionState();
  PredictionState get state => _state;

  // Pintas akses state dari UI
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

  // Baca CSV & siapkan model ML
  Future<void> init() async {
    _setState(_state.copyWith(isInitializing: true));

    try {
      await _dataService.init();
      if (!kIsWeb) {
        await _onnxService.preloadSession(_state.selectedAlgorithm);
      }
      _setState(_state.copyWith(isInitializing: false, isInitialized: true));
    } catch (e) {
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

  void setDate(DateTime date) {
    // Tanggal harus lebih maju dari hari ini
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
    if (!kIsWeb) {
      _onnxService.preloadSession(algorithm).catchError((_) {});
    }
  }

  // Prediksi dengan parameter spesifik dari UI
  Future<AirQualityPrediction> predict({
    required DateTime targetDate,
    required JakartaLocation location,
    required AirQualityAlgorithm algorithm,
  }) async {
    final today = _today();
    if (!targetDate.isAfter(today)) {
      throw PredictionValidationException('Tanggal harus setelah hari ini');
    }
    if (kIsWeb) {
      throw PredictionValidationException(
        'Prediksi tidak tersedia di web. '
        'Gunakan Android emulator atau device fisik untuk inference model.',
      );
    }

    return await _performPrediction(targetDate, location, algorithm);
  }

  // Prediksi dengan pilihan yang sudah dipilih user
  Future<void> predictWithCurrentSelection() async {
    if (_state.selectedDate == null) {
      throw PredictionValidationException(
        'Pilih tanggal prediksi terlebih dahulu',
      );
    }
    final today = _today();
    if (!_state.selectedDate!.isAfter(today)) {
      throw PredictionValidationException('Tanggal harus setelah hari ini');
    }
    if (kIsWeb) {
      throw PredictionValidationException(
        'Prediksi tidak tersedia di web. '
        'Gunakan Android emulator atau device fisik untuk inference model.',
      );
    }

    await _performPrediction(
      _state.selectedDate!,
      _state.selectedLocation,
      _state.selectedAlgorithm,
    );
  }

  // Proses utama: ambil data → prediksi → tampilkan hasil
  Future<AirQualityPrediction> _performPrediction(
    DateTime targetDate,
    JakartaLocation location,
    AirQualityAlgorithm algorithm,
  ) async {
    _setState(
      _state.copyWith(status: PredictionStatus.loading, clearError: true),
    );

    try {
      // Step 1: Ambil data historis atau standar dari CSV
      final featureResult = await _dataService.buildFeatures(
        targetDate,
        location,
      );
      final features = featureResult.features;
      // Step 2: Model prediksi kategori & probabilitas
      final inferenceResult = await _onnxService.predict(algorithm, features);
      // Step 3: Info polutan untuk tampilan
      final pollutantInfoList = _dataService.buildPollutantInfo(features);

      // Bundel semua hasil untuk ditampilkan UI
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

      // Simpan hasil & beri tahu UI ada data baru
      _setState(
        _state.copyWith(
          status: PredictionStatus.success,
          prediction: prediction,
        ),
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
    } catch (e) {
      _setState(
        _state.copyWith(
          status: PredictionStatus.error,
          errorMessage: 'Terjadi kesalahan: $e',
        ),
      );
      rethrow;
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

  // Perbarui state & beri tahu UI ada perubahan
  void _setState(PredictionState newState) {
    _state = newState;
    notifyListeners();
  }

  // Ambil tanggal hari ini jam 00:00
  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // Awal pilihan tanggal: besok
  DateTime get minimumDate {
    final today = _today();
    return today.add(const Duration(days: 1));
  }

  // Akhir pilihan tanggal: satu tahun ke depan
  DateTime get maximumDate {
    final today = _today();
    return today.add(const Duration(days: 365));
  }

  // Cek tanggal valid atau tidak untuk dipilih
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
