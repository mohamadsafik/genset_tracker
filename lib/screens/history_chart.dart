import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GensetHistoryChart extends StatelessWidget {
  const GensetHistoryChart({super.key});

  @override
  Widget build(BuildContext context) {
    // Ambil waktu saat ini dan 10 menit yang lalu.
    // Ini sudah benar untuk mengambil 10 data terbaru dalam 10 menit.
    final today = DateTime.now();
    final tenMinutesAgo = today.subtract(const Duration(minutes: 10));

    // ⭐️ Stream data dari Firestore:
    // Query ini sudah efisien: terbaru (descending), dibatasi 10, dalam 10 menit terakhir.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('genset_history')
          .where(
            'CreatedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(tenMinutesAgo),
          )
          .where('CreatedAt', isLessThanOrEqualTo: Timestamp.fromDate(today))
          .orderBy('CreatedAt', descending: true)
          .limit(5) // 🔹 batasi hanya 10 data terbaru
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!;

        if (data.docs.isEmpty) {
          return const Column(
            children: [
              SizedBox(height: 16),
              Center(
                child: Text(
                  'Belum ada data history yang tersedia.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          );
        }

        // Balik list agar data diurutkan dari lama (kiri) ke baru (kanan)
        final docs = data.docs.reversed.toList();

        final voltageSpots = <FlSpot>[];
        final freqSpots = <FlSpot>[];
        final currentSpots = <FlSpot>[];
        final timeLabels = <String>[];

        double minTimestamp = -1;

        // ⭐️ Memproses data untuk FlSpot
        for (int i = 0; i < docs.length; i++) {
          final dataMap = docs[i].data() as Map<String, dynamic>;

          // Konversi nilai ke double dengan aman
          final voltage = (dataMap['Voltage'] as num? ?? 0).toDouble();
          final freq = (dataMap['Frequency'] as num? ?? 0).toDouble();
          final current = (dataMap['Current'] as num? ?? 0).toDouble();

          final timestampValue = dataMap['CreatedAt'] as Timestamp?;
          if (timestampValue == null) continue; // Skip jika CreatedAt null

          final DateTime date = timestampValue.toDate();

          final double timestamp = date.millisecondsSinceEpoch.toDouble();

          if (minTimestamp == -1 || timestamp < minTimestamp) {
            minTimestamp = timestamp;
          }

          // Normalisasi X axis: waktu relatif terhadap waktu data pertama
          final double normalizedX = timestamp - minTimestamp;

          voltageSpots.add(FlSpot(normalizedX, voltage));
          freqSpots.add(FlSpot(normalizedX, freq));
          currentSpots.add(FlSpot(normalizedX, current));
          timeLabels.add(DateFormat.Hm().format(date));
        }

        final double minX = voltageSpots.isNotEmpty ? voltageSpots.first.x : 0;
        final double maxX = voltageSpots.isNotEmpty ? voltageSpots.last.x : 1;

        // Ambil nilai real-time dari dokumen TERAKHIR (sudah dibalik, jadi ini index terakhir)
        final lastDocData = docs.last.data() as Map<String, dynamic>;

        final lastVoltage = (lastDocData['Voltage'] as num? ?? 0)
            .toDouble()
            .toStringAsFixed(1);
        final lastFrequency = (lastDocData['Frequency'] as num? ?? 0)
            .toDouble()
            .toStringAsFixed(1);
        final lastCurrent = (lastDocData['Current'] as num? ?? 0)
            .toDouble()
            .toStringAsFixed(2);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Grafik Parameter Real-time",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // 🔵 Tegangan
            _buildChartCard(
              key: const ValueKey('VoltageChart'),
              title: 'Tegangan',
              value: '$lastVoltage V',
              color: Colors.blueAccent,
              spots: voltageSpots,
              labels: timeLabels,
              minX: minX,
              maxX: maxX,
            ),

            // 🟡 Frekuensi
            _buildChartCard(
              key: const ValueKey('FrequencyChart'),
              title: 'Frekuensi',
              value: '$lastFrequency Hz',
              color: Colors.orangeAccent,
              spots: freqSpots,
              labels: timeLabels,
              minX: minX,
              maxX: maxX,
            ),

            // 🔴 Arus
            _buildChartCard(
              key: const ValueKey('CurrentChart'),
              title: 'Arus',
              value: '$lastCurrent A',
              color: Colors.redAccent,
              spots: currentSpots,
              labels: timeLabels,
              minX: minX,
              maxX: maxX,
            ),
          ],
        );
      },
    );
  }

  // --- Fungsi _buildChartCard (dengan PERBAIKAN Y-AXIS) ---

  Widget _buildChartCard({
    Key? key,
    required String title,
    required String value,
    required Color color,
    required List<FlSpot> spots,
    required List<String> labels,
    required double minX,
    required double maxX,
  }) {
    if (spots.isEmpty) {
      return Container(key: key);
    }

    // Logika Skala Y
    final double maxY = spots
        .map((spot) => spot.y)
        .reduce((a, b) => a > b ? a : b);
    final double minY = spots
        .map((spot) => spot.y)
        .reduce((a, b) => a < b ? a : b);

    double yInterval;
    double chartMaxY;
    double chartMinY;

    // ⭐ LOGIKA PERBAIKAN UTAMA Y-AXIS
    // Menghitung rentang data
    final double dataRange = maxY - minY;

    if (dataRange < 0.1) {
      // Menangani kasus data rata (Flatline) atau range sangat kecil
      // Jika data rata, kita buat rentang 2.0 atau 0.2
      double padding = (maxY < 1.0) ? 0.1 : 1.0;

      chartMaxY = maxY + padding;
      chartMinY = minY >= padding ? minY - padding : 0.0;

      // Menentukan interval yang lebih baik
      if (maxY >= 50) {
        yInterval = 5.0;
      } else if (maxY >= 5) {
        yInterval = 1.0;
      } else {
        yInterval = 0.5;
      }

      // Membulatkan batas chart agar menjadi kelipatan yInterval
      chartMaxY = (chartMaxY / yInterval).ceil() * yInterval;
      chartMinY = (chartMinY / yInterval).floor() * yInterval;
      if (chartMinY < 0) chartMinY = 0; // Pastikan tidak negatif
    } else {
      // Logika untuk data yang bervariasi
      // Menjaga rentang sekitar 10% dari rentang data
      double buffer = dataRange * 0.10;
      yInterval = (dataRange + 2 * buffer) / 4; // Target 5 garis interval

      chartMaxY = maxY + buffer;
      chartMinY = minY - buffer;
      if (chartMinY < 0) chartMinY = 0;

      // Pembulatan interval untuk tampilan yang lebih rapi
      if (yInterval >= 10) {
        yInterval = (yInterval / 5).ceil() * 5.0; // Kelipatan 5
      } else if (yInterval >= 1) {
        yInterval = yInterval.ceilToDouble(); // Kelipatan 1
      } else if (yInterval > 0.1) {
        yInterval = (yInterval * 10).ceilToDouble() / 10.0; // Kelipatan 0.1
      } else {
        yInterval = 0.1;
      }

      // Memastikan chartMaxY dan chartMinY disesuaikan ke kelipatan yInterval
      chartMaxY = (chartMaxY / yInterval).ceil() * yInterval;
      chartMinY = (chartMinY / yInterval).floor() * yInterval;
      if (chartMinY < 0) chartMinY = 0;
    }

    // Interval X axis: Mencari interval yang bagus, min 3 label
    final double rangeX = maxX - minX;
    // Tentukan interval agar ada sekitar 4-5 label di sumbu X
    double xInterval = rangeX / 4.0;
    // Minimum 1 menit (60000ms) untuk mencegah label numpuk jika data sangat dekat
    if (xInterval < 60000) xInterval = 60000;

    // 💡 Anda sudah memiliki FlDotData(show: true), jadi dot seharusnya muncul.

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101B2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: RepaintBoundary(
              child: LineChart(
                LineChartData(
                  minY: chartMinY,
                  maxY: chartMaxY,
                  minX: minX,
                  maxX: maxX,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.white.withOpacity(0.1),
                      strokeWidth: 1,
                    ),
                    // Hanya tampilkan garis di chartMinY dan setiap kelipatan yInterval
                    checkToShowHorizontalLine: (value) {
                      final diff = (value - chartMinY).abs();
                      // Tampilkan garis jika itu chartMinY atau mendekati kelipatan yInterval
                      return diff < 0.001 ||
                          (diff / yInterval).round() * yInterval == diff;
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval:
                            xInterval, // Menggunakan interval yang diperbaiki
                        getTitlesWidget: (value, meta) {
                          if (spots.isEmpty) return const SizedBox.shrink();

                          // Logika untuk menampilkan label di titik data yang terdekat
                          final spot = spots.reduce(
                            (a, b) => (a.x - value).abs() < (b.x - value).abs()
                                ? a
                                : b,
                          );
                          final index = spots.indexOf(spot);

                          // Tampilkan label hanya jika nilai 'value' (dari interval FlChart)
                          // sangat dekat dengan x-value dari salah satu data point
                          if (index >= 0 &&
                              index < labels.length &&
                              (value - spot.x).abs() < xInterval * 0.2) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 4,
                              child: Text(
                                labels[index],
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                    ),

                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: yInterval,
                        getTitlesWidget: (value, meta) {
                          if (value < chartMinY || value > chartMaxY)
                            return const SizedBox.shrink();

                          // Tampilkan hanya di kelipatan interval, dimulai dari chartMinY
                          final diff = (value - chartMinY).abs();
                          if ((diff / yInterval).round() * yInterval != diff &&
                              diff > 0.001) {
                            return const SizedBox.shrink();
                          }

                          // Format label: 1 desimal jika lebih besar atau sama dengan 1, 2 desimal jika lebih kecil
                          final String label = (value >= 10.0)
                              ? value.toStringAsFixed(
                                  0,
                                ) // Untuk Tegangan/Frekuensi tinggi, lebih baik tanpa desimal
                              : (value >= 1.0
                                    ? value.toStringAsFixed(1)
                                    : value.toStringAsFixed(2));

                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 12,
                            child: Text(
                              label,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      // tooltipBgColor: Colors.black54, // Ganti warna agar terlihat
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((LineBarSpot spot) {
                          String unit;
                          if (title.contains('Tegangan')) {
                            unit = 'V';
                          } else if (title.contains('Frekuensi')) {
                            unit = 'Hz';
                          } else {
                            unit = 'A';
                          }

                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(2)} $unit', // nilai y
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: color,
                      dotData: FlDotData(
                        show: true,
                      ), // 💡 Dot (titik) sudah aktif
                      spots: spots,
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
