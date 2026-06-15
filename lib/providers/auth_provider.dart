import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.login(email, password);
      if (user == null) {
        _error = 'Email ou mot de passe incorrect';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _user = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Impossible de se connecter à la base de données';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    _user = User(
      id: 1,
      username: username,
      email: email,
      role: 'user',
      createdAt: DateTime.now(),
    );
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _user = null;
    notifyListeners();
  }

  void setUser(User user) {
    _user = user;
    notifyListeners();
  }
}
