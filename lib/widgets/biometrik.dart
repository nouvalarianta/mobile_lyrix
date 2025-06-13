import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthPage extends StatefulWidget {
  @override
  _BiometricAuthPageState createState() => _BiometricAuthPageState();
}

class _BiometricAuthPageState extends State<BiometricAuthPage> {
  final LocalAuthentication auth = LocalAuthentication();
  String _message = 'Belum diautentikasi';

  Future<void> _authenticate() async {
    try {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      bool isAuthenticated = false;

      if (canCheckBiometrics) {
        isAuthenticated = await auth.authenticate(
          localizedReason: 'Silakan autentikasi dengan biometrik',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
      }

      setState(() {
        _message = isAuthenticated
            ? 'Autentikasi berhasil!'
            : 'Autentikasi gagal atau dibatalkan.';
      });
    } catch (e) {
      setState(() {
        _message = 'Terjadi kesalahan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login Biometrik')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_message),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authenticate,
              child: Text('Login dengan Biometrik'),
            ),
          ],
        ),
      ),
    );
  }
}