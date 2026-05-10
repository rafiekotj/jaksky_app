// prediction_provider.dart
// State management for the Jakarta Air Quality Prediction feature.
//
// Uses Flutter's ChangeNotifier pattern (compatible with both Provider and
// Riverpod). A Riverpod StateNotifierProvider variant is also included.
//
// Responsibilities:
//   • Hold user selections (date, station, algorithm)
//   • Coordinate CsvService + FeatureBuilder + OnnxService
//   • Expose PredictionResult to the UI
//   • Manage loading / error states

import 'package:flutter/foundation.dart';
import 'package:jaksky_app/models/air_quality_model.dart';
import 'package:jaksky_app/services/data_service.dart';
import 'package:jaksky_app/services/onnx_service.dart';

// ---------------------------------------------------------------------------
// PredictionState — immutable snapshot of the current prediction state
// ---------------------------------------------------------------------------

enum PredictionStatus { idle, loading, success, error }

class PredictionState {
  final PredictionStatus status;
  final DateTime? selectedDate;
  final JakartaStation selectedStation;
  final PredictionAlgorithm selectedAlgorithm;
  final PredictionResult? result;
  final String? errorMessage;

  const PredictionState({
    this.status = PredictionStatus.idle,
    this.selectedDate,
    this.selectedStation = JakartaStation.jakartaPusat,
    this.selectedAlgorithm = PredictionAlgorithm.randomForest,
    this.result,
    this.errorMessage,
  });

