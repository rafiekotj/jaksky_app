// lib/models/air_quality_model.dart
//
// Model kelas, enum, dan data historis kualitas udara Jakarta.
// Digunakan sebagai kontrak data bersama di seluruh aplikasi.

import 'dart:math';

// ─── Enum Lokasi ─────────────────────────────────────────────────────────────

enum JakartaLocation {
  jakartaPusat('Jakarta Pusat', 'pusat'),
  jakartaUtara('Jakarta Utara', 'utara'),
  jakartaTimur('Jakarta Timur', 'timur'),
  jakartaSelatan('Jakarta Selatan', 'selatan'),
  jakartaBarat('Jakarta Barat', 'barat');

  const JakartaLocation(this.displayName, this.key);
  final String displayName;
  final String key;
}

// ─── Enum Algoritma ──────────────────────────────────────────────────────────

enum AirQualityAlgorithm {
  randomForest(
    'Random Forest',
    'random_forest',
    'assets/models/random_forest.onnx',
  ),
  decisionTree(
    'Decision Tree',
    'decision_tree',
    'assets/models/decision_tree.onnx',
  ),
  gradientBoosting(
    'Gradient Boosting',
    'gradient_boosting',
    'assets/models/gradient_boosting.onnx',
  ),
  knn('K-Nearest Neighbors', 'knn', 'assets/models/knn.onnx'),
  logisticRegression(
    'Logistic Regression',
    'logistic_regression',
    'assets/models/logistic_regression.onnx',
  );

  const AirQualityAlgorithm(this.displayName, this.key, this.assetPath);
  final String displayName;
  final String key;
  final String assetPath;
}

// ─── Enum Kategori Kualitas Udara ────────────────────────────────────────────
//
// CLASS INDEX (urutan alfabetis LabelEncoder):
//   0 → BAIK
//   1 → SANGAT TIDAK SEHAT
//   2 → SEDANG
//   3 → TIDAK SEHAT

enum AirQualityCategory {
  baik(0, 'BAIK', 'Baik'),
  sangatTidakSehat(1, 'SANGAT TIDAK SEHAT', 'Sangat Tidak Sehat'),
  sedang(2, 'SEDANG', 'Sedang'),
  tidakSehat(3, 'TIDAK SEHAT', 'Tidak Sehat');

  const AirQualityCategory(this.classIndex, this.rawLabel, this.displayName);
  final int classIndex;
  final String rawLabel;
  final String displayName;

  static AirQualityCategory fromIndex(int index) {
    return AirQualityCategory.values.firstWhere(
      (e) => e.classIndex == index,
      orElse: () => AirQualityCategory.sedang,
    );
  }

  static AirQualityCategory fromLabel(String label) {
    return AirQualityCategory.values.firstWhere(
      (e) => e.rawLabel == label.toUpperCase(),
      orElse: () => AirQualityCategory.sedang,
    );
  }
}

// ─── Model Fitur Input ───────────────────────────────────────────────────────
//
// 6 fitur: pm10, pm2.5, so2, co, o3, no2
// Urutan sesuai INPUT CONTRACT model ONNX: float_input [1, 6]

class AirQualityFeatures {
  final double pm10; // PM10  (µg/m³)
  final double pm25; // PM2.5 (µg/m³)
  final double so2; // SO2   (µg/m³)
  final double co; // CO    (mg/m³)
  final double o3; // O3    (µg/m³)
  final double no2; // NO2   (µg/m³)

  const AirQualityFeatures({
    required this.pm10,
    required this.pm25,
    required this.so2,
    required this.co,
    required this.o3,
    required this.no2,
  });

  /// Konversi ke flat list float untuk input ONNX [pm10, pm25, so2, co, o3, no2]
  List<double> toInputList() => [pm10, pm25, so2, co, o3, no2];

