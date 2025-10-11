import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum RangeMode { Harian, Mingguan, Bulanan, Tahunan }

class StatistikPemakaianScreen extends StatefulWidget {
  const StatistikPemakaianScreen({Key? key}) : super(key: key);

  @override
  State<StatistikPemakaianScreen> createState() => _StatistikPemakaianScreenState();
}

class _StatistikPemakaianScreenState extends State<StatistikPemakaianScreen> {
  RangeMode _mode = RangeMode.Mingguan;

  static const String AGGREGATE_FIELD = 'Power';

  /// Real-time stream from Firestore collection genset_history
  Stream<QuerySnapshot<Map<String, dynamic>>> get _historyStream =>
      FirebaseFirestore.instance.collection('genset_history').orderBy('CreatedAt', descending: false).snapshots();

  // 💡 PERUBAHAN: Mengembalikan Map yang berisi buckets dan semua data mentah yang terfilter
  Map<String, dynamic> _aggregate(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return {'buckets': <MapEntry<String, double>>[], 'filteredValues': <double>[]};

    final now = DateTime.now();
    DateTime getCreatedAt(Map<String, dynamic> d) {
      final v = d['CreatedAt'];
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    final Map<String, double> buckets = {};
    // 💡 Data mentah yang lolos filter waktu
    final List<double> filteredValues = [];

    for (var doc in docs) {
      final d = doc.data();
      final dt = getCreatedAt(d);

      final value = (d[AGGREGATE_FIELD] ?? 0).toDouble();

      String key;
      bool skip = false;

      if (_mode == RangeMode.Harian) {
        final today = DateTime(now.year, now.month, now.day);
        if (dt.isBefore(today)) skip = true;
        key = DateFormat.H().format(dt);
      } else if (_mode == RangeMode.Mingguan) {
        final start = now.subtract(const Duration(days: 6));
        if (dt.isBefore(DateTime(start.year, start.month, start.day))) skip = true;
        key = DateFormat('yyyy-MM-dd').format(dt);
      } else if (_mode == RangeMode.Bulanan) {
        final monthStart = DateTime(now.year, now.month, 1);
        if (dt.isBefore(monthStart) || dt.month != now.month || dt.year != now.year) skip = true;
        key = DateFormat('yyyy-MM-dd').format(dt);
      } else {
        final yearStart = DateTime(now.year, 1, 1);
        if (dt.isBefore(yearStart) || dt.year != now.year) skip = true;
        key = DateFormat('yyyy-MM').format(dt);
      }

      if (!skip) {
        buckets[key] = (buckets[key] ?? 0) + value;
        // 💡 Tambahkan nilai mentah ke list
        filteredValues.add(value);
      }
    }

    // Mengubah Map menjadi List<MapEntry> berurut (untuk chart)
    List<MapEntry<String,double>> chartBuckets;
    if (_mode == RangeMode.Harian) {
      chartBuckets = List.generate(24, (i) => MapEntry(i.toString(), buckets[i.toString()] ?? 0));
    } else if (_mode == RangeMode.Mingguan) {
      final start = now.subtract(const Duration(days: 6));
      chartBuckets = List.generate(7, (i) {
        final day = start.add(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(day);
        final label = DateFormat.E('id').format(day);
        return MapEntry(label, buckets[key] ?? 0);
      });
    } else if (_mode == RangeMode.Bulanan) {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      chartBuckets = List.generate(daysInMonth, (i) {
        final dt = DateTime(now.year, now.month, i + 1);
        final key = DateFormat('yyyy-MM-dd').format(dt);
        return MapEntry((i + 1).toString(), buckets[key] ?? 0);
      });
    } else {
      chartBuckets = List.generate(12, (m) {
        final dt = DateTime(now.year, m + 1, 1);
        final key = DateFormat('yyyy-MM').format(dt);
        return MapEntry(DateFormat.MMM('id').format(dt), buckets[key] ?? 0);
      });
    }

    return {'buckets': chartBuckets, 'filteredValues': filteredValues};
  }

  // 💡 PERBAIKAN TOTAL: Menerima SEMUA data mentah yang terfilter
  Map<String, double> _statsFromBuckets(List<double> filteredValues) {
    final values = filteredValues.where((v) => v > 0).toList();
    if (values.isEmpty) {
      return {'total': 0.0, 'avg': 0.0, 'peak': 0.0};
    }

    // Durasi setiap dokumen/bucket yang dihitung adalah 1 menit (1/60 jam)
    const double hoursPerMinute = 1.0 / 60.0;

    // 1. Total kWh: Jumlahkan kWh dari setiap menit data mentah yang aktif.
    double totalKwh = 0.0;
    for (double powerWatt in values) {
      final double powerKw = powerWatt / 1000.0;
      final kwhConsumed = powerKw * hoursPerMinute;
      totalKwh += kwhConsumed;
    }

    // 2. Rata-rata kWh: Total kWh dibagi jumlah dokumen (menit) yang aktif.
    final avgKwh = totalKwh / values.length;

    // 3. Puncak (Peak Power/kW): Ambil nilai tertinggi dari data mentah
    final peakWatt = values.reduce((a, b) => a > b ? a : b);
    final peakKw = peakWatt / 1000.0;

    return {
      'total': totalKwh,
      'avg': avgKwh,
      'peak': peakKw,
    };
  }

  // Export CSV (write aggregated rows)
  Future<void> _exportCSV(List<MapEntry<String,double>> buckets) async {
    final rows = <List<dynamic>>[];
    rows.add(['Label', 'Watt']);
    for (var e in buckets) {
      rows.add([e.key, e.value.toStringAsFixed(0)]);
    }
    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/consumption_${_mode.name.toLowerCase()}.csv');
    await file.writeAsString(csvData);
    await Share.shareXFiles([XFile(file.path)], text: 'Export ${_mode.name} consumption');
  }

  // Export Excel (simple sheet)
  Future<void> _exportExcel(List<MapEntry<String,double>> buckets) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow(['Label', 'Watt']);
    for (var e in buckets) {
      sheet.appendRow([e.key, e.value]);
    }
    final dir = await getApplicationDocumentsDirectory();
    final fileBytes = excel.encode();
    final file = File('${dir.path}/consumption_${_mode.name.toLowerCase()}.xlsx');
    if (fileBytes != null) {
      await file.writeAsBytes(fileBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Export ${_mode.name} consumption (excel)');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal generate excel')));
    }
  }

  Widget _buildBarChart(List<MapEntry<String,double>> buckets) {
    if (buckets.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('Tidak ada data', style: TextStyle(color: Colors.white54))),
      );
    }
    double niceCeil(double value) {
      if (value <= 10) return (value.ceilToDouble());
      double magnitude = pow(10, value.toStringAsFixed(0).length - 1).toDouble();
      return (value / magnitude).ceil() * magnitude;
    }

    final maxVal = niceCeil(buckets.map((e) => e.value).reduce(max));
    double interval = (maxVal / 5).ceilToDouble();

    final barGroups = List.generate(buckets.length, (i) {
      final val = buckets[i].value;
      return BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: val,
            width: 20,
            borderRadius: BorderRadius.circular(6),
            color: const Color(0xFF3BD07E),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxVal == 0 ? 1 : maxVal,
              color: Colors.transparent,
            ),
          )
        ],
      );
    });

    final chartWidth = (buckets.length * 24.0).clamp(0, double.infinity) as double;

    if (interval == 0) interval = 1;

    return SizedBox(
      height: 220,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: chartWidth < MediaQuery.of(context).size.width
              ? MediaQuery.of(context).size.width
              : chartWidth,
          child: BarChart(
            BarChartData(
              maxY: (maxVal * 1.1).clamp(1.0, double.infinity),
              minY: 0,
              barGroups: barGroups,
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.white12,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= buckets.length) return const SizedBox.shrink();
                      final label = buckets[idx].key;
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 4,
                        child: Transform.rotate(
                          angle: -0.5,
                          child: Text(
                            label,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      );
                    },
                    reservedSize: 60,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      if (value > maxVal || value % interval != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          value.toStringAsFixed(0),
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      );
                    },
                    reservedSize: 50,
                  ),
                ),

                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barTouchData: BarTouchData(enabled: false),
            ),
          ),
        ),
      ),
    );
  }


  // UI header: export buttons and title
  Widget _buildHeader(List<MapEntry<String,double>> buckets, Map<String,double> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Statistik Pemakaian Listrik', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        Row(
          children: [
            // CSV
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _exportCSV(buckets),
                icon: const Icon(Icons.download_rounded, color: Colors.black87),
                label: const Text('CSV', style: TextStyle(color: Colors.black87)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3BD07E), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _exportExcel(buckets),
                icon: const Icon(Icons.file_copy, color: Colors.white),
                label: const Text('Excel', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D6BFF), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Total consumption card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF101827), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total Konsumsi', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('${stats['total']!.toStringAsFixed(2)} kWh', style: const TextStyle(fontSize: 28, color: Color(0xFF3BD07E), fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('kWh dari data aktif', style: TextStyle(color: Colors.white54)),
          ]),
        ),

        const SizedBox(height: 12),

        // Range selector (segmented)
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: const Color(0xFF101827), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: RangeMode.values.map((r) {
              final selected = r == _mode;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _mode = r),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: selected ? const Color(0xFF2C3540) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(r.name, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontWeight: FontWeight.w600))),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071025),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _historyStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData) {
                return const Center(child: Text('No data', style: TextStyle(color: Colors.white54)));
              }

              final docs = snapshot.data!.docs;
              // 💡 Panggil aggregate dan dapatkan kedua list
              final aggregatedData = _aggregate(docs);
              final buckets = aggregatedData['buckets'] as List<MapEntry<String, double>>;
              final filteredValues = aggregatedData['filteredValues'] as List<double>;

              // 💡 Hitung statistik dari semua data mentah yang terfilter
              final stats = _statsFromBuckets(filteredValues);

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 0),
                    _buildHeader(buckets, stats),
                    const SizedBox(height: 12),
                    Text('Konsumsi Per ${_mode == RangeMode.Harian ? 'Jam' : _mode == RangeMode.Mingguan ? 'Hari' : _mode == RangeMode.Bulanan ? 'Hari' : 'Bulan'} (Watt)', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    // Card with chart
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF0E1720), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          _buildBarChart(buckets),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                
                    // Bottom small cards
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: const Color(0xFF0E1720), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                // Menampilkan Rata-rata KWH per menit (data aktif)
                                Text(stats['avg']!.toStringAsFixed(2), style: const TextStyle(color: Color(0xFF5CC9FF), fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                const Text('Rata-rata kWh', style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: const Color(0xFF0E1720), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                // Menampilkan Puncak Power (kW)
                                Text(stats['peak']!.toStringAsFixed(1), style: const TextStyle(color: Color(0xFF3BD07E), fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                // LABEL KOREKSI: Puncak harus kW
                                const Text('Puncak kW', style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // footer spacer
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}