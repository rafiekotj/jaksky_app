// lib/services/data_service.dart
//
// Gabungan CsvService + FeatureBuilder.
//
// CsvService   → memuat dan mem-parsing CleanDatas.csv dari assets
// FeatureBuilder → menentukan fitur input untuk tanggal & lokasi target
//                 menggunakan data historis atau estimasi sintetis sebagai fallback

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:jaksky_app/models/air_quality_model.dart';

// ─── CsvService ───────────────────────────────────────────────────────────────

class CsvService {
  static const String _csvAssetPath = 'assets/data/CleanDatas.csv';

  List<AirQualityRecord>? _cachedRecords;

  /// Muat semua record dari CSV. Hasil di-cache setelah load pertama.
  Future<List<AirQualityRecord>> loadRecords() async {
    if (_cachedRecords != null) return _cachedRecords!;

    try {
      final raw = await rootBundle.loadString(_csvAssetPath);
      _cachedRecords = _parseCsv(raw);
      debugPrint(
        '[CsvService] Loaded ${_cachedRecords!.length} records dari CSV',
      );
      return _cachedRecords!;
    } catch (e) {
      debugPrint(
        '[CsvService] Gagal memuat CSV: $e — akan menggunakan data estimasi',
      );
      _cachedRecords = [];
      return _cachedRecords!;
    }
  }

  /// Filter record berdasarkan lokasi
  Future<List<AirQualityRecord>> recordsForLocation(
    JakartaLocation location,
  ) async {
    final all = await loadRecords();
    // r.location adalah JakartaLocation yang sudah dipetakan via _stasiunToLocation
    // DKI1→jakartaPusat, DKI2→jakartaUtara, DKI3→jakartaSelatan,
    // DKI4→jakartaTimur, DKI5→jakartaBarat
    return all.where((r) => r.location == location).toList();
  }

  /// Filter record berdasarkan lokasi dan bulan tertentu (lintas tahun)
  Future<List<AirQualityRecord>> recordsForLocationAndMonth(
    JakartaLocation location,
    int month,
  ) async {
    final records = await recordsForLocation(location);
    return records.where((r) => r.date.month == month).toList();
  }

  // ── CSV Parsing ────────────────────────────────────────────────────────────

  List<AirQualityRecord> _parseCsv(String raw) {
    final lines = raw.split('\n');
    if (lines.isEmpty) return [];

    // Baris pertama = header
    final headers = _splitCsvLine(
      lines.first,
    ).map((h) => h.trim().toLowerCase()).toList();

    final records = <AirQualityRecord>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final values = _splitCsvLine(line);
      if (values.length < headers.length) continue;

      final row = <String, dynamic>{};
      for (int j = 0; j < headers.length; j++) {
        row[headers[j]] = values[j].trim();
      }

      try {
        records.add(AirQualityRecord.fromCsvRow(row));
      } catch (e) {
        debugPrint('[CsvService] Skip baris $i: $e');
      }
    }
    return records;
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  void clearCache() {
    _cachedRecords = null;
  }
}

// ─── FeatureBuilder ───────────────────────────────────────────────────────────

class FeatureBuilder {
  final CsvService _csvService;

  FeatureBuilder({CsvService? csvService})
    : _csvService = csvService ?? CsvService();

  /// Bangun fitur input untuk tanggal dan lokasi target.
  ///
  /// Strategi:
  ///  1. Cari rekaman historis pada tanggal yang sama (bulan & hari) di tahun-tahun sebelumnya
  ///  2. Jika ada → rata-rata nilai polutan rekaman tersebut
  ///  3. Jika tidak ada → gunakan estimasi sintetis berbasis baseline lokasi + musim
  Future<FeatureBuildResult> buildFeatures(
    DateTime targetDate,
    JakartaLocation location,
  ) async {
    // Step 1: cari data historis pada bulan & hari yang sama
    final monthRecords = await _csvService.recordsForLocationAndMonth(
      location,
      targetDate.month,
    );

    // Filter hari ±3 hari untuk sample yang lebih banyak
    final nearbyRecords = monthRecords.where((r) {
      final diff = (r.date.day - targetDate.day).abs();
      return diff <= 3;
    }).toList();

    if (nearbyRecords.isNotEmpty) {
      final features = _averageFeatures(nearbyRecords);
      return FeatureBuildResult(
        features: features,
        isEstimated: false,
        sourceRecordCount: nearbyRecords.length,
        sourceDescription:
            '${nearbyRecords.length} data historis (±3 hari, bulan ${targetDate.month})',
      );
    }

    // Step 2: coba rata-rata seluruh bulan yang sama
    if (monthRecords.isNotEmpty) {
      final features = _averageFeatures(monthRecords);
      return FeatureBuildResult(
        features: features,
        isEstimated: false,
        sourceRecordCount: monthRecords.length,
        sourceDescription:
            '${monthRecords.length} data historis (bulan ${targetDate.month})',
      );
    }

    // Step 3: fallback estimasi sintetis
    debugPrint(
      '[FeatureBuilder] Tidak ada data historis untuk ${location.displayName} '
      'bulan=${targetDate.month}, menggunakan estimasi baseline',
    );
    final features = HistoricalBaselineData.estimateFeatures(
      targetDate,
      location,
      seed: targetDate.year * 10000 + targetDate.month * 100 + targetDate.day,
    );
    return FeatureBuildResult(
      features: features,
      isEstimated: true,
      sourceRecordCount: 0,
      sourceDescription:
          'Estimasi berbasis baseline historis ${location.displayName}',
    );
  }