  /// Nama kolom CSV → field (sesuai CleanDatas.csv)
  static const List<String> csvColumnNames = [
    'pm_sepuluh',
    'pm_duakomalima',
    'sulfur_dioksida',
    'karbon_monoksida',
    'ozon',
    'nitrogen_dioksida',
  ];

  /// Nama display untuk UI
  static const Map<String, String> displayNames = {
    'pm10': 'PM10',
    'pm25': 'PM2.5',
    'so2': 'SO₂',
    'co': 'CO',
    'o3': 'O₃',
    'no2': 'NO₂',
  };

  /// Satuan tiap polutan
  static const Map<String, String> units = {
    'pm10': 'µg/m³',
    'pm25': 'µg/m³',
    'so2': 'µg/m³',
    'co': 'mg/m³',
    'o3': 'µg/m³',
    'no2': 'µg/m³',
  };

  Map<String, double> toMap() => {
    'pm10': pm10,
    'pm25': pm25,
    'so2': so2,
    'co': co,
    'o3': o3,
    'no2': no2,
  };

  @override
  String toString() =>
      'AirQualityFeatures(pm10=$pm10, pm25=$pm25, so2=$so2, co=$co, o3=$o3, no2=$no2)';
}

// ─── Model Hasil Prediksi ─────────────────────────────────────────────────────

class AirQualityPrediction {
  final DateTime targetDate;
  final JakartaLocation location;
  final AirQualityAlgorithm algorithm;
  final AirQualityCategory category;
  final Map<String, double> probabilities; // key: rawLabel, value: prob
  final AirQualityFeatures features;
  final List<PollutantInfo> dominantPollutants;
  final bool isEstimated; // true jika data historis tidak ada (perkiraan)
  final DateTime predictedAt;

  const AirQualityPrediction({
    required this.targetDate,
    required this.location,
    required this.algorithm,
    required this.category,
    required this.probabilities,
    required this.features,
    required this.dominantPollutants,
    required this.isEstimated,
    required this.predictedAt,
  });

  /// Probabilitas kategori tertentu (0.0 - 1.0)
  double probabilityOf(AirQualityCategory cat) =>
      probabilities[cat.rawLabel] ?? 0.0;

  /// Probabilitas kategori terpilih (confidence)
  double get confidence => probabilityOf(category);

  AirQualityPrediction copyWith({
    DateTime? targetDate,
    JakartaLocation? location,
    AirQualityAlgorithm? algorithm,
    AirQualityCategory? category,
    Map<String, double>? probabilities,
    AirQualityFeatures? features,
    List<PollutantInfo>? dominantPollutants,
    bool? isEstimated,
    DateTime? predictedAt,
  }) {
    return AirQualityPrediction(
      targetDate: targetDate ?? this.targetDate,
      location: location ?? this.location,
      algorithm: algorithm ?? this.algorithm,
      category: category ?? this.category,
      probabilities: probabilities ?? this.probabilities,
      features: features ?? this.features,
      dominantPollutants: dominantPollutants ?? this.dominantPollutants,
      isEstimated: isEstimated ?? this.isEstimated,
      predictedAt: predictedAt ?? this.predictedAt,
    );
  }
}

// ─── Model Info Polutan ───────────────────────────────────────────────────────

class PollutantInfo {
  final String key; // 'pm10', 'pm25', dll.
  final String name; // display name
  final String unit;
  final double value;
  final PollutantLevel level;

  const PollutantInfo({
    required this.key,
    required this.name,
    required this.unit,
    required this.value,
    required this.level,
  });
}

enum PollutantLevel {
  good('Baik'),
  moderate('Sedang'),
  unhealthy('Tidak Sehat'),
  veryUnhealthy('Sangat Tidak Sehat');

  const PollutantLevel(this.label);
  final String label;
}

