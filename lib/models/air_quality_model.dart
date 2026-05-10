// air_quality_model.dart
// Model entities, enums, and data classes for the Jakarta Air Quality Prediction app.
// Data source: CleanData.csv — stations DKI1–DKI5, years 2021–2025.

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Air quality categories matching the CSV `kategori` column.
enum AirQualityCategory {
  baik, // BAIK
  sedang, // SEDANG
  tidakSehat, // TIDAK SEHAT
  sangatTidakSehat, // SANGAT TIDAK SEHAT
}

extension AirQualityCategoryX on AirQualityCategory {
  String get label {
    switch (this) {
      case AirQualityCategory.baik:
        return 'Baik';
      case AirQualityCategory.sedang:
        return 'Sedang';
      case AirQualityCategory.tidakSehat:
        return 'Tidak Sehat';
      case AirQualityCategory.sangatTidakSehat:
        return 'Sangat Tidak Sehat';
    }
  }

  /// Raw string as stored in CSV / returned by ONNX label output.
  String get rawLabel {
    switch (this) {
      case AirQualityCategory.baik:
        return 'BAIK';
      case AirQualityCategory.sedang:
        return 'SEDANG';
      case AirQualityCategory.tidakSehat:
        return 'TIDAK SEHAT';
      case AirQualityCategory.sangatTidakSehat:
        return 'SANGAT TIDAK SEHAT';
    }
  }

  Color get color {
    switch (this) {
      case AirQualityCategory.baik:
        return const Color(0xFF00C853); // green
      case AirQualityCategory.sedang:
        return const Color(0xFFFFD600); // yellow
      case AirQualityCategory.tidakSehat:
        return const Color(0xFFFF6D00); // orange
      case AirQualityCategory.sangatTidakSehat:
        return const Color(0xFFD50000); // red
    }
  }

  IconData get icon {
    switch (this) {
      case AirQualityCategory.baik:
        return Icons.check_circle_outline;
      case AirQualityCategory.sedang:
        return Icons.info_outline;
      case AirQualityCategory.tidakSehat:
        return Icons.warning_amber_outlined;
      case AirQualityCategory.sangatTidakSehat:
        return Icons.dangerous_outlined;
    }
  }

  String get description {
    switch (this) {
      case AirQualityCategory.baik:
        return 'Kualitas udara memuaskan dan tidak menimbulkan risiko kesehatan.';
      case AirQualityCategory.sedang:
        return 'Kualitas udara dapat diterima, namun mungkin ada risiko bagi kelompok sensitif.';
      case AirQualityCategory.tidakSehat:
        return 'Setiap orang mungkin mulai mengalami efek kesehatan. Kurangi aktivitas luar ruangan.';
      case AirQualityCategory.sangatTidakSehat:
        return 'Peringatan kesehatan darurat. Hindari semua aktivitas luar ruangan.';
    }
  }
}

/// Five prediction algorithms available.
enum PredictionAlgorithm {
  decisionTree,
  logisticRegression,
  knn,
  randomForest,
  gradientBoosting,
}

extension PredictionAlgorithmX on PredictionAlgorithm {
  String get label {
    switch (this) {
      case PredictionAlgorithm.decisionTree:
        return 'Decision Tree';
      case PredictionAlgorithm.logisticRegression:
        return 'Logistic Regression';
      case PredictionAlgorithm.knn:
        return 'K-Nearest Neighbors';
      case PredictionAlgorithm.randomForest:
        return 'Random Forest';
      case PredictionAlgorithm.gradientBoosting:
        return 'Gradient Boosting';
    }
  }

  /// Asset path for the corresponding ONNX model.
  String get assetPath {
    switch (this) {
      case PredictionAlgorithm.decisionTree:
        return 'assets/models/decision_tree.onnx';
      case PredictionAlgorithm.logisticRegression:
        return 'assets/models/logistic_regression.onnx';
      case PredictionAlgorithm.knn:
        return 'assets/models/knn.onnx';
      case PredictionAlgorithm.randomForest:
        return 'assets/models/random_forest.onnx';
      case PredictionAlgorithm.gradientBoosting:
        return 'assets/models/gradient_boosting.onnx';
    }
  }
}

