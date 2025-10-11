import 'package:firebase_database/firebase_database.dart';

class DBService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<void> saveUser(String uid, Map<String, dynamic> data) async {
    await _db.child('users/$uid').set(data);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.child('users/$uid').update(data);
  }

  Future<void> deleteUser(String uid) async {
    await _db.child('users/$uid').remove();
  }
}
