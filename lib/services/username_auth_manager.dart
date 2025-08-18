import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user_model.dart';

class SimpleAuthManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Hash password for security
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Simple username-based sign up
  static Future<Map<String, dynamic>> signUp({
    required String username,
    required String email,
    required String password,
    required String name,
    required String phone,
    required String userType,
  }) async {
    try {
      // Check if username already exists
      final existingUser = await _firestore
          .collection('users')
          .where('additionalInfo.username', isEqualTo: username)
          .get();

      if (existingUser.docs.isNotEmpty) {
        return {
          'success': false,
          'error':
              'Username already exists. Please choose a different username.',
        };
      }

      // Check if email already exists
      final existingEmail = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (existingEmail.docs.isNotEmpty) {
        return {
          'success': false,
          'error': 'Email already exists. Please use a different email.',
        };
      }

      // Create user document
      final userId = _firestore.collection('users').doc().id;
      final hashedPassword = _hashPassword(password);

      final user = UserModel(
        id: userId,
        email: email,
        name: name,
        phone: phone,
        userType: userType,
        createdAt: DateTime.now(),
        additionalInfo: {
          'username': username,
          'hashedPassword': hashedPassword,
        },
      );

      await _firestore.collection('users').doc(userId).set(user.toJson());

      return {
        'success': true,
        'user': user,
        'message': 'Account created successfully',
      };
    } catch (e) {
      return {'success': false, 'error': 'Failed to create account: $e'};
    }
  }

  // Simple username-based sign in
  static Future<Map<String, dynamic>> signIn({
    required String username,
    required String password,
  }) async {
    try {
      final hashedPassword = _hashPassword(password);

      // Find user by username and password
      final userQuery = await _firestore
          .collection('users')
          .where('additionalInfo.username', isEqualTo: username)
          .where('additionalInfo.hashedPassword', isEqualTo: hashedPassword)
          .get();

      if (userQuery.docs.isEmpty) {
        return {'success': false, 'error': 'Invalid username or password'};
      }

      final userData = userQuery.docs.first.data();
      userData['id'] = userQuery.docs.first.id;
      final user = UserModel.fromJson(userData);

      return {'success': true, 'user': user, 'message': 'Sign in successful'};
    } catch (e) {
      return {'success': false, 'error': 'Failed to sign in: $e'};
    }
  }

  // Check if username exists
  static Future<bool> checkUsernameExists(String username) async {
    try {
      final result = await _firestore
          .collection('users')
          .where('additionalInfo.username', isEqualTo: username)
          .get();
      return result.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get user by username
  static Future<UserModel?> getUserByUsername(String username) async {
    try {
      final result = await _firestore
          .collection('users')
          .where('additionalInfo.username', isEqualTo: username)
          .get();

      if (result.docs.isNotEmpty) {
        final userData = result.docs.first.data();
        userData['id'] = result.docs.first.id;
        return UserModel.fromJson(userData);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Sign out (just clear local data)
  static Future<void> signOut() async {
    // Since we're not using Firebase Auth, just clear any local data
    // This would be handled by the app state management
  }
}