/// Jakarta monitoring stations mapped from the CSV `stasiun` column.
enum JakartaStation {
  jakartaPusat, // DKI1 BUNDARAN HOTEL INDONESIA (HI) — index 0
  jakartaUtara, // DKI2 KELAPA GADING                — index 1
  jakartaSelatan, // DKI3 JAGAKARSA                    — index 2
  jakartaTimur, // DKI4 LUBANG BUAYA                 — index 3
  jakartaBarat, // DKI5 KEBON JERUK                  — index 4
}

extension JakartaStationX on JakartaStation {
  String get label {
    switch (this) {
      case JakartaStation.jakartaPusat:
        return 'Jakarta Pusat';
      case JakartaStation.jakartaUtara:
        return 'Jakarta Utara';
      case JakartaStation.jakartaSelatan:
        return 'Jakarta Selatan';
      case JakartaStation.jakartaTimur:
        return 'Jakarta Timur';
      case JakartaStation.jakartaBarat:
        return 'Jakarta Barat';
    }
  }

  /// Integer encoding used as feature index 2 in the ONNX model.
  int get encodedIndex {
    switch (this) {
      case JakartaStation.jakartaPusat:
        return 0;
      case JakartaStation.jakartaUtara:
        return 1;
      case JakartaStation.jakartaSelatan:
        return 2;
      case JakartaStation.jakartaTimur:
        return 3;
      case JakartaStation.jakartaBarat:
        return 4;
    }
  }

  /// CSV raw station name.
  String get csvName {
    switch (this) {
      case JakartaStation.jakartaPusat:
        return 'DKI1 BUNDARAN HOTEL INDONESIA (HI)';
      case JakartaStation.jakartaUtara:
        return 'DKI2 KELAPA GADING';
      case JakartaStation.jakartaSelatan:
        return 'DKI3 JAGAKARSA';
      case JakartaStation.jakartaTimur:
        return 'DKI4 LUBANG BUAYA';
      case JakartaStation.jakartaBarat:
        return 'DKI5 KEBON JERUK';
    }
  }
}

// ---------------------------------------------------------------------------
// Critical pollutant enum
// ---------------------------------------------------------------------------

enum CriticalPollutant { pm10, pm25, so2, co, o3, no2, unknown }

extension CriticalPollutantX on CriticalPollutant {
  String get label {
    switch (this) {
      case CriticalPollutant.pm10:
        return 'PM10';
      case CriticalPollutant.pm25:
        return 'PM2.5';
      case CriticalPollutant.so2:
        return 'SO₂';
      case CriticalPollutant.co:
        return 'CO';
      case CriticalPollutant.o3:
        return 'O₃';
      case CriticalPollutant.no2:
        return 'NO₂';
      case CriticalPollutant.unknown:
        return '-';
    }
  }

  String get description {
    switch (this) {
      case CriticalPollutant.pm10:
        return 'Partikel debu kasar berdiameter ≤10 µm';
      case CriticalPollutant.pm25:
        return 'Partikel halus berdiameter ≤2.5 µm, dapat masuk paru-paru';
      case CriticalPollutant.so2:
        return 'Sulfur dioksida — dari pembakaran bahan bakar fosil';
      case CriticalPollutant.co:
        return 'Karbon monoksida — gas tidak berwarna & berbau';
      case CriticalPollutant.o3:
        return 'Ozon permukaan tanah — dapat iritasi saluran napas';
      case CriticalPollutant.no2:
        return 'Nitrogen dioksida — dari emisi kendaraan bermotor';
      case CriticalPollutant.unknown:
        return 'Pencemar tidak teridentifikasi';
    }
  }
}

/// Parse CSV `parameter_pencemar_kritis` string to [CriticalPollutant].
/// Top-level function because Dart extensions cannot have static members
/// that are callable on the original type.
CriticalPollutant criticalPollutantFromCsvString(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'PM10':
      return CriticalPollutant.pm10;
    case 'PM25':
      return CriticalPollutant.pm25;
    case 'SO2':
      return CriticalPollutant.so2;
    case 'CO':
      return CriticalPollutant.co;
    case 'O3':
      return CriticalPollutant.o3;
    case 'NO2':
      return CriticalPollutant.no2;
    default:
      return CriticalPollutant.unknown;
  }
}

// ---------------------------------------------------------------------------
// Data Models
// ---------------------------------------------------------------------------

/// One row from the CleanData.csv with all pollutant readings.
class AirQualityRecord {
  final int tahun;
  final int bulan;
  final int hari;
  final JakartaStation station;
  final double? pm10;
  final double? pm25;
  final double? so2;
  final double? co;
  final double? o3;
  final double? no2;
  final double? max;
  final CriticalPollutant criticalPollutant;
  final AirQualityCategory category;

