import 'package:flutter/material.dart';
import 'package:jaksky_app/core/constants/app_color.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _selectedDate;
  String? _selectedLokasi;
  String? _selectedAlgoritma;

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
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
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
                          ? 'Tanggal'
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
                child: DropdownButton<String>(
                  value: _selectedLokasi,
                  hint: const Text(
                    'Lokasi',
                    style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93)),
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF8E8E93),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'jakarta_barat',
                      child: Text('Jakarta Barat'),
                    ),
                    DropdownMenuItem(
                      value: 'jakarta_pusat',
                      child: Text('Jakarta Pusat'),
                    ),
                    DropdownMenuItem(
                      value: 'jakarta_selatan',
                      child: Text('Jakarta Selatan'),
                    ),
                    DropdownMenuItem(
                      value: 'jakarta_timur',
                      child: Text('Jakarta Timur'),
                    ),
                    DropdownMenuItem(
                      value: 'jakarta_utara',
                      child: Text('Jakarta Utara'),
                    ),
                  ],
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
                child: DropdownButton<String>(
                  value: _selectedAlgoritma,
                  hint: const Text(
                    'Algoritma',
                    style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93)),
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF8E8E93),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'random_forest',
                      child: Text('Random Forest'),
                    ),
                    DropdownMenuItem(
                      value: 'linear_regression',
                      child: Text('Linear Regression'),
                    ),
                    DropdownMenuItem(value: 'lstm', child: Text('LSTM')),
                    DropdownMenuItem(value: 'arima', child: Text('ARIMA')),
                  ],
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
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6AABDF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Terapkan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Card Hasil Kualitas Udara ─────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFB5D96A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Status "BAIK"
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7CBF4A),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'BAIK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),

                  // Label polutan
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Perkiraan Polutan',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'PM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: '2.5',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lokasi & tanggal
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                          children: const [
                            Text(
                              'Jakarta Barat, DKI Jakarta',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '10 Mei 2026',
                              style: TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Grid 4 Info Card ──────────────────────────────────────
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                // Card 1 – Udara bersih
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFB5D96A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Udara bersih, aman untuk\naktivitas luar',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // Card 2 – Risiko kesehatan
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFB5D96A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.eco_outlined, color: Colors.white, size: 40),
                      SizedBox(height: 12),
                      Text(
                        'Risiko kesehatan\nsangat rendah',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // Card 3 – Ventilasi
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFB5D96A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.grid_view_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Ventilasi alami\ndianjurkan',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // Card 4 – Olahraga
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFB5D96A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_run, color: Colors.white, size: 40),
                      SizedBox(height: 12),
                      Text(
                        'Cocok untuk olahraga\ndi luar ruangan',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
