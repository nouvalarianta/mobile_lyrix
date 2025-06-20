import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final PocketBase _pb = PocketBase('http://127.0.0.1:8090');

  PocketBase get pb => _pb;

  bool get isAuthenticated => _pb.authStore.isValid;

  RecordModel? get currentUser => _pb.authStore.model;

  Future<RecordModel> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      final record = await _pb.collection('users').create(body: {
        'name': name,
        'email': email,
        'password': password,
        'passwordConfirm': passwordConfirm,
        'emailVisibility': true,
      });

      await login(email: email, password: password);

      return record;
    } catch (e) {
      if (kDebugMode) {
        print('Registration error: $e');
      }
      rethrow;
    }
  }

  Future<RecordAuth> login({
    required String email,
    required String password,
  }) async {
    try {
      final authData = await _pb.collection('users').authWithPassword(
            email,
            password,
          );

      return authData;
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      rethrow;
    }
  }

  void logout() {
    _pb.authStore.clear();
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _pb.collection('users').requestPasswordReset(email);
    } catch (e) {
      if (kDebugMode) {
        print('Password reset error: $e');
      }
      rethrow;
    }
  }

  Future<RecordAuth?> refresh() async {
    try {
      if (_pb.authStore.isValid) {
        return await _pb.collection('users').authRefresh();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Refresh error: $e');
      }
      logout();
      return null;
    }
  }

  Future<RecordModel> updateProfile({
    required String id,
    String? name,
    String? email,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (email != null) data['email'] = email;

      return await _pb.collection('users').update(id, body: data);
    } catch (e) {
      if (kDebugMode) {
        print('Update profile error: $e');
      }
      rethrow;
    }
  }

  String getErrorMessage(dynamic error) {
    if (error.toString().contains('Failed to authenticate')) {
      return 'Email atau password salah';
    } else if (error.toString().contains('email')) {
      return 'Email sudah terdaftar';
    } else if (error.toString().contains('password')) {
      return 'Password tidak memenuhi kriteria';
    } else if (error.toString().contains('network')) {
      return 'Tidak dapat terhubung ke server';
    } else {
      return 'Terjadi kesalahan. Silakan coba lagi.';
    }
  }
}
