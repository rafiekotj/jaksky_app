// Perolehan kualitas udara saat ini (data aktual atau estimasi)
enum JakartaLocation {
  jakartaPusat('Jakarta Pusat', 'pusat'),
  jakartaUtara('Jakarta Utara', 'utara'),
  jakartaTimur('Jakarta Timur', 'timur'),
  jakartaSelatan('Jakarta Selatan', 'selatan'),
  jakartaBarat('Jakarta Barat', 'barat');

  const JakartaLocation(this.displayName, this.key);
  final String displayName; // Nama untuk ditampilkan user
  final String key; // Identifier unik lokasi
}

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
  final String displayName; // Nama model untuk ditampilkan UI
  final String key; // Identifier unik model
  final String assetPath; // Path file model ONNX
}

enum AirQualityCategory {
  baik(0, 'BAIK', 'Baik'),
  sangatTidakSehat(1, 'SANGAT TIDAK SEHAT', 'Sangat Tidak Sehat'),
  sedang(2, 'SEDANG', 'Sedang'),
  tidakSehat(3, 'TIDAK SEHAT', 'Tidak Sehat');

  // Index harus sesuai urutan training model ML
  const AirQualityCategory(this.classIndex, this.rawLabel, this.displayName);
  final int classIndex; // Index prediksi model (0-3)
  final String rawLabel; // Label dari dataset training
  final String displayName; // Label untuk tampilan pengguna

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

class AirQualityFeatures {
  // Konsentrasi 6 polutan utara dalam µg/m³ atau mg/m³
  final double pm10, pm25, so2, co, o3, no2;

  const AirQualityFeatures({
    required this.pm10,
    required this.pm25,
    required this.so2,
    required this.co,
    required this.o3,
    required this.no2,
  });

  // Konversi ke array input model ONNX
  List<double> toInputList() => [pm10, pm25, so2, co, o3, no2];

  static const List<String> csvColumnNames = [
    'pm_sepuluh',
    'pm_duakomalima',
    'sulfur_dioksida',
    'karbon_monoksida',
    'ozon',
    'nitrogen_dioksida',
  ];

  static const Map<String, String> displayNames = {
    'pm10': 'PM10',
    'pm25': 'PM2.5',
    'so2': 'SO₂',
    'co': 'CO',
    'o3': 'O₃',
    'no2': 'NO₂',
  };

  static const Map<String, String> units = {
    'pm10': 'µg/m³',
    'pm25': 'µg/m³',
    'so2': 'µg/m³',
    'co': 'mg/m³',
    'o3': 'µg/m³',
    'no2': 'µg/m³',
  };

  // Konversi fitur ke map untuk iterasi dan akses mudah
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

// Hasil prediksi dari model machine learning
class AirQualityPrediction {
  final DateTime targetDate; // Tanggal target prediksi
  final JakartaLocation location; // Lokasi wilayah
  final AirQualityAlgorithm algorithm; // Model yang digunakan
  final AirQualityCategory category; // Kategori hasil prediksi
  final Map<String, double> probabilities; // Probabilitas tiap kategori
  final AirQualityFeatures features; // Nilai input 6 polutan
  final List<PollutantInfo> dominantPollutants; // Polutan paling berpengaruh
  final bool isEstimated; // Apakah hasil estimasi (bukan data historis)
  final DateTime predictedAt; // Waktu prediksi dibuat

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

  // Ambil probabilitas kategori tertentu (0.0 - 1.0)
  double probabilityOf(AirQualityCategory cat) =>
      probabilities[cat.rawLabel] ?? 0.0;
  // Tingkat kepercayaan terhadap prediksi kategori
  double get confidence => probabilityOf(category);

  // Update beberapa field sambil mempertahankan yang lain
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

// Info detail satu jenis polutan untuk ditampilkan
class PollutantInfo {
  final String key; // Identifier: pm10, pm25, so2, co, o3, no2
  final String name; // Nama display: PM10, PM2.5, SO₂ dll
  final String unit; // Satuan: µg/m³ atau mg/m³
  final double value; // Nilai terukur
  final PollutantLevel level; // Kategori level (good/moderate/unhealthy)

  const PollutantInfo({
    required this.key,
    required this.name,
    required this.unit,
    required this.value,
    required this.level,
  });
}

// Kategori level kualitas polutan individual
enum PollutantLevel {
  good('Baik'),
  moderate('Sedang'),
  unhealthy('Tidak Sehat'),
  veryUnhealthy('Sangat Tidak Sehat');

