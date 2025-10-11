import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GensetHistoryChart extends StatelessWidget {
  const GensetHistoryChart({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('genset_history')
          .orderBy('Time', descending: false) // urut dari lama ke baru
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Column(
            children: [
              SizedBox(height: 16),
              Text('Error: ${snapshot.error}'),
            ],
          ));
        }

        // Langkah 2: Cek apakah ada dokumen
        // Gunakan final data = snapshot.data! untuk memudahkan
        final data = snapshot.data!;

        if (data.docs.isEmpty) { // <-- PERIKSA INI
          return Column(
            children: [
              SizedBox(height: 16),
              const Center(
                child: Text('Belum ada data history yang tersedia.',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          );
        }

        final docs = snapshot.data!.docs;
        final voltageSpots = <FlSpot>[];
        final freqSpots = <FlSpot>[];
        final currentSpots = <FlSpot>[];
        final timeLabels = <String>[];

        for (int i = 0; i < docs.length; i++) {
          final data = docs[i].data() as Map<String, dynamic>;
          final voltage = (data['Voltage'] ?? 0).toDouble();
          final freq = (data['Frequency'] ?? 0).toDouble();
          final current = (data['Current'] ?? 0).toDouble();

          final timeString = data['Time']?.toString() ?? '';
          DateTime date;

          try {
            date = DateFormat("yyyy-MM-dd HH:mm:ss").parse(timeString);
          } catch (e) {
            date = DateTime.now().subtract(Duration(minutes: docs.length - i));
          }

          voltageSpots.add(FlSpot(i.toDouble(), voltage));
          freqSpots.add(FlSpot(i.toDouble(), freq));
          currentSpots.add(FlSpot(i.toDouble(), current));
          timeLabels.add(DateFormat.Hm().format(date)); // 19:06, 19:11, dst
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Grafik Parameter Real-time",
                style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),

            // 🔵 Tegangan
            _buildChartCard(
              title: 'Tegangan',
              value: '${voltageSpots.last.y.toStringAsFixed(1)} V',
              color: Colors.blueAccent,
              spots: voltageSpots,
              labels: timeLabels,
            ),

            // 🟡 Frekuensi
            _buildChartCard(
              title: 'Frekuensi',
              value: '${freqSpots.last.y.toStringAsFixed(1)} Hz',
              color: Colors.orangeAccent,
              spots: freqSpots,
              labels: timeLabels,
            ),

            // 🔴 Arus
            _buildChartCard(
              title: 'Arus',
              value: '${currentSpots.last.y.toStringAsFixed(2)} A',
              color: Colors.redAccent,
              spots: currentSpots,
              labels: timeLabels,
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartCard({
    required String title,
    required String value,
    required Color color,
    required List<FlSpot> spots,
    required List<String> labels,
  }) {
    // Hitung nilai min/max Y untuk menentukan skala chart
    final double maxY = spots.isEmpty ? 10.0 : spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.1;
    final double minY = spots.isEmpty ? 0.0 : spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) * 0.9;

    // Tentukan interval Y. Disini saya ambil 4 interval utama.
    final double yInterval = (maxY - minY) / 4;
    final double chartMaxY = maxY + (maxY * 0.05);
    final double chartMinY = minY - (minY * 0.05).clamp(0, 1);

    // Tentukan interval X (untuk bottomTitles)
    final double interval = 1.0;

    return Container(
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
              Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              Text(value,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minY: chartMinY, // Terapkan min Y yang dihitung
                maxY: chartMaxY, // Terapkan max Y yang dihitung
                minX: 0,
                maxX: (spots.length - 1).toDouble(),

                gridData: FlGridData(
                  show: true, // Tampilkan grid untuk sumbu Y
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: interval, // Gunakan interval 1.0
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();

                        // Logika untuk bottomTitles (sumbu X)
                        if (labels.length > 5 && index % ((labels.length / 4).ceil()) != 0 && index != labels.length - 1) {
                          return const SizedBox.shrink();
                        }

                        if (index >= 0 && index < labels.length) {
                          return SideTitleWidget( // Tambahkan SideTitleWidget untuk kontrol spasi
                            axisSide: meta.axisSide,
                            space: 4,
                            child: Text(
                              labels[index],
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),

                  // 💡 PERUBAHAN: leftTitles (Sumbu Y)
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, // Aktifkan label sumbu Y
                      reservedSize: 48, // Ruang yang dicadangkan untuk label
                      interval: yInterval, // Gunakan interval Y yang dihitung
                      getTitlesWidget: (value, meta) {
                        // Filter nilai yang tidak perlu (nilai di luar batas)
                        if (value < chartMinY || value > chartMaxY) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 12, // Jarak dari garis Y (sumbu 0)
                          child: Text(
                            value.toStringAsFixed(1), // Format 1 desimal (seperti screenshot)
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // ------------------------------------

                  rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: color,
                    dotData: FlDotData(show: false), // Sembunyikan titik agar lebih rapi
                    spots: spots,
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
