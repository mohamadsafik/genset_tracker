import 'package:flutter/material.dart';
import 'package:genset_tracker/services/monitoring_service.dart';

class MonitoringProvider extends ChangeNotifier {
  final MonitoringService service;
  Map<String, dynamic>? _monitoring;
  Map<String, dynamic>? get monitoring => _monitoring;
  Map<String, dynamic>? get gas => _gas;
  Map<String, dynamic>? get baterai => _baterai;

  Map<String, dynamic>? _engine;
  Map<String, dynamic>? _gas;
  Map<String, dynamic>? _baterai;
  Map<String, dynamic>? get engine => _engine;

  MonitoringProvider({required this.service}) {
    _init();
  }

  void _init() {
    service.listenMonitoring((data) {
      _monitoring = data;
      notifyListeners(); // UI akan rebuild otomatis
    });
    service.listenBattery((data) {
      _baterai = data;
      notifyListeners(); // UI akan rebuild otomatis
    });
    service.listenGas((data) {
      _gas = data;
      notifyListeners(); // UI akan rebuild otomatis
    });
  }

  Future<void> fetchMonitoring() async {
    _monitoring = await service.getMonitoring();
    _gas = await service.getGas();
    _monitoring = await service.getBattery();
    notifyListeners();
  }
}
