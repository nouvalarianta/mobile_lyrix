import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OTPLoginPage extends StatefulWidget {
  @override
  _OTPLoginPageState createState() => _OTPLoginPageState();
}

class _OTPLoginPageState extends State<OTPLoginPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String _verificationId = '';
  bool _otpSent = false;

  void _sendOTP() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneController.text,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        print('Verifikasi gagal: ${e.message}');
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  void _verifyOTP() async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: _otpController.text,
    );

    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      print('Login sukses!');
    } catch (e) {
      print('OTP salah!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login dengan OTP')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: 'Nomor Telepon (+62...)'),
            ),
            if (_otpSent)
              TextField(
                controller: _otpController,
                decoration: InputDecoration(labelText: 'Kode OTP'),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _otpSent ? _verifyOTP : _sendOTP,
              child: Text(_otpSent ? 'Verifikasi OTP' : 'Kirim OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