  PredictionState copyWith({
    PredictionStatus? status,
    DateTime? selectedDate,
    JakartaStation? selectedStation,
    PredictionAlgorithm? selectedAlgorithm,
    PredictionResult? result,
    String? errorMessage,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return PredictionState(
      status: status ?? this.status,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedStation: selectedStation ?? this.selectedStation,
      selectedAlgorithm: selectedAlgorithm ?? this.selectedAlgorithm,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get hasResult => result != null && status == PredictionStatus.success;
  bool get isLoading => status == PredictionStatus.loading;
  bool get hasError => status == PredictionStatus.error;

  /// True when all required inputs are selected.
  bool get canPredict => selectedDate != null;
}

// ---------------------------------------------------------------------------
// PredictionNotifier — ChangeNotifier (works with Provider package)
// ---------------------------------------------------------------------------

class PredictionNotifier extends ChangeNotifier {
  PredictionState _state = const PredictionState();

  PredictionState get state => _state;

  final CsvService _csvService;
  final FeatureBuilder _featureBuilder;
  final OnnxService _onnxService;

  PredictionNotifier({
    CsvService? csvService,
    FeatureBuilder? featureBuilder,
    OnnxService? onnxService,
  }) : _csvService = csvService ?? CsvService.instance,
       _featureBuilder = featureBuilder ?? FeatureBuilder(),
       _onnxService = onnxService ?? OnnxService.instance;

  // ---------------------------------------------------------------------------
  // Selection setters
  // ---------------------------------------------------------------------------

  /// Set target prediction date.
  /// Must be strictly in the future (after today).
  void setDate(DateTime date) {
    final today = _todayMidnight();
    if (!date.isAfter(today)) {
      debugPrint('PredictionNotifier: date must be after today, ignoring.');
      return;
    }
    _state = _state.copyWith(
      selectedDate: date,
      clearResult: true,
      clearError: true,
    );
    notifyListeners();
  }

  void setStation(JakartaStation station) {
    _state = _state.copyWith(
      selectedStation: station,
      clearResult: true,
      clearError: true,
    );
    notifyListeners();
  }

  void setAlgorithm(PredictionAlgorithm algorithm) {
    _state = _state.copyWith(
      selectedAlgorithm: algorithm,
      clearResult: true,
      clearError: true,
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Prediction
  // ---------------------------------------------------------------------------

  /// Run the full prediction pipeline:
  ///   1. Build feature vector from historical CSV data
  ///   2. Run ONNX inference
  ///   3. Combine results into [PredictionResult]
  Future<void> predict() async {
    if (!_state.canPredict) {
      _setError('Pilih tanggal terlebih dahulu.');
      return;
    }

    _state = _state.copyWith(
      status: PredictionStatus.loading,
      clearResult: true,
      clearError: true,
    );
    notifyListeners();

    try {
      final targetDate = _state.selectedDate!;
      final station = _state.selectedStation;
      final algorithm = _state.selectedAlgorithm;

      // 1. Build features
      final builtFeatures = await _featureBuilder.buildFeatures(
        targetDate: targetDate,
        station: station,
      );

      // 2. Run ONNX model
      final onnxPrediction = await _onnxService.runPrediction(
        algorithm: algorithm,
        featureVector: builtFeatures.featureVector,
      );

      // 3. Assemble result
      final result = PredictionResult(
        predictedCategory: onnxPrediction.predictedCategory,
        probabilities: onnxPrediction.probabilities,
        likelyCriticalPollutant: builtFeatures.criticalPollutant,
        estimatedFeatures: builtFeatures.namedFeatures,
        algorithm: algorithm,
        targetDate: targetDate,
        station: station,
        hasHistoricalData: builtFeatures.hasHistoricalData,
      );

      _state = _state.copyWith(
        status: PredictionStatus.success,
        result: result,
        clearError: true,
      );
    } on OnnxServiceException catch (e) {
      _setError('Model error: ${e.message}');
    } catch (e) {
      _setError('Terjadi kesalahan: $e');
    }

    notifyListeners();
  }

  /// Pre-warm the currently selected ONNX session in the background.
  Future<void> preloadCurrentModel() async {
    try {
      await _onnxService.preloadSession(_state.selectedAlgorithm);
    } catch (e) {
      debugPrint('PredictionNotifier: preload failed — $e');
    }
  }

  /// Pre-warm all five models (call once at app startup for best UX).
  Future<void> preloadAllModels() async {
    // Ensure CSV is loaded first.
    await _csvService.loadRecords();
    try {
      await _onnxService.preloadAllSessions();
    } catch (e) {
      debugPrint('PredictionNotifier: preloadAll failed — $e');
    }
  }

  /// Reset everything to initial state.
  void reset() {
    _state = const PredictionState();
    notifyListeners();
  }

  void _setError(String message) {
    _state = _state.copyWith(
      status: PredictionStatus.error,
      errorMessage: message,
      clearResult: true,
    );
  }

  DateTime _todayMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    // Sessions are managed globally by OnnxService; do NOT close them here
    // unless this notifier owns them exclusively.
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// CsvLoadingNotifier — handles initial CSV data loading state
// ---------------------------------------------------------------------------

enum CsvLoadingStatus { idle, loading, loaded, error }

class CsvLoadingState {
  final CsvLoadingStatus status;
  final int totalRecords;
  final String? errorMessage;

  const CsvLoadingState({
    this.status = CsvLoadingStatus.idle,
    this.totalRecords = 0,
    this.errorMessage,
  });

  bool get isLoaded => status == CsvLoadingStatus.loaded;
  bool get isLoading => status == CsvLoadingStatus.loading;
}

class CsvLoadingNotifier extends ChangeNotifier {
  CsvLoadingState _state = const CsvLoadingState();
  CsvLoadingState get state => _state;

  final CsvService _csvService;

  CsvLoadingNotifier({CsvService? csvService})
    : _csvService = csvService ?? CsvService.instance;

  Future<void> load() async {
    if (_state.isLoaded || _state.isLoading) return;

    _state = const CsvLoadingState(status: CsvLoadingStatus.loading);
    notifyListeners();

    try {
      final records = await _csvService.loadRecords();
      _state = CsvLoadingState(
        status: CsvLoadingStatus.loaded,
        totalRecords: records.length,
      );
    } catch (e) {
      _state = CsvLoadingState(
        status: CsvLoadingStatus.error,
        errorMessage: 'Gagal memuat data historis: $e',
      );
    }

    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Convenience factory for ChangeNotifierProvider (Provider package)
// ---------------------------------------------------------------------------
//
// Usage in main.dart:
//
//   MultiProvider(
//     providers: [
//       ChangeNotifierProvider(create: (_) => CsvLoadingNotifier()..load()),
//       ChangeNotifierProvider(create: (_) => PredictionNotifier()),
//     ],
//     child: MyApp(),
//   )
//
// Usage in a widget:
//
//   final notifier = context.watch<PredictionNotifier>();
//   final state = notifier.state;

// ---------------------------------------------------------------------------
// Riverpod StateNotifier variant (optional — use if project uses Riverpod)
// ---------------------------------------------------------------------------
//
// Uncomment the block below if you use flutter_riverpod instead of provider.
//
// ```dart
// import 'package:flutter_riverpod/flutter_riverpod.dart';
//
// class PredictionStateNotifier extends StateNotifier<PredictionState> {
//   PredictionStateNotifier() : super(const PredictionState());
//
//   final _csvService = CsvService.instance;
//   final _featureBuilder = FeatureBuilder();
//   final _onnxService = OnnxService.instance;
//
//   void setDate(DateTime date) {
//     final today = DateTime.now();
//     final todayMidnight = DateTime(today.year, today.month, today.day);
//     if (!date.isAfter(todayMidnight)) return;
//     state = state.copyWith(selectedDate: date, clearResult: true);
//   }
//
//   void setStation(JakartaStation station) =>
//       state = state.copyWith(selectedStation: station, clearResult: true);
//
//   void setAlgorithm(PredictionAlgorithm algo) =>
//       state = state.copyWith(selectedAlgorithm: algo, clearResult: true);
//
//   Future<void> predict() async {
//     if (!state.canPredict) return;
//     state = state.copyWith(status: PredictionStatus.loading, clearResult: true);
//     try {
//       final builtFeatures = await _featureBuilder.buildFeatures(
//         targetDate: state.selectedDate!,
//         station: state.selectedStation,
//       );
//       final onnxPrediction = await _onnxService.runPrediction(
//         algorithm: state.selectedAlgorithm,
//         featureVector: builtFeatures.featureVector,
//       );
//       state = state.copyWith(
//         status: PredictionStatus.success,
//         result: PredictionResult(
//           predictedCategory: onnxPrediction.predictedCategory,
//           probabilities: onnxPrediction.probabilities,
//           likelyCriticalPollutant: builtFeatures.criticalPollutant,
//           estimatedFeatures: builtFeatures.namedFeatures,
//           algorithm: state.selectedAlgorithm,
//           targetDate: state.selectedDate!,
//           station: state.selectedStation,
//           hasHistoricalData: builtFeatures.hasHistoricalData,
//         ),
//       );
//     } catch (e) {
//       state = state.copyWith(
//         status: PredictionStatus.error,
//         errorMessage: 'Terjadi kesalahan: $e',
//       );
//     }
//   }
// }
//
// final predictionProvider =
//     StateNotifierProvider<PredictionStateNotifier, PredictionState>(
//   (ref) => PredictionStateNotifier(),
// );
//
// final csvLoadingProvider = FutureProvider<List<AirQualityRecord>>((ref) {
//   return CsvService.instance.loadRecords();
// });
// ```