  /// Rata-rata fitur dari kumpulan rekaman
  AirQualityFeatures _averageFeatures(List<AirQualityRecord> records) {
    if (records.isEmpty) {
      return const AirQualityFeatures(
        pm10: 0,
        pm25: 0,
        so2: 0,
        co: 0,
        o3: 0,
        no2: 0,
      );
    }

    double sumPm10 = 0, sumPm25 = 0, sumSo2 = 0;
    double sumCo = 0, sumO3 = 0, sumNo2 = 0;
    final n = records.length.toDouble();

    for (final r in records) {
      sumPm10 += r.features.pm10;
      sumPm25 += r.features.pm25;
      sumSo2 += r.features.so2;
      sumCo += r.features.co;
      sumO3 += r.features.o3;
      sumNo2 += r.features.no2;
    }

    return AirQualityFeatures(
      pm10: _clamp(sumPm10 / n, 0, 600),
      pm25: _clamp(sumPm25 / n, 0, 300),
      so2: _clamp(sumSo2 / n, 0, 1000),
      co: _clamp(sumCo / n, 0, 50),
      o3: _clamp(sumO3 / n, 0, 400),
      no2: _clamp(sumNo2 / n, 0, 400),
    );
  }

  double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);

  /// Bangun daftar [PollutantInfo] dari fitur + tentukan polutan dominan
  List<PollutantInfo> buildPollutantInfoList(AirQualityFeatures features) {
    final map = features.toMap();
    return map.entries.map((e) {
      return PollutantInfo(
        key: e.key,
        name: AirQualityFeatures.displayNames[e.key] ?? e.key,
        unit: AirQualityFeatures.units[e.key] ?? '',
        value: e.value,
        level: pollutantLevel(e.key, e.value),
      );
    }).toList()..sort((a, b) => b.level.index.compareTo(a.level.index));
  }
}

// ─── FeatureBuildResult ───────────────────────────────────────────────────────

class FeatureBuildResult {
  final AirQualityFeatures features;
  final bool isEstimated;
  final int sourceRecordCount;
  final String sourceDescription;

  const FeatureBuildResult({
    required this.features,
    required this.isEstimated,
    required this.sourceRecordCount,
    required this.sourceDescription,
  });
}

// ─── DataService (fasad) ──────────────────────────────────────────────────────
//
// Gabungkan CsvService + FeatureBuilder menjadi satu titik akses.

class DataService {
  final CsvService csvService;
  final FeatureBuilder featureBuilder;

  DataService() : csvService = CsvService(), featureBuilder = FeatureBuilder() {
    // Gunakan instance CsvService yang sama
    // ignore: prefer_initializing_formals
  }

  DataService.withDeps({
    required this.csvService,
    required this.featureBuilder,
  });

  /// Muat semua data historis (panggil di init)
  Future<void> init() async {
    await csvService.loadRecords();
  }

  /// Bangun fitur untuk prediksi
  Future<FeatureBuildResult> buildFeatures(
    DateTime targetDate,
    JakartaLocation location,
  ) => featureBuilder.buildFeatures(targetDate, location);

  /// Bangun info polutan untuk ditampilkan di UI
  List<PollutantInfo> buildPollutantInfo(AirQualityFeatures features) =>
      featureBuilder.buildPollutantInfoList(features);

  /// Statistik ringkas data historis untuk lokasi tertentu
  Future<LocationDataStats> getLocationStats(JakartaLocation location) async {
    final records = await csvService.recordsForLocation(location);
    if (records.isEmpty) {
      return LocationDataStats(
        location: location,
        totalRecords: 0,
        dateRange: null,
        categoryCounts: {},
      );
    }

    records.sort((a, b) => a.date.compareTo(b.date));
    final categoryCounts = <AirQualityCategory, int>{};
    for (final r in records) {
      categoryCounts[r.category] = (categoryCounts[r.category] ?? 0) + 1;
    }

    return LocationDataStats(
      location: location,
      totalRecords: records.length,
      dateRange: DateTimeRange(
        start: records.first.date,
        end: records.last.date,
      ),
      categoryCounts: categoryCounts,
    );
  }
}

class LocationDataStats {
  final JakartaLocation location;
  final int totalRecords;
  final DateTimeRange? dateRange;
  final Map<AirQualityCategory, int> categoryCounts;

  const LocationDataStats({
    required this.location,
    required this.totalRecords,
    required this.dateRange,
    required this.categoryCounts,
  });
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});
}
