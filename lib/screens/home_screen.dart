import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:genset_tracker/providers/monitoring_provider.dart';
import 'package:genset_tracker/providers/user_provider.dart';
import 'package:genset_tracker/screens/Profile.dart';
import 'package:genset_tracker/screens/animated_flow.dart';
import 'package:genset_tracker/screens/history_chart.dart';
import 'package:genset_tracker/screens/history_screen.dart';
import 'package:provider/provider.dart';

import 'history_screen.dart';

// --- Placeholder Constants for Design ---
const Color kDarkBackground = Color(0xFF071025);
const Color kCardBackground = Color(0xFF2C2C2E);
const Color kSurfaceColor = Color(0xFF101B2D);
const Color kAccentColor = Color(0xFF5E5CE6); // Primary accent color
const Color kStandbyColor = Color(0xFF8E8E93); // Grey for standby/off elements
const Color kRunningColor = Color(0xFF34C759); // Green for running/on elements

// --- Utility Function ---

// Safely extract and format data from monitoring map
String formatData(Map<String, dynamic>? map, String key, [String unit = '']) {
  if (map == null || map[key] == null) return '0.0 $unit';
  final value = map[key];
  if (value is num) return '${value.toStringAsFixed(1)} $unit';
  return '$value $unit';
}

// --- Main Widget (Stateful) ---

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Pages for the Bottom Navigation Bar
  final List<Widget> _pages = [
    const MonitoringView(), // The main redesigned screen
    StatistikPemakaianScreen(),
    ProfileScreen()
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBackground,
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: kSurfaceColor,
        selectedItemColor: Colors.white,
        unselectedItemColor: kStandbyColor,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_outlined),
            activeIcon: Icon(Icons.show_chart),
            label: 'Grafik',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}

// --- Monitoring View (The Redesigned Screen) ---

class MonitoringView extends StatelessWidget {
  const MonitoringView({super.key});