  const AirQualityRecord({
    required this.tahun,
    required this.bulan,
    required this.hari,
    required this.station,
    this.pm10,
    this.pm25,
    this.so2,
    this.co,
    this.o3,
    this.no2,
    this.max,
    required this.criticalPollutant,
    required this.category,
  });

  DateTime get date => DateTime(tahun, bulan, hari);

  /// Convert CSV row (semicolon-delimited) to a record.
  /// Returns null if required fields are missing.
  static AirQualityRecord? fromCsvRow(Map<String, String> row) {
    try {
      final tahun = int.tryParse(row['tahun'] ?? '');
      final bulan = int.tryParse(row['bulan'] ?? '');
      final hari = int.tryParse(row['hari'] ?? '');
      if (tahun == null || bulan == null || hari == null) return null;

      final stationRaw = row['stasiun'] ?? '';
      final station = JakartaStation.values.firstWhere(
        (s) => s.csvName == stationRaw,
        orElse: () => JakartaStation.jakartaPusat,
      );

      final categoryRaw = (row['kategori'] ?? '').trim().toUpperCase();
      AirQualityCategory category;
      switch (categoryRaw) {
        case 'BAIK':
          category = AirQualityCategory.baik;
          break;
        case 'SEDANG':
          category = AirQualityCategory.sedang;
          break;
        case 'TIDAK SEHAT':
          category = AirQualityCategory.tidakSehat;
          break;
        case 'SANGAT TIDAK SEHAT':
          category = AirQualityCategory.sangatTidakSehat;
          break;
        default:
          category = AirQualityCategory.sedang;
      }

      return AirQualityRecord(
        tahun: tahun,
        bulan: bulan,
        hari: hari,
        station: station,
        pm10: double.tryParse(row['pm_sepuluh'] ?? ''),
        pm25: double.tryParse(row['pm_duakomalima'] ?? ''),
        so2: double.tryParse(row['sulfur_dioksida'] ?? ''),
        co: double.tryParse(row['karbon_monoksida'] ?? ''),
        o3: double.tryParse(row['ozon'] ?? ''),
        no2: double.tryParse(row['nitrogen_dioksida'] ?? ''),
        max: double.tryParse(row['max'] ?? ''),
        criticalPollutant: criticalPollutantFromCsvString(
          row['parameter_pencemar_kritis'] ?? '',
        ),
        category: category,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Aggregated monthly statistics for a station, used when estimating missing
/// feature values for future date predictions.
class MonthlyStationStats {
  final int bulan;
  final JakartaStation station;
  final double avgPm10;
  final double avgPm25;
  final double avgMax;
  final AirQualityCategory dominantCategory;
  final CriticalPollutant dominantPollutant;

  const MonthlyStationStats({
    required this.bulan,
    required this.station,
    required this.avgPm10,
    required this.avgPm25,
    required this.avgMax,
    required this.dominantCategory,
    required this.dominantPollutant,
  });
}

/// The result returned to the UI after an ONNX prediction run.
class PredictionResult {
  /// Predicted air quality category.
  final AirQualityCategory predictedCategory;

  /// Probability map: category → confidence [0.0–1.0].
  final Map<AirQualityCategory, double> probabilities;

  /// Most likely critical pollutant (estimated from historical averages).
  final CriticalPollutant likelyCriticalPollutant;

  /// Estimated pollutant concentrations used as model input.
  final Map<String, double> estimatedFeatures;

  /// The algorithm that produced this prediction.
  final PredictionAlgorithm algorithm;

  /// Target date for the prediction.
  final DateTime targetDate;

  /// Station for the prediction.
  final JakartaStation station;

  /// Whether historical data was available for this month/station.
  final bool hasHistoricalData;

  const PredictionResult({
    required this.predictedCategory,
    required this.probabilities,
    required this.likelyCriticalPollutant,
    required this.estimatedFeatures,
    required this.algorithm,
    required this.targetDate,
    required this.station,
    required this.hasHistoricalData,
  });

  /// Confidence of the top predicted category.
  double get confidence => probabilities[predictedCategory] ?? 0.0;

  /// Sorted list of (category, probability) pairs, descending by probability.
  List<MapEntry<AirQualityCategory, double>> get sortedProbabilities {
    final entries = probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}
