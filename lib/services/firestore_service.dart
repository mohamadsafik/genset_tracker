import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get users => _db.collection('users');

  Future<void> addUser(String uid, Map<String, dynamic> data) async {
    await users.doc(uid).set(data);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await users.doc(uid).update(data);
  }

  Future<void> deleteUser(String uid) async {
    await users.doc(uid).delete();
  }

  Stream<DocumentSnapshot> getUserStream(String uid) {
    return users.doc(uid).snapshots();
  }
}
