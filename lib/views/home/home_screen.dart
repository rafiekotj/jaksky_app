import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jaksky_app/core/constants/app_color.dart';
import 'package:jaksky_app/models/air_quality_model.dart';
import 'package:jaksky_app/providers/prediction_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _selectedDate;
  JakartaLocation? _selectedLokasi;
  AirQualityAlgorithm? _selectedAlgoritma;
  bool _isLoading = false;
  AirQualityPrediction? _currentPrediction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColor.surface,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'JakSky',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColor.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Tanggal (DatePicker) ──────────────────────────────────
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      _selectedDate ??
                      DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now().add(const Duration(days: 1)),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1D1D6)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDate == null
                          ? 'Pilih Tanggal'
                          : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                                '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                                '${_selectedDate!.year}',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDate == null
                            ? const Color(0xFF8E8E93)
                            : Colors.black,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF8E8E93),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Lokasi (Dropdown) ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1D1D6)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<JakartaLocation>(
                  value: _selectedLokasi,
                  hint: const Text(
                    'Pilih Lokasi',
                    style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93)),
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF8E8E93),
                  ),
                  isExpanded: true,
                  items: JakartaLocation.values
                      .map(
                        (location) => DropdownMenuItem(
                          value: location,
                          child: Text(location.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedLokasi = value);
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Algoritma (Dropdown) ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1D1D6)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AirQualityAlgorithm>(
                  value: _selectedAlgoritma,
                  hint: const Text(
                    'Pilih Algoritma',
                    style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93)),
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF8E8E93),
                  ),
                  isExpanded: true,
                  items: AirQualityAlgorithm.values
                      .map(
                        (algo) => DropdownMenuItem(
                          value: algo,
                          child: Text(algo.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedAlgoritma = value);
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Tombol Terapkan ───────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 160,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      _selectedDate != null &&
                          _selectedLokasi != null &&
                          _selectedAlgoritma != null &&
                          !_isLoading
                      ? () => _handlePredict()
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6AABDF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Terapkan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Hasil Prediksi ────────────────────────────────────────
            if (_currentPrediction != null) ...[
              _buildResultCard(_currentPrediction!),
              const SizedBox(height: 16),
              _buildPollutantGrid(_currentPrediction!),
              const SizedBox(height: 16),
              _buildRecommendationCards(_currentPrediction!),
            ] else
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Text(
                  'Pilih tanggal, lokasi, dan algoritma\nkemudian klik "Terapkan" untuk melihat prediksi',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePredict() async {
    if (_selectedDate == null ||
        _selectedLokasi == null ||
        _selectedAlgoritma == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<PredictionProvider>();
      final prediction = await provider.predict(
        targetDate: _selectedDate!,
        location: _selectedLokasi!,
        algorithm: _selectedAlgoritma!,
      );

      setState(() {
        _currentPrediction = prediction;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Color _getCategoryColor(AirQualityCategory category) {
    switch (category) {
      case AirQualityCategory.baik:
        return const Color(0xFF7CBF4A);
      case AirQualityCategory.sedang:
        return const Color(0xFFFFA500);
      case AirQualityCategory.tidakSehat:
        return const Color(0xFFFF6B6B);
      case AirQualityCategory.sangatTidakSehat:
        return const Color(0xFF8B0000);
    }
  }

  Color _getCategoryBackgroundColor(AirQualityCategory category) {
    switch (category) {
      case AirQualityCategory.baik:
        return const Color(0xFFB5D96A);
      case AirQualityCategory.sedang:
        return const Color(0xFFFFD699);
      case AirQualityCategory.tidakSehat:
        return const Color(0xFFFFB3B3);
      case AirQualityCategory.sangatTidakSehat:
        return const Color(0xFFCC6666);
    }
  }

  Widget _buildResultCard(AirQualityPrediction prediction) {
    return Container(
      decoration: BoxDecoration(
        color: _getCategoryBackgroundColor(prediction.category),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Status kategori
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: _getCategoryColor(prediction.category),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Center(
              child: Text(
                prediction.category.displayName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          // Deskripsi
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              prediction.category.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Lokasi & tanggal
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFFE53935),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.location.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${prediction.targetDate.day} ${_getMonthName(prediction.targetDate.month)} ${prediction.targetDate.year}',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Algoritma',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                    ),
                    Text(
                      prediction.algorithm.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Confidence
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kepercayaan Prediksi',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  '${(prediction.confidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollutantGrid(AirQualityPrediction prediction) {
    final pollutants = [
      prediction.features.pm10,
      prediction.features.pm25,
      prediction.features.so2,
      prediction.features.co,
      prediction.features.o3,
      prediction.features.no2,
    ];
    final keys = ['pm10', 'pm25', 'so2', 'co', 'o3', 'no2'];
    final names = [
      AirQualityFeatures.displayNames['pm10']!,
      AirQualityFeatures.displayNames['pm25']!,
      AirQualityFeatures.displayNames['so2']!,
      AirQualityFeatures.displayNames['co']!,
      AirQualityFeatures.displayNames['o3']!,
      AirQualityFeatures.displayNames['no2']!,
    ];
    final units = [
      AirQualityFeatures.units['pm10']!,
      AirQualityFeatures.units['pm25']!,
      AirQualityFeatures.units['so2']!,
      AirQualityFeatures.units['co']!,
      AirQualityFeatures.units['o3']!,
      AirQualityFeatures.units['no2']!,
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        final level = pollutantLevel(keys[index], pollutants[index]);
        final levelColor = _getPollutantLevelColor(level);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: levelColor, width: 2),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                names[index],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pollutants[index].toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: levelColor,
                    ),
                  ),
                  Text(
                    units[index],
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  level.label,
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getPollutantLevelColor(PollutantLevel level) {
    switch (level) {
      case PollutantLevel.good:
        return const Color(0xFF7CBF4A);
      case PollutantLevel.moderate:
        return const Color(0xFFFFA500);
      case PollutantLevel.unhealthy:
        return const Color(0xFFFF6B6B);
      case PollutantLevel.veryUnhealthy:
        return const Color(0xFF8B0000);
    }
  }

  Widget _buildRecommendationCards(AirQualityPrediction prediction) {
    final recommendations = _getRecommendations(prediction.category);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: recommendations
          .map(
            (rec) => Container(
              decoration: BoxDecoration(
                color: _getCategoryBackgroundColor(prediction.category),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(rec['icon'] as IconData, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    rec['text'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  List<Map<String, dynamic>> _getRecommendations(AirQualityCategory category) {
    switch (category) {
      case AirQualityCategory.baik:
        return [
          {
            'icon': Icons.wb_sunny_outlined,
            'text': 'Udara bersih, aman untuk\naktivitas luar',
          },
          {
            'icon': Icons.eco_outlined,
            'text': 'Risiko kesehatan\nsangat rendah',
          },
          {
            'icon': Icons.grid_view_outlined,
            'text': 'Ventilasi alami\ndianjurkan',
          },
          {
            'icon': Icons.directions_run,
            'text': 'Cocok untuk olahraga\ndi luar ruangan',
          },
        ];
      case AirQualityCategory.sedang:
        return [
          {
            'icon': Icons.cloud_outlined,
            'text': 'Udara cukup baik\nuntuk aktivitas normal',
          },
          {
            'icon': Icons.favorite_border,
            'text': 'Kelompok sensitif\nmungkin terganggu',
          },
          {'icon': Icons.air, 'text': 'Ventilasi alami\nmasih boleh'},
          {
            'icon': Icons.directions_walk,
            'text': 'Aktivitas ringan\ndi luar ruangan',
          },
        ];
      case AirQualityCategory.tidakSehat:
        return [
          {
            'icon': Icons.warning_outlined,
            'text': 'Batasi aktivitas\nluar ruangan',
          },
          {
            'icon': Icons.health_and_safety,
            'text': 'Kelompok sensitif\ngunakan masker',
          },
          {
            'icon': Icons.home,
            'text': 'Tutup jendela dan pintu\nuntuk ventilasi',
          },
          {
            'icon': Icons.do_not_disturb,
            'text': 'Hindari olahraga\ndi luar ruangan',
          },
        ];
      case AirQualityCategory.sangatTidakSehat:
        return [
          {
            'icon': Icons.not_interested,
            'text': 'Hindari aktivitas\nluar ruangan',
          },
          {'icon': Icons.masks, 'text': 'Semua orang gunakan\nmasker N95'},
          {'icon': Icons.home, 'text': 'Tutup semua ventilasi\nalami'},
          {
            'icon': Icons.medical_services,
            'text': 'Konsultasi dokter jika\nmerasa tidak sehat',
          },
        ];
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }
}