  @override
  Widget build(BuildContext context) {
    final monitoring = context.watch<MonitoringProvider>().monitoring;
    final gas = context.watch<MonitoringProvider>().gas;
    final baterai = context.watch<MonitoringProvider>().baterai;
    final user = Provider.of<UserProvider>(context).user;


    if (monitoring == null || user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Default to 'N/A' or 'STANDBY' if data is not ready
// 1. Ambil data mentah (String & double)
    final String timeString = monitoring['time'] as String;
    final double voltage = monitoring['voltage'] as double;
    final DateTime timeNow = DateTime.now();

// 2. Konversi String Waktu ke DateTime
    final DateTime lastReadingTime = DateTime.parse(timeString);

// 3. Tentukan batas waktu (5 menit yang lalu)
    final DateTime fiveMinutesAgo = timeNow.subtract(const Duration(minutes: 5));

    final String engineStatus;

// Logika ON/OFF:
// Genset OFF jika: (Voltase <= 0.0) ATAU (Waktu terakhir lebih lama dari 5 menit yang lalu)
    if (voltage <= 0.0 || lastReadingTime.isBefore(fiveMinutesAgo)) {
      engineStatus = 'OFF';
    } else {
      engineStatus = 'ON';
    }
    final bool isGensetRunning = engineStatus == 'ON';


    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 56,
            bottom: 24,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // 1. Header Section
              _buildPowerHeader(context, isGensetRunning, monitoring, user),
              const SizedBox(height: 24),

              // 2. Power Flow Section
              const Text(
                'Power Flow',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _buildPowerFlowDiagram(
                context,
                isGensetRunning,
                formatData(monitoring, 'power'),
                  gas?['persen'].toString()??"",
                  baterai?['persen'].toString()??""
              ),
              const SizedBox(height: 32),

              // 3. Real-time Parameters
              _buildRealtimeParameters(context, monitoring, isGensetRunning),
              const SizedBox(height: 32),

              // 4. Status Card
              _buildStatusCard(context, engineStatus, isGensetRunning),
            ]),
          ),
        ),
      ],
    );
  }
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getInitialsFromEmail(String email) {
    if (email.isEmpty) return '?';

    // ambil bagian sebelum '@'
    String namePart = email.split('@').first;

    // ambil maksimal 2 huruf awal
    String initials = namePart.length >= 2
        ? namePart.substring(0, 2).toUpperCase()
        : namePart.substring(0, 1).toUpperCase();

    return initials;
  }

  Widget _buildPowerHeader(
      BuildContext context,
      bool isGensetRunning,
      Map<String, dynamic> monitoring,
      User? user,
      ) {
    String greeting = _getGreeting();
    String displayName =
    (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName!
        : (user?.email ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bagian atas: profil + status on/off
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 👤 Kiri
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blueGrey.shade700,
                  backgroundImage: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                      ? NetworkImage(user.photoURL!)
                      : null, // kalau null, tampilkan inisial
                  child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                      ? Text(
                    _getInitialsFromEmail(user?.email ?? ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : null,
                ),


                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$greeting 👋',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.wifi, size: 14, color: Colors.greenAccent),
                      ],
                    ),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ⚡ Kanan (Status ON)
            Stack(
              alignment: Alignment.center,
              children: [
                if (isGensetRunning)
                  _buildPulsingGlow(kRunningColor), // efek glow animasi
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isGensetRunning ? kRunningColor : kStandbyColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (isGensetRunning)
                        BoxShadow(
                          color: kRunningColor.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white),
                ),
                Positioned(
                  bottom: -18,
                  child: Text(
                    isGensetRunning ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: isGensetRunning ? kRunningColor : kStandbyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 🕒 Status terakhir card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Status Terakhir:',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              Row(
                children: [
                  Text(
                    monitoring['time'].toString().split(' ')[1]??'',
                    style: TextStyle(
                      color: isGensetRunning ? Colors.greenAccent : Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isGensetRunning ? 'BEROPERASI' : 'STANDBY',
                      style: TextStyle(
                        color: isGensetRunning
                            ? Colors.greenAccent
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 🌈 Animasi Glow Efek
  Widget _buildPulsingGlow(Color color) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.8, end: 1.2),
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.03),
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }




  Widget _buildPowerFlowDiagram(
    BuildContext context,
    bool isGensetRunning,
    String powerValue,
      String gasValue,
      String batteryValue ,
  ) {
    // A simplified diagram using Column and Row
    const double nodeSize = 70;
    const TextStyle nodeTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
    );

    // Node A: Source (Gas)
    Widget gasNode = _buildFlowCircle(
      'Gas\n$gasValue%',
      Colors.orange,
      nodeSize,
      nodeTextStyle,
    );

    // Node B: Generator (Center)
    Widget generatorNode = _buildFlowCircle(
      'Generator',
      kAccentColor,
      nodeSize,
      nodeTextStyle,
    );

    // Node C: Storage (Baterai) - In image, it connects to Generator
    Widget batteryNode = _buildFlowCircle(
      'Baterai\n$batteryValue%',
      kAccentColor,
      nodeSize,
      nodeTextStyle,
    );

    // Node D: Load (Bottom)
    Widget loadNode = Container(
      width: nodeSize + 20,
      height: nodeSize - 19,
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.power_settings_new, color: Colors.white, size: 20),
            Text('Load', style: nodeTextStyle),
            Text(
              powerValue,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );

    // Helper for lines (visual only)
    Widget verticalLine = AnimatedFlowLine(
      width: 2,
      height: 24,
      isActive: isGensetRunning,
      color: isGensetRunning ? kRunningColor : kStandbyColor,
      direction: Axis.vertical,
    );

    Widget horizontalLine = AnimatedFlowLine(
      width: 24,
      height: 2,
      isActive: isGensetRunning,
      color: isGensetRunning ? kRunningColor : kStandbyColor,
      direction: Axis.horizontal,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            gasNode,
            horizontalLine,
            generatorNode,
            horizontalLine,
            batteryNode,
          ],
        ),
        verticalLine,
        loadNode,
        const SizedBox(height: 16),
        Text(
          isGensetRunning ? '• Power Flow Aktif' : '• Power Flow Standby',
          style: TextStyle(
            color: isGensetRunning ? kRunningColor : kStandbyColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFlowCircle(
    String text,
    Color color,
    double size,
    TextStyle style,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(text, textAlign: TextAlign.center, style: style),
      ),
    );
  }

  Widget _buildRealtimeParameters(
    BuildContext context,
    Map<String, dynamic>? monitoring,
    bool isGensetRunning,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Parameter Real-time',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildParameterRow(
                'Tegangan',
                formatData(monitoring, 'voltage', 'V'),
                Colors.blue,
                isGensetRunning,
              ),
              _buildParameterRow(
                'Frekuensi',
                formatData(monitoring, 'frequency', 'Hz'),
                Colors.orange,
                isGensetRunning,
              ),
              _buildParameterRow(
                'Arus',
                formatData(monitoring, 'current', 'A'),
                Colors.red,
                isGensetRunning,
              ),
              _buildParameterRow(
                'Power Factor',
                formatData(monitoring, 'pf'),
                Colors.yellow,
                isGensetRunning,
                includeUnit: false,
              ),

            ],
          ),
        ),
        GensetHistoryChart(),
      ],
    );
  }

  Widget _buildParameterRow(
    String label,
    String value,
    Color color,
    bool isGensetRunning, {
    bool includeUnit = true,
  }) {
    // Only show real values if genset is running, otherwise 0.0 or N/A
    String displayValue = isGensetRunning
        ? value
        : (includeUnit ? '0.0 ${value.split(' ').last}' : '0.0');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white)),
            ],
          ),
          Text(
            displayValue,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    String engineStatus,
    bool isGensetRunning,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isGensetRunning ? kRunningColor : kCardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.power_settings_new, color: Colors.white, size: 40),
          const SizedBox(height: 16),
          Text(
            isGensetRunning
                ? 'Genset dalam Mode Running'
                : 'Genset dalam Mode Standby',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isGensetRunning
                ? 'Genset sedang beroperasi dan menyuplai daya.'
                : 'Nyalakan genset untuk melihat parameter dan grafik real-time.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}