/// Hitung level polutan berdasarkan ambang batas ISPU Indonesia
PollutantLevel pollutantLevel(String key, double value) {
  switch (key) {
    case 'pm10':
      if (value <= 50) return PollutantLevel.good;
      if (value <= 150) return PollutantLevel.moderate;
      if (value <= 350) return PollutantLevel.unhealthy;
      return PollutantLevel.veryUnhealthy;
    case 'pm25':
      if (value <= 15.5) return PollutantLevel.good;
      if (value <= 55.4) return PollutantLevel.moderate;
      if (value <= 150.4) return PollutantLevel.unhealthy;
      return PollutantLevel.veryUnhealthy;
    case 'so2':
      if (value <= 52) return PollutantLevel.good;
      if (value <= 180) return PollutantLevel.moderate;
      if (value <= 800) return PollutantLevel.unhealthy;
      return PollutantLevel.veryUnhealthy;
    case 'co':
      if (value <= 4.0) return PollutantLevel.good;
      if (value <= 9.0) return PollutantLevel.moderate;
      if (value <= 15.0) return PollutantLevel.unhealthy;
      return PollutantLevel.veryUnhealthy;
    case 'o3':
      if (value <= 50) return PollutantLevel.good;
      if (value <= 100) return PollutantLevel.moderate;
      if (value <= 200) return PollutantLevel.unhealthy;
      return PollutantLevel.veryUnhealthy;
    case 'no2':
      if (value <= 40) return PollutantLevel.good;
      if (value <= 100) return PollutantLevel.moderate;
      if (value <= 200) return PollutantLevel.unhealthy;
      return PollutantLevel.veryUnhealthy;
    default:
      return PollutantLevel.moderate;
  }
}

// ─── Data Record CSV ─────────────────────────────────────────────────────────
//
// Format CSV aktual (13 kolom):
//   tahun, bulan, hari, stasiun, pm_sepuluh, pm_duakomalima,
//   sulfur_dioksida, karbon_monoksida, ozon, nitrogen_dioksida,
//   max, parameter_pencemar_kritis, kategori
//
// Kolom 'max' dan 'parameter_pencemar_kritis' diabaikan (ignored).
// Tanggal dibangun dari 3 kolom terpisah: tahun + bulan + hari.
// Stasiun dipetakan ke JakartaLocation via kode DKI1–DKI5.

class AirQualityRecord {
  final DateTime date;
  final String stasiun; // nama stasiun asli dari CSV, e.g. "DKI1 BUNDARAN HI"
  final JakartaLocation location; // lokasi yang dipetakan dari stasiun
  final AirQualityFeatures features;
  final AirQualityCategory category;

  const AirQualityRecord({
    required this.date,
    required this.stasiun,
    required this.location,
    required this.features,
    required this.category,
  });

