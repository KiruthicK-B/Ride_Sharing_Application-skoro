import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/username_auth_manager.dart';

class SimpleAuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUser;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void setUser(UserModel? user) {
    _currentUser = user;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> signIn(String username, String password) async {
    setLoading(true);
    clearError();

    try {
      final result = await SimpleAuthManager.signIn(
        username: username,
        password: password,
      );

      if (result['success'] == true) {
        setUser(result['user']);
        setLoading(false);
        return true;
      } else {
        setError(result['error']);
        setLoading(false);
        return false;
      }
    } catch (e) {
      setError('An error occurred: $e');
      setLoading(false);
      return false;
    }
  }

  Future<bool> signUp({
    required String username,
    required String email,
    required String password,
    required String name,
    required String phone,
    required String userType,
  }) async {
    setLoading(true);
    clearError();

    try {
      final result = await SimpleAuthManager.signUp(
        username: username,
        email: email,
        password: password,
        name: name,
        phone: phone,
        userType: userType,
      );

      if (result['success'] == true) {
        setUser(result['user']);
        setLoading(false);
        return true;
      } else {
        setError(result['error']);
        setLoading(false);
        return false;
      }
    } catch (e) {
      setError('An error occurred: $e');
      setLoading(false);
      return false;
    }
  }

  void signOut() {
    _currentUser = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
