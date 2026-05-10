// data_service.dart
// Handles:
//   • CsvService   — loads CleanData.csv from assets and parses rows
//   • FeatureBuilder — computes the 6 model features for any future date
//
// Feature order expected by every ONNX model (float_input shape [1,6]):
//   [0] bulan            (1–12)
//   [1] hari             (1–31)
//   [2] stasiun_encoded  (0–4)  DKI1=0, DKI2=1, DKI3=2, DKI4=3, DKI5=4
//   [3] pm_sepuluh       (PM10 µg/m³)
//   [4] pm_duakomalima   (PM2.5 µg/m³)
//   [5] max              (max pollutant value of the day)

import 'package:flutter/services.dart';
import 'package:jaksky_app/models/air_quality_model.dart';

// ---------------------------------------------------------------------------
// CsvService
// ---------------------------------------------------------------------------

class CsvService {
  static const String _assetPath = 'assets/data/CleanData.csv';

  CsvService._();
  static final CsvService instance = CsvService._();

  List<AirQualityRecord>? _cachedRecords;

  /// Load and parse CleanData.csv from assets.
  /// Results are cached after the first load.
  Future<List<AirQualityRecord>> loadRecords() async {
    if (_cachedRecords != null) return _cachedRecords!;

    final raw = await rootBundle.loadString(_assetPath);
    final lines = raw.split('\n');
    if (lines.isEmpty) return [];

    // The CSV uses semicolons as delimiters and has a UTF-8 BOM on the first
    // column header; clean it up before parsing.
    final header = lines.first
        .replaceAll('\r', '')
        .replaceAll('\uFEFF', '')
        .split(';');

    final records = <AirQualityRecord>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].replaceAll('\r', '').trim();
      if (line.isEmpty) continue;

      final values = line.split(';');
      if (values.length < header.length) continue;

      final rowMap = <String, String>{};
      for (int j = 0; j < header.length; j++) {
        rowMap[header[j].trim()] = values[j].trim();
      }

      final record = AirQualityRecord.fromCsvRow(rowMap);
      if (record != null) records.add(record);
    }

    _cachedRecords = records;
    return records;
  }

  /// Filter records by station.
  Future<List<AirQualityRecord>> recordsForStation(
    JakartaStation station,
  ) async {
    final all = await loadRecords();
    return all.where((r) => r.station == station).toList();
  }

  /// Filter records by station + month.
  Future<List<AirQualityRecord>> recordsForStationAndMonth(
    JakartaStation station,
    int bulan,
  ) async {
    final all = await loadRecords();
    return all.where((r) => r.station == station && r.bulan == bulan).toList();
  }

  /// Compute [MonthlyStationStats] for all station/month combinations.
  /// Used by [FeatureBuilder] when no exact-date record exists.
  Future<Map<String, MonthlyStationStats>> buildMonthlyStats() async {
    final all = await loadRecords();

    // Group by "station-month" key
    final groups = <String, List<AirQualityRecord>>{};
    for (final r in all) {
      final key = '${r.station.encodedIndex}_${r.bulan}';
      groups.putIfAbsent(key, () => []).add(r);
    }

    final stats = <String, MonthlyStationStats>{};
    for (final entry in groups.entries) {
      final rows = entry.value;
      final station = rows.first.station;
      final bulan = rows.first.bulan;

      final pm10Vals = rows.map((r) => r.pm10).whereType<double>().toList();
      final pm25Vals = rows.map((r) => r.pm25).whereType<double>().toList();
      final maxVals = rows.map((r) => r.max).whereType<double>().toList();

      final avgPm10 = pm10Vals.isNotEmpty
          ? pm10Vals.reduce((a, b) => a + b) / pm10Vals.length
          : _globalDefaultPm10(station);
      final avgPm25 = pm25Vals.isNotEmpty
          ? pm25Vals.reduce((a, b) => a + b) / pm25Vals.length
          : _globalDefaultPm25(station);
      final avgMax = maxVals.isNotEmpty
          ? maxVals.reduce((a, b) => a + b) / maxVals.length
          : avgPm25;

      // Dominant category
      final catCount = <AirQualityCategory, int>{};
      for (final r in rows) {
        catCount[r.category] = (catCount[r.category] ?? 0) + 1;
      }
      final dominantCategory = catCount.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;

      // Dominant pollutant
      final pollCount = <CriticalPollutant, int>{};
      for (final r in rows) {
        pollCount[r.criticalPollutant] =
            (pollCount[r.criticalPollutant] ?? 0) + 1;
      }
      final dominantPollutant = pollCount.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;

      stats[entry.key] = MonthlyStationStats(
        bulan: bulan,
        station: station,
        avgPm10: avgPm10,
        avgPm25: avgPm25,
        avgMax: avgMax,
        dominantCategory: dominantCategory,
        dominantPollutant: dominantPollutant,
      );
    }

    return stats;
  }

  // Fallback defaults based on overall dataset averages per station area.
  double _globalDefaultPm10(JakartaStation station) {
    const defaults = {
      JakartaStation.jakartaPusat: 49.0,
      JakartaStation.jakartaUtara: 52.0,
      JakartaStation.jakartaSelatan: 47.0,
      JakartaStation.jakartaTimur: 51.0,
      JakartaStation.jakartaBarat: 53.0,
    };
    return defaults[station] ?? 51.0;
  }

  double _globalDefaultPm25(JakartaStation station) {
    const defaults = {
      JakartaStation.jakartaPusat: 72.0,
      JakartaStation.jakartaUtara: 78.0,
      JakartaStation.jakartaSelatan: 70.0,
      JakartaStation.jakartaTimur: 76.0,
      JakartaStation.jakartaBarat: 79.0,
    };
    return defaults[station] ?? 75.0;
  }
}

