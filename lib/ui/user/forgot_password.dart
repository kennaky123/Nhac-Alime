import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../../data/database.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  
  int _step = 1; // 1: Nhập email, 2: Nhập OTP, 3: Đổi mật khẩu
  String _generatedOtp = '';
  String _message = '';
  bool _isLoading = false;

  // Cấu hình Email gửi đi (Sử dụng Gmail SMTP)
  // LƯU Ý: Bạn cần tạo "Mật khẩu ứng dụng" (App Password) cho Gmail này
  final String _senderEmail = 'toandq.24itb@vku.udn.vn';
  final String _appPassword = 'elai ayfv cvrs grbr'; // Thay bằng mật khẩu ứng dụng thực tế

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _message = 'Vui lòng nhập email!');
      return;
    }

    setState(() => _isLoading = true);

    // 1. Kiểm tra email có trong DB không
    final exists = await AppDatabase.instance.checkEmailExists(email);
    if (!exists) {
      setState(() {
        _message = 'Email này chưa được đăng ký!';
        _isLoading = false;
      });
      return;
    }

    // 2. Tạo mã OTP ngẫu nhiên
    _generatedOtp = (Random().nextInt(900000) + 100000).toString();

    // 3. Gửi Email
    final smtpServer = gmail(_senderEmail, _appPassword);
    final message = Message()
      ..from = Address(_senderEmail, 'Music App Support')
      ..recipients.add(email)
      ..subject = 'Mã xác thực khôi phục mật khẩu: $_generatedOtp'
      ..text = 'Mã OTP của bạn là: $_generatedOtp. Vui lòng không chia sẻ mã này cho ai.';

    try {
      await send(message, smtpServer);
      setState(() {
        _step = 2;
        _message = 'Mã OTP đã được gửi đến $email';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi gửi mail: $e');
      setState(() {
        _message = 'Không thể gửi email. Vui lòng kiểm tra lại cấu hình SMTP!';
        _isLoading = false;
      });
      // Đối với môi trường dev, mình cho phép bỏ qua bước này để test
      // Uncomment dòng dưới nếu muốn test mà không cần gửi mail thật
      /*
      setState(() {
        _step = 2;
        _message = '[DEV] Mã OTP là: $_generatedOtp';
        _isLoading = false;
      });
      */
    }
  }

  void _verifyOtp() {
    if (_otpController.text.trim() == _generatedOtp) {
      setState(() {
        _step = 3;
        _message = 'Xác thực thành công! Nhập mật khẩu mới.';
      });
    } else {
      setState(() => _message = 'Mã OTP không chính xác!');
    }
  }

  Future<void> _resetPassword() async {
    final newPassword = _newPasswordController.text.trim();
    if (newPassword.length < 6) {
      setState(() => _message = 'Mật khẩu phải từ 6 ký tự!');
      return;
    }

    await AppDatabase.instance.resetPassword(_emailController.text.trim(), newPassword);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đổi mật khẩu thành công! Vui lòng đăng nhập lại.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.surface, colorScheme.primary.withOpacity(0.05)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              if (_step == 1) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.lock_reset_rounded, size: 80, color: colorScheme.primary),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Enter your email address to receive a verification code',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Send Verification Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else if (_step == 2) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.mark_email_read_rounded, size: 80, color: Colors.green),
                ),
                const SizedBox(height: 24),
                Text(
                  'Verification code sent to\n${_emailController.text}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: 'Enter OTP Code',
                    prefixIcon: Icon(Icons.pin_rounded),
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _verifyOtp,
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
                    child: const Text('Verify OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else if (_step == 3) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.security_rounded, size: 80, color: Colors.blue),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Almost done! Enter your new password below',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _resetPassword,
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
                    child: const Text('Update Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _message.contains('thành công') ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _message.contains('thành công') ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
