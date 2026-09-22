import 'package:flutter/material.dart';
import 'package:jaksky_app/core/constants/app_color.dart';
import 'package:jaksky_app/models/air_quality_model.dart';

class DetailPredictionScreen extends StatelessWidget {
  final AirQualityPrediction prediction;

  const DetailPredictionScreen({super.key, required this.prediction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColor.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColor.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Kategori',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColor.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status Kategori ───────────────────────────────────────
            _buildCategoryCard(context),

            const SizedBox(height: 24),

            // ── Kategori Guide Infografis ───────────────────────────────────────
            _buildCategoryGuideCard(),

            const SizedBox(height: 20),

            // ── Standar Parameter ISPU (Normal) ─────────────────────────────
            _buildStandardISPUCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _getCategoryBackgroundColor(prediction.category),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _getCategoryColor(prediction.category).withAlpha(126),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: _getCategoryColor(prediction.category),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              prediction.category.displayName.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGuideCard() {
    final categoryInfo = _getCategoryInfo(prediction.category);
    final color = categoryInfo['color'] as Color;
    final descText = categoryInfo['description'] as String;
    final categoryName = categoryInfo['name'] as String;

    return Container(
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengertian Kategori',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColor.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 5)),
              color: color.withAlpha(12),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  descText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColor.textPrimary,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getCategoryInfo(AirQualityCategory category) {
    switch (category) {
      case AirQualityCategory.baik:
        return {
          'name': 'BAIK',
          'shortDescription': 'Kualitas udara baik, aman untuk semua aktivitas',
          'description':
              'Kategori BAIK menunjukkan kualitas udara yang sangat baik dan sehat untuk semua orang. Pada kondisi ini, semua lapisan masyarakat dapat melakukan aktivitas outdoor maupun indoor tanpa perlu khawatir terhadap dampak negatif kualitas udara. Anda dapat menikmati aktivitas Anda dengan nyaman dan aman.',
          'color': AppColor.baik,
        };
      case AirQualityCategory.sedang:
        return {
          'name': 'SEDANG',
          'shortDescription':
              'Kualitas udara sedang, kelompok sensitif perlu perhatian',
          'description':
              'Kategori SEDANG menunjukkan kualitas udara yang sedang atau cukup. Pada kondisi ini, kelompok sensitif seperti anak-anak, lansia, ibu hamil, dan penderita penyakit pernafasan atau jantung perlu membatasi aktivitas outdoor yang berat. Masyarakat umum dapat melakukan aktivitas normal, namun disarankan untuk tetap waspada terhadap kualitas udara.',
          'color': AppColor.sedang,
        };
      case AirQualityCategory.tidakSehat:
        return {
          'name': 'TIDAK SEHAT',
          'shortDescription':
              'Kualitas udara tidak sehat, hindari aktivitas outdoor',
          'description':
              'Kategori TIDAK SEHAT menunjukkan kualitas udara yang telah melampaui standar kesehatan. Pada kondisi ini, semua kelompok masyarakat mulai dapat merasakan dampak kesehatan dari polusi udara. Aktivitas outdoor yang berat harus dihindari, terutama untuk kelompok sensitif. Gunakan masker perlindungan jika terpaksa harus berada di luar ruangan.',
          'color': AppColor.tsehat,
        };
      case AirQualityCategory.sangatTidakSehat:
        return {
          'name': 'SANGAT TIDAK SEHAT',
          'shortDescription':
              'Kualitas udara sangat tidak sehat, tetap di dalam ruangan',
          'description':
              'Kategori SANGAT TIDAK SEHAT menunjukkan kualitas udara yang sangat buruk dan berbahaya bagi kesehatan. Pada kondisi ini, semua kelompok masyarakat mengalami risiko kesehatan yang serius. Sangat disarankan untuk menghindari aktivitas outdoor dan tetap berada di dalam ruangan. Gunakan AC dengan filter atau purifier udara jika memungkinkan. Jika harus keluar, gunakan masker yang sesuai dan batasi waktu di luar ruangan.',
          'color': AppColor.stsehat,
        };
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

  Widget _buildStandardISPUCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Batas Normal Kualitas Udara (Kategori BAIK)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColor.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildStandardRow('PM10', 'Partikel debu', '≤ 50', 'µg/m³'),
          _buildStandardRow('PM2.5', 'Partikel halus', '≤ 15.5', 'µg/m³'),
          _buildStandardRow('SO₂', 'Sulfur dioksida', '≤ 52', 'µg/m³'),
          _buildStandardRow('CO', 'Karbon monoksida', '≤ 4.0', 'mg/m³'),
          _buildStandardRow('O₃', 'Ozon', '≤ 50', 'µg/m³'),
          _buildStandardRow('NO₂', 'Nitrogen dioksida', '≤ 40', 'µg/m³'),
        ],
      ),
    );
  }

  Widget _buildStandardRow(
    String name,
    String desc,
    String limit,
    String unit,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                limit,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColor.baik,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