  /// Buat dari Map hasil parsing CSV.
  ///
  /// Kolom yang dibaca:
  ///   tahun, bulan, hari        → DateTime
  ///   stasiun                   → dipetakan ke JakartaLocation
  ///   pm_sepuluh … nitrogen_dioksida → AirQualityFeatures
  ///   kategori                  → AirQualityCategory
  ///
  /// Kolom yang DIABAIKAN: max, parameter_pencemar_kritis
  factory AirQualityRecord.fromCsvRow(Map<String, dynamic> row) {
    final stasiun = row['stasiun']?.toString() ?? '';
    return AirQualityRecord(
      date: _buildDate(row),
      stasiun: stasiun,
      location: _stasiunToLocation(stasiun),
      features: AirQualityFeatures(
        pm10: _toDouble(row['pm_sepuluh']),
        pm25: _toDouble(row['pm_duakomalima']),
        so2: _toDouble(row['sulfur_dioksida']),
        co: _toDouble(row['karbon_monoksida']),
        o3: _toDouble(row['ozon']),
        no2: _toDouble(row['nitrogen_dioksida']),
      ),
      category: AirQualityCategory.fromLabel(
        row['kategori']?.toString() ?? 'SEDANG',
      ),
      // 'max' dan 'parameter_pencemar_kritis' sengaja tidak dibaca
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  /// Bangun DateTime dari kolom terpisah: tahun, bulan, hari
  static DateTime _buildDate(Map<String, dynamic> row) {
    try {
      final year = int.parse(row['tahun'].toString());
      final month = int.parse(row['bulan'].toString());
      final day = int.parse(row['hari'].toString());
      return DateTime(year, month, day);
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Petakan nama stasiun DKI ke [JakartaLocation].
  ///
  /// Mapping berdasarkan kode stasiun resmi BMKG/KLHK:
  ///   DKI1 (Bundaran HI)   → Jakarta Pusat
  ///   DKI2 (Kelapa Gading) → Jakarta Utara
  ///   DKI3 (Jagakarsa)     → Jakarta Selatan
  ///   DKI4 (Lubang Buaya)  → Jakarta Timur
  ///   DKI5 (Kebon Jeruk)   → Jakarta Barat
  static JakartaLocation _stasiunToLocation(String stasiun) {
    final upper = stasiun.toUpperCase();
    if (upper.contains('DKI1')) return JakartaLocation.jakartaPusat;
    if (upper.contains('DKI2')) return JakartaLocation.jakartaUtara;
    if (upper.contains('DKI3')) return JakartaLocation.jakartaSelatan;
    if (upper.contains('DKI4')) return JakartaLocation.jakartaTimur;
    if (upper.contains('DKI5')) return JakartaLocation.jakartaBarat;
    // Fallback: coba dari nama kota jika kode DKI tidak ditemukan
    if (upper.contains('BUNDARAN') || upper.contains('HOTEL INDONESIA'))
      return JakartaLocation.jakartaPusat;
    if (upper.contains('KELAPA GADING')) return JakartaLocation.jakartaUtara;
    if (upper.contains('JAGAKARSA')) return JakartaLocation.jakartaSelatan;
    if (upper.contains('LUBANG BUAYA')) return JakartaLocation.jakartaTimur;
    if (upper.contains('KEBON JERUK')) return JakartaLocation.jakartaBarat;
    return JakartaLocation.jakartaPusat; // default
  }
}

// ─── Data Historis Sintetis (Fallback jika CSV tidak ada / tanggal kosong) ───
//
// Baseline rata-rata polutan per lokasi Jakarta berdasarkan laporan KLHK 2019-2023.
// Digunakan untuk estimasi ketika data historis CSV tidak mencakup tanggal target.

class HistoricalBaselineData {
  /// Rata-rata bulanan polutan per lokasi (index 0=Jan … 11=Des)
  static const Map<String, List<double>> _pm10Baseline = {
    'pusat': [72, 68, 65, 60, 58, 62, 70, 73, 69, 66, 71, 75],
    'utara': [85, 80, 76, 70, 66, 68, 76, 80, 78, 74, 82, 88],
    'timur': [78, 74, 70, 65, 61, 64, 72, 76, 73, 69, 76, 82],
    'selatan': [65, 62, 58, 54, 51, 53, 61, 65, 62, 59, 64, 70],
    'barat': [80, 76, 72, 67, 63, 66, 74, 78, 75, 71, 78, 84],
  };

  static const Map<String, List<double>> _pm25Baseline = {
    'pusat': [42, 40, 38, 35, 33, 36, 41, 44, 41, 38, 42, 46],
    'utara': [50, 47, 44, 40, 37, 39, 44, 48, 46, 42, 48, 53],
    'timur': [46, 43, 40, 37, 34, 36, 42, 45, 43, 39, 45, 50],
    'selatan': [38, 36, 34, 31, 29, 31, 37, 40, 38, 35, 39, 43],
    'barat': [48, 45, 42, 38, 35, 38, 43, 47, 45, 41, 46, 51],
  };

  static const Map<String, List<double>> _so2Baseline = {
    'pusat': [14, 13, 12, 11, 10, 11, 13, 14, 13, 12, 14, 15],
    'utara': [18, 17, 16, 14, 13, 14, 16, 18, 17, 15, 17, 19],
    'timur': [16, 15, 14, 13, 12, 13, 15, 16, 15, 14, 16, 17],
    'selatan': [12, 11, 10, 9, 8, 9, 11, 12, 11, 10, 12, 13],
    'barat': [17, 16, 15, 13, 12, 13, 15, 17, 16, 14, 16, 18],
  };

  static const Map<String, List<double>> _coBaseline = {
    'pusat': [1.8, 1.7, 1.6, 1.5, 1.4, 1.5, 1.7, 1.9, 1.8, 1.6, 1.8, 2.0],
    'utara': [2.2, 2.1, 2.0, 1.8, 1.7, 1.8, 2.0, 2.2, 2.1, 1.9, 2.1, 2.4],
    'timur': [2.0, 1.9, 1.8, 1.6, 1.5, 1.6, 1.8, 2.0, 1.9, 1.7, 1.9, 2.1],
    'selatan': [1.6, 1.5, 1.4, 1.3, 1.2, 1.3, 1.5, 1.7, 1.6, 1.4, 1.6, 1.8],
    'barat': [2.1, 2.0, 1.9, 1.7, 1.6, 1.7, 1.9, 2.1, 2.0, 1.8, 2.0, 2.2],
  };

  static const Map<String, List<double>> _o3Baseline = {
    'pusat': [52, 56, 60, 64, 68, 65, 58, 54, 57, 61, 55, 50],
    'utara': [45, 49, 53, 57, 61, 58, 51, 47, 50, 54, 48, 43],
    'timur': [55, 59, 63, 67, 71, 68, 61, 57, 60, 64, 58, 53],
    'selatan': [60, 64, 68, 72, 76, 73, 66, 62, 65, 69, 63, 58],
    'barat': [48, 52, 56, 60, 64, 61, 54, 50, 53, 57, 51, 46],
  };

  static const Map<String, List<double>> _no2Baseline = {
    'pusat': [28, 27, 25, 23, 21, 22, 26, 29, 27, 25, 28, 31],
    'utara': [35, 33, 31, 28, 26, 27, 31, 35, 33, 30, 34, 38],
    'timur': [32, 30, 28, 26, 24, 25, 29, 32, 30, 28, 31, 34],
    'selatan': [24, 23, 21, 19, 18, 19, 22, 25, 23, 21, 24, 27],
    'barat': [33, 31, 29, 27, 25, 26, 30, 33, 31, 28, 32, 36],
  };

  /// Hitung estimasi fitur untuk tanggal dan lokasi tertentu.
  /// Menambahkan sedikit noise untuk membuat tiap prediksi unik.
  static AirQualityFeatures estimateFeatures(
    DateTime date,
    JakartaLocation location, {
    int? seed,
  }) {
    final key = location.key;
    final monthIdx = date.month - 1;
    final rng = Random(seed ?? date.millisecondsSinceEpoch ~/ 86400000);

    double jitter(double base, double range) =>
        base + (rng.nextDouble() - 0.5) * range;

    // Faktor musim kemarau (Apr-Sep) lebih bersih, musim hujan lebih kotor
    final double seasonFactor = (date.month >= 4 && date.month <= 9)
        ? 0.95
        : 1.05;

    return AirQualityFeatures(
      pm10: jitter(_pm10Baseline[key]![monthIdx] * seasonFactor, 10),
      pm25: jitter(_pm25Baseline[key]![monthIdx] * seasonFactor, 6),
      so2: jitter(_so2Baseline[key]![monthIdx] * seasonFactor, 2),
      co: jitter(_coBaseline[key]![monthIdx] * seasonFactor, 0.3),
      o3: jitter(_o3Baseline[key]![monthIdx] / seasonFactor, 8), // O3 terbalik
      no2: jitter(_no2Baseline[key]![monthIdx] * seasonFactor, 5),
    );
  }
}