  const PollutantLevel(this.label);
  final String label;
}

// Tentukan level polutan berdasarkan standar ISPU Indonesia
PollutantLevel pollutantLevel(String key, double value) {
  switch (key) {
    case 'pm10': // Partikel berukuran <= 10 mikron
      if (value <= 50) return PollutantLevel.good;
      if (value <= 150) return PollutantLevel.moderate;
      if (value <= 350) return PollutantLevel.unhealthy;
      return PollutantLevel.veryUnhealthy;
    case 'pm25': // Partikel berukuran <= 2.5 mikron
      if (value <= 15.5) return PollutantLevel.good;
      if (value <= 55.4) return PollutantLevel.moderate;
      if (value <= 150.4) return PollutantLevel.unhealthy;
      return PollutantLevel.veryUnhealthy;
    case 'so2': // Sulfur dioksida dari kendaraan/industri
      if (value <= 52) return PollutantLevel.good;
      if (value <= 180) return PollutantLevel.moderate;
      if (value <= 800) return PollutantLevel.unhealthy;
      return PollutantLevel.veryUnhealthy;
    case 'co': // Karbon monoksida dari emisi kendaraan
      if (value <= 4.0) return PollutantLevel.good;
      if (value <= 9.0) return PollutantLevel.moderate;
      if (value <= 15.0) return PollutantLevel.unhealthy;
      return PollutantLevel.veryUnhealthy;
    case 'o3': // Ozon dari reaksi fotokimia polutan
      if (value <= 50) return PollutantLevel.good;
      if (value <= 100) return PollutantLevel.moderate;
      if (value <= 200) return PollutantLevel.unhealthy;
      return PollutantLevel.veryUnhealthy;
    case 'no2': // Nitrogen dioksida dari emisi kendaraan
      if (value <= 40) return PollutantLevel.good;
      if (value <= 100) return PollutantLevel.moderate;
      if (value <= 200) return PollutantLevel.unhealthy;
      return PollutantLevel.veryUnhealthy;
    default:
      return PollutantLevel.moderate;
  }
}

// Satu baris data historis dari file CSV
class AirQualityRecord {
  final DateTime date; // Tanggal pengukuran
  final String stasiun; // Nama stasiun pengukur
  final JakartaLocation location; // Lokasi wilayah Jakarta
  final AirQualityFeatures features; // Nilai 6 polutan
  final AirQualityCategory category; // Kategori kualitas udara

  const AirQualityRecord({
    required this.date,
    required this.stasiun,
    required this.location,
    required this.features,
    required this.category,
  });

  // Parse satu baris CSV menjadi AirQualityRecord
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
    );
  }

  static double _toDouble(dynamic v) {
    // Konversi nilai CSV ke double, default 0.0
    if (v == null) return 0.0;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static DateTime _buildDate(Map<String, dynamic> row) {
    // Gabung tahun, bulan, hari dari kolom CSV terpisah
    try {
      final year = int.parse(row['tahun'].toString());
      final month = int.parse(row['bulan'].toString());
      final day = int.parse(row['hari'].toString());
      return DateTime(year, month, day);
    } catch (_) {
      // Jika parse gagal, return hari ini
      return DateTime.now();
    }
  }

  // Ubah kode stasiun menjadi lokasi Jakarta
  static JakartaLocation _stasiunToLocation(String stasiun) {
    final upper = stasiun.toUpperCase();
    if (upper.contains('DKI1')) return JakartaLocation.jakartaPusat;
    if (upper.contains('DKI2')) return JakartaLocation.jakartaUtara;
    if (upper.contains('DKI3')) return JakartaLocation.jakartaSelatan;
    if (upper.contains('DKI4')) return JakartaLocation.jakartaTimur;
    if (upper.contains('DKI5')) return JakartaLocation.jakartaBarat;
    if (upper.contains('BUNDARAN') || upper.contains('HOTEL INDONESIA')) {
      return JakartaLocation.jakartaPusat;
    }
    if (upper.contains('KELAPA GADING')) return JakartaLocation.jakartaUtara;
    if (upper.contains('JAGAKARSA')) return JakartaLocation.jakartaSelatan;
    if (upper.contains('LUBANG BUAYA')) return JakartaLocation.jakartaTimur;
    if (upper.contains('KEBON JERUK')) return JakartaLocation.jakartaBarat;
    return JakartaLocation.jakartaPusat;
  }
}
