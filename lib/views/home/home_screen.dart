import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
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
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'JakSky',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColor.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Form Input Container ──────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColor.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                        lastDate: DateTime(2050, 12, 31),
                        initialEntryMode: DatePickerEntryMode.calendarOnly,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              // Warna utama global
                              colorScheme: ColorScheme.light(
                                primary: AppColor.primary,
                                onPrimary: AppColor.textOnPrimary,
                              ),
                              // Warna divider global (termasuk di year picker)
                              dividerColor: AppColor.border,
                              dividerTheme: DividerThemeData(
                                color: AppColor.border,
                                thickness: 1,
                              ),
                              datePickerTheme: DatePickerThemeData(
                                // Background & header
                                backgroundColor: Colors.white,
                                headerBackgroundColor: AppColor.surface,
                                headerForegroundColor: Colors.black,
                                dividerColor: AppColor.border,

                                // Style teks
                                weekdayStyle: const TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 12,
                                ),
                                dayStyle: const TextStyle(color: Colors.black),
                                yearStyle: const TextStyle(color: Colors.black),

                                // Warna hari
                                dayForegroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(
                                        WidgetState.selected,
                                      )) {
                                        return Colors.white;
                                      }
                                      if (states.contains(
                                        WidgetState.disabled,
                                      )) {
                                        return const Color(0xFFD1D1D6);
                                      }
                                      return Colors.black;
                                    }),
                                dayBackgroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(
                                        WidgetState.selected,
                                      )) {
                                        return AppColor.primary;
                                      }
                                      return Colors.transparent;
                                    }),

                                // Hari ini
                                todayForegroundColor: WidgetStateProperty.all(
                                  AppColor.primary,
                                ),
                                todayBackgroundColor: WidgetStateProperty.all(
                                  Colors.transparent,
                                ),
                                todayBorder: BorderSide(
                                  color: AppColor.primary,
                                ),

                                // Warna tahun
                                yearForegroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(
                                        WidgetState.selected,
                                      )) {
                                        return AppColor.textOnPrimary;
                                      }
                                      return Colors.black;
                                    }),
                                yearBackgroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(
                                        WidgetState.selected,
                                      )) {
                                        return AppColor.primary;
                                      }
                                      return Colors.transparent;
                                    }),
                                yearOverlayColor: WidgetStateProperty.all(
                                  Colors.transparent,
                                ),
                              ),

                              // Warna tombol Cancel & OK
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColor.primary,
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColor.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColor.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDate == null
                                ? 'Pilih Tanggal'
                                : '${_selectedDate!.day} ${_getMonthName(_selectedDate!.month)} ${_selectedDate!.year}',
                            style: TextStyle(
                              fontSize: 14,
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

                  // ── Lokasi (PopupMenu Button) ─────────────────────────────
                  PopupMenuButton<JakartaLocation>(
                    color: AppColor.surface,
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 64,
                    ),
                    onSelected: (value) {
                      setState(() => _selectedLokasi = value);
                    },
                    position: PopupMenuPosition.under,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColor.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColor.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedLokasi == null
                                ? 'Pilih Lokasi'
                                : _selectedLokasi!.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedLokasi == null
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
                    itemBuilder: (context) => JakartaLocation.values
                        .map(
                          (location) => PopupMenuItem(
                            value: location,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Text(location.displayName),
                            ),
                          ),
                        )
                        .toList(),
                  ),

                  const SizedBox(height: 12),

                  // ── Algoritma (PopupMenu Button) ──────────────────────────
                  PopupMenuButton<AirQualityAlgorithm>(
                    color: AppColor.surface,
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 64,
                    ),
                    onSelected: (value) {
                      setState(() => _selectedAlgoritma = value);
                    },
                    position: PopupMenuPosition.under,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColor.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColor.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedAlgoritma == null
                                ? 'Pilih Algoritma'
                                : _selectedAlgoritma!.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedAlgoritma == null
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
                    itemBuilder: (context) => AirQualityAlgorithm.values
                        .map(
                          (algo) => PopupMenuItem(
                            value: algo,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Text(algo.displayName),
                            ),
                          ),
                        )
                        .toList(),
                  ),

                  const SizedBox(height: 16),

                  // ── Tombol Terapkan ───────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 112,
                      height: 44,
                      child: ElevatedButton(
                        onPressed:
                            _selectedDate != null &&
                                _selectedLokasi != null &&
                                _selectedAlgoritma != null &&
                                !_isLoading
                            ? () => _handlePredict()
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.primary,
                          foregroundColor: AppColor.surface,
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                                    AppColor.surface,
                                  ),
                                ),
                              )
                            : const Text(
                                'Terapkan',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Hasil Prediksi ────────────────────────────────────────
            if (_currentPrediction != null) ...[
              _buildResultCard(_currentPrediction!),
              const SizedBox(height: 16),
              const Text(
                "Prediksi Polutan",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildPollutantGrid(_currentPrediction!),
              const SizedBox(height: 16),
              const Text(
                "Indeks",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildRecommendationCards(_currentPrediction!),
            ] else
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Lottie.asset(
                      'assets/animations/Weather-mist.json',
                      width: 180,
                    ),
                    Text(
                      'Pilih tanggal, lokasi, dan algoritma\nkemudian klik "Terapkan" untuk melihat prediksi',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
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

    // Debug print untuk melihat nilai yang dipilih
    debugPrint('[HomeScreen] === Prediksi Dimulai ===');
    debugPrint('[HomeScreen] Tanggal: ${_selectedDate!.toString()}');
    debugPrint('[HomeScreen] Lokasi: ${_selectedLokasi!.displayName}');
    debugPrint('[HomeScreen] Algoritma: ${_selectedAlgoritma!.displayName}');
    debugPrint('[HomeScreen] Asset Model: ${_selectedAlgoritma!.assetPath}');
    debugPrint('[HomeScreen] ========================');

    try {
      final provider = context.read<PredictionProvider>();
      final prediction = await provider.predict(
        targetDate: _selectedDate!,
        location: _selectedLokasi!,
        algorithm: _selectedAlgoritma!,
      );

      // Debug print fitur yang digunakan
      debugPrint('[HomeScreen] === Feature Values ===');
      debugPrint(
        '[HomeScreen] PM10: ${prediction.features.pm10.toStringAsFixed(2)}',
      );
      debugPrint(
        '[HomeScreen] PM2.5: ${prediction.features.pm25.toStringAsFixed(2)}',
      );
      debugPrint(
        '[HomeScreen] SO2: ${prediction.features.so2.toStringAsFixed(2)}',
      );
      debugPrint(
        '[HomeScreen] CO: ${prediction.features.co.toStringAsFixed(2)}',
      );
      debugPrint(
        '[HomeScreen] O3: ${prediction.features.o3.toStringAsFixed(2)}',
      );
      debugPrint(
        '[HomeScreen] NO2: ${prediction.features.no2.toStringAsFixed(2)}',
      );
      debugPrint('[HomeScreen] isEstimated: ${prediction.isEstimated}');
      debugPrint('[HomeScreen] ========================');

      // Debug print probabilitas
      debugPrint('[HomeScreen] === Probabilities ===');
      prediction.probabilities.forEach((key, value) {
        debugPrint('[HomeScreen] $key: ${(value * 100).toStringAsFixed(2)}%');
      });
      debugPrint('[HomeScreen] ========================');
      debugPrint(
        '[HomeScreen] Hasil: ${prediction.category.displayName} (Confidence: ${(prediction.confidence * 100).toStringAsFixed(2)}%)',
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
        return AppColor.baik;
      case AirQualityCategory.sedang:
        return AppColor.sedang;
      case AirQualityCategory.tidakSehat:
        return AppColor.tsehat;
      case AirQualityCategory.sangatTidakSehat:
        return AppColor.stsehat;
    }
  }

  Color _getCategoryBackgroundColor(AirQualityCategory category) {
    switch (category) {
      case AirQualityCategory.baik:
        return AppColor.baikSoft;
      case AirQualityCategory.sedang:
        return AppColor.sedangSoft;
      case AirQualityCategory.tidakSehat:
        return AppColor.tsehatSoft;
      case AirQualityCategory.sangatTidakSehat:
        return AppColor.stsehatSoft;
    }
  }

  Widget _buildResultCard(AirQualityPrediction prediction) {
    return Container(
      decoration: BoxDecoration(
        color: _getCategoryBackgroundColor(prediction.category),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _getCategoryColor(prediction.category).withAlpha(126),
            blurRadius: 4,
            spreadRadius: 2,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status kategori
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: _getCategoryColor(prediction.category),
              borderRadius: BorderRadius.circular(8),
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

          // Confidence
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tingkat Keyakinan Prediksi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
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

          // Lokasi & tanggal
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
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
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${prediction.targetDate.day} ${_getMonthName(prediction.targetDate.month)} ${prediction.targetDate.year}',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 12,
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
                        fontSize: 14,
                      ),
                    ),
                  ],
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
        childAspectRatio: 1.3,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        final level = pollutantLevel(keys[index], pollutants[index]);
        final levelColor = _getPollutantLevelColor(level);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: levelColor, width: 1.5),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  names[index],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          pollutants[index].toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: levelColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          units[index],
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: levelColor.withAlpha(45),
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
        return AppColor.baik;
      case PollutantLevel.moderate:
        return AppColor.sedang;
      case PollutantLevel.unhealthy:
        return AppColor.tsehat;
      case PollutantLevel.veryUnhealthy:
        return AppColor.stsehat;
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    rec['icon'] as IconData,
                    color: Colors.white,
                    size: 32,
                    weight: 700,
                  ),
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
            'icon': Symbols.clear_day,
            'text': 'Udara bersih,\naman untuk aktivitas',
          },
          {'icon': Symbols.eco, 'text': 'Risiko kesehatan\nsangat rendah'},
          {'icon': Symbols.window, 'text': 'Ventilasi alami\ndianjurkan'},
          {
            'icon': Symbols.directions_run,
            'text': 'Cocok untuk olahraga\ndi luar ruangan',
          },
        ];
      case AirQualityCategory.sedang:
        return [
          {'icon': Symbols.foggy, 'text': 'Kualitas udara\ncukup baik'},
          {'icon': Symbols.medical_mask, 'text': 'Perlindungan\nopsional'},
          {'icon': Symbols.warning, 'text': 'Waspada\nringan'},
          {'icon': Symbols.directions_walk, 'text': 'Kurangi\naktivitas berat'},
        ];
      case AirQualityCategory.tidakSehat:
        return [
          {'icon': Symbols.air, 'text': 'Kualitas udara buruk,\nberisiko'},
          {'icon': Symbols.masks, 'text': 'Gunakan masker\npelindung'},
          {
            'icon': Symbols.do_not_disturb_on,
            'text': 'Kurangi aktivitas\ndi luar ruangan',
          },
          {
            'icon': Symbols.airline_seat_recline_extra,
            'text': 'Kelompok sensitif\nsebaiknya tetap di dalam',
          },
        ];
      case AirQualityCategory.sangatTidakSehat:
        return [
          {'icon': Symbols.dangerous, 'text': 'Udara\nsangat berbahaya'},
          {
            'icon': Symbols.air_purifier_gen,
            'text': 'Gunakan masker\ndan air purifier',
          },
          {
            'icon': Symbols.window_closed,
            'text': 'Tutup Jendela,\ntetap di dalam ruangan',
          },
          {
            'icon': Symbols.in_home_mode,
            'text': 'Hindari aktivitas\ndi luar ruangan',
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
