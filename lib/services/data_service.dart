import 'package:flutter/services.dart' show rootBundle;
import 'package:jaksky_app/models/air_quality_model.dart';

class CsvService {
  static const String _csvAssetPath = 'assets/data/CleanDatas.csv';

  List<AirQualityRecord>? _cachedRecords;

  Future<List<AirQualityRecord>> loadRecords() async {
    // Cache data agar tidak reload berkali-kali
    if (_cachedRecords != null) return _cachedRecords!;

    try {
      final raw = await rootBundle.loadString(_csvAssetPath);
      _cachedRecords = _parseCsv(raw);
      return _cachedRecords!;
    } catch (e) {
      _cachedRecords = [];
      return _cachedRecords!;
    }
  }

  Future<List<AirQualityRecord>> recordsForLocation(
    JakartaLocation location,
  ) async {
    final all = await loadRecords();
    return all.where((r) => r.location == location).toList();
  }

  Future<List<AirQualityRecord>> recordsForLocationAndMonth(
    JakartaLocation location,
    int month,
  ) async {
    final records = await recordsForLocation(location);
    return records.where((r) => r.date.month == month).toList();
  }

  // Parse CSV: ambil header lalu parse setiap baris
  List<AirQualityRecord> _parseCsv(String raw) {
    final lines = raw.split('\n');
    if (lines.isEmpty) return [];

    // Baris pertama = nama kolom CSV
    final headers = _splitCsvLine(
      lines.first,
    ).map((h) => h.trim().toLowerCase()).toList();

    final records = <AirQualityRecord>[];
    for (int i = 1; i < lines.length; i++) {
      // Lewati baris kosong atau tidak lengkap
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final values = _splitCsvLine(line);
      if (values.length < headers.length) continue;

      final row = <String, dynamic>{};
      for (int j = 0; j < headers.length; j++) {
        row[headers[j]] = values[j].trim();
      }

      try {
        // Konversi baris ke object AirQualityRecord
        records.add(AirQualityRecord.fromCsvRow(row));
      } catch (e) {}
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

class FeatureBuilder {
  final CsvService _csvService;

  FeatureBuilder({CsvService? csvService})
    : _csvService = csvService ?? CsvService();

  Future<FeatureBuildResult> buildFeatures(
    DateTime targetDate,
    JakartaLocation location,
  ) async {
    // Ambil semua data lokasi dari CSV
    final allRecords = await _csvService.recordsForLocation(location);

    // Tier 1: Cari tanggal EXACT sama (bulan & hari)
    final exactDateRecords = allRecords.where((r) {
      return r.date.month == targetDate.month && r.date.day == targetDate.day;
    }).toList();

    if (exactDateRecords.isNotEmpty) {
      final features = _averageFeatures(exactDateRecords);
      return FeatureBuildResult(
        features: features,
        isEstimated: false, // Data riil dari CSV!
        sourceRecordCount: exactDateRecords.length,
        sourceDescription:
            '${exactDateRecords.length} data historis tanggal sama (tahun lain)',
      );
    }

    // Tier 2: Cari ±7 hari di bulan yang sama
    final nearbyRecords = allRecords.where((r) {
      return r.date.month == targetDate.month &&
          (r.date.day - targetDate.day).abs() <= 7;
    }).toList();

    if (nearbyRecords.isNotEmpty) {
      final features = _averageFeatures(nearbyRecords);
      return FeatureBuildResult(
        features: features,
        isEstimated: true, // Tidak exact, tapi dari data historis
        sourceRecordCount: nearbyRecords.length,
        sourceDescription:
            '${nearbyRecords.length} data historis (±7 hari, bulan ${targetDate.month})',
      );
    }

    // Tier 3: Cari rata-rata seluruh bulan yang sama
    final monthRecords = allRecords.where((r) {
      return r.date.month == targetDate.month;
    }).toList();

    if (monthRecords.isNotEmpty) {
      final features = _averageFeatures(monthRecords);
      return FeatureBuildResult(
        features: features,
        isEstimated: true,
        sourceRecordCount: monthRecords.length,
        sourceDescription:
            'Rata-rata ${monthRecords.length} data historis bulan ${targetDate.month}',
      );
    }

    // Tier 4: Fallback - nilai standard tetap, jujur & transparan
    return FeatureBuildResult(
      features: const AirQualityFeatures(
        pm10: 65,
        pm25: 35,
        so2: 11,
        co: 1.5,
        o3: 60,
        no2: 25,
      ),
      isEstimated: true,
      sourceRecordCount: 0,
      sourceDescription: 'Data estimasi standar (data historis tidak tersedia)',
    );
  }

  // Hitung rata-rata 6 polutan dari beberapa record
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

    // Jumlahkan semua nilai polutan dari setiap record
    for (final r in records) {
      sumPm10 += r.features.pm10;
      sumPm25 += r.features.pm25;
      sumSo2 += r.features.so2;
      sumCo += r.features.co;
      sumO3 += r.features.o3;
      sumNo2 += r.features.no2;
    }

    return AirQualityFeatures(
      // Rata-rata lalu pastikan dalam range valid (clamp)
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

  // Buat info polutan & urutkan dari level tertinggi
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

class DataService {
  final CsvService csvService;
  final FeatureBuilder featureBuilder;

  DataService() : csvService = CsvService(), featureBuilder = FeatureBuilder();

  DataService.withDeps({
    required this.csvService,
    required this.featureBuilder,
  });

  /// Muat semua data historis
  Future<void> init() async {
    // Siapkan CSV data saat app startup
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
    // Hitung jumlah & range tanggal data
    if (records.isEmpty) {
      return LocationDataStats(
        location: location,
        totalRecords: 0,
        dateRange: null,
        categoryCounts: {},
      );
    }

    records.sort((a, b) => a.date.compareTo(b.date));
    // Hitung berapa banyak tiap kategori
    final categoryCounts = <AirQualityCategory, int>{};
    for (final r in records) {
      // Terhitung: berapa Baik, Sedang, Tidak Sehat, etc
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
