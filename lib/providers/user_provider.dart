import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? user;
  bool isLoading = true;

  UserProvider() {
    _authService.authStateChanges().listen((event) {
      user = event;
      debugPrint('User photoURL: ${user?.photoURL}');
      isLoading = false;
      notifyListeners();
    });
  }

  Future<void> getUser(String email, String password) async {
    isLoading = true;
    notifyListeners();
    user = _authService.currentUser;
    isLoading = false;
    notifyListeners();
  }
  Future<void> signOut() async {
    await _authService.signOut();
  }
}