// ---------------------------------------------------------------------------
// FeatureBuilder
// ---------------------------------------------------------------------------

/// Builds the 6-element float feature vector for a given future date and
/// station, using historical averages from the CSV data.
///
/// Feature vector layout (matches ONNX model training):
///   index 0 → bulan  (1–12)
///   index 1 → hari   (1–31)
///   index 2 → stasiun_encoded (0–4)
///   index 3 → pm_sepuluh  (PM10)
///   index 4 → pm_duakomalima (PM2.5)
///   index 5 → max
class FeatureBuilder {
  final CsvService _csvService;
  Map<String, MonthlyStationStats>? _monthlyStats;

  FeatureBuilder({CsvService? csvService})
    : _csvService = csvService ?? CsvService.instance;

  Future<void> _ensureStats() async {
    _monthlyStats ??= await _csvService.buildMonthlyStats();
  }

  /// Build feature vector for [targetDate] at [station].
  ///
  /// Returns a named feature map (for display) and the ordered float list
  /// ready to pass into the ONNX session.
  Future<BuiltFeatures> buildFeatures({
    required DateTime targetDate,
    required JakartaStation station,
  }) async {
    await _ensureStats();

    final bulan = targetDate.month;
    final hari = targetDate.day;
    final stationCode = station.encodedIndex.toDouble();

    final key = '${station.encodedIndex}_$bulan';
    final stats = _monthlyStats![key];

    bool hasHistoricalData;
    double pm10, pm25, maxVal;
    CriticalPollutant criticalPollutant;

    if (stats != null) {
      pm10 = stats.avgPm10;
      pm25 = stats.avgPm25;
      maxVal = stats.avgMax;
      criticalPollutant = stats.dominantPollutant;
      hasHistoricalData = true;
    } else {
      // No historical data for this station/month → use station-level defaults
      // with a seasonal adjustment factor.
      pm10 = _csvService._globalDefaultPm10(station) * _seasonalFactor(bulan);
      pm25 = _csvService._globalDefaultPm25(station) * _seasonalFactor(bulan);
      maxVal = pm25;
      criticalPollutant = CriticalPollutant.pm25;
      hasHistoricalData = false;
    }

    final featureVector = [
      bulan.toDouble(),
      hari.toDouble(),
      stationCode,
      pm10,
      pm25,
      maxVal,
    ];

    return BuiltFeatures(
      featureVector: featureVector,
      namedFeatures: {
        'Bulan': bulan.toDouble(),
        'Hari': hari.toDouble(),
        'Stasiun (encoded)': stationCode,
        'PM10 (µg/m³)': pm10,
        'PM2.5 (µg/m³)': pm25,
        'Max': maxVal,
      },
      criticalPollutant: criticalPollutant,
      hasHistoricalData: hasHistoricalData,
    );
  }

  /// Seasonal adjustment: dry season (Jun–Sep) in Jakarta has higher pollution.
  double _seasonalFactor(int bulan) {
    // Dry season months: June–September → 10% above average
    if (bulan >= 6 && bulan <= 9) return 1.10;
    // Wet season: Nov–Mar → 5% below average (rain washes particulates)
    if (bulan >= 11 || bulan <= 3) return 0.95;
    // Transition months
    return 1.00;
  }
}

/// Output from [FeatureBuilder.buildFeatures].
class BuiltFeatures {
  /// Ordered list ready for ONNX input (shape: [1, 6]).
  final List<double> featureVector;

  /// Human-readable map for display in the UI.
  final Map<String, double> namedFeatures;

  /// Estimated dominant pollutant based on historical data.
  final CriticalPollutant criticalPollutant;

  /// Whether historical monthly averages were available.
  final bool hasHistoricalData;

  const BuiltFeatures({
    required this.featureVector,
    required this.namedFeatures,
    required this.criticalPollutant,
    required this.hasHistoricalData,
  });
}
