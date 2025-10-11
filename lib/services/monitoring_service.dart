import 'package:firebase_database/firebase_database.dart';

class MonitoringService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<Map<String, dynamic>?> getMonitoring() async {
    DatabaseEvent event = await _db.child('monitoring').once();
    if (event.snapshot.exists) {
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    }
    return null;
  }
  Future<Map<String, dynamic>?> getBattery() async {
    DatabaseEvent event = await _db.child('baterai').once();
    if (event.snapshot.exists) {
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    }
    return null;
  }
  Future<Map<String, dynamic>?> getGas() async {
    DatabaseEvent event = await _db.child('gas').once();
    if (event.snapshot.exists) {
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    }
    return null;
  }

  void listenMonitoring(void Function(Map<String, dynamic>) onData) {
    _db.child('monitoring').onValue.listen((event) {
      final monitoring = Map<String, dynamic>.from(event.snapshot.value as Map);
      onData(monitoring);
    });
  }
  void listenGas(void Function(Map<String, dynamic>) onData) {
    _db.child('gas').onValue.listen((event) {
      final monitoring = Map<String, dynamic>.from(event.snapshot.value as Map);
      onData(monitoring);
    });
  }
  void listenBattery(void Function(Map<String, dynamic>) onData) {
    _db.child('baterai').onValue.listen((event) {
      final monitoring = Map<String, dynamic>.from(event.snapshot.value as Map);
      onData(monitoring);
    });
  }
}
