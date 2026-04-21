import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../discovery/discovery.dart';
import '../home/home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true; // Biến xác định đang ở form Đăng nhập hay Đăng ký

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _message = '';

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _message = 'Vui lòng nhập đủ thông tin!');
      return;
    }

    if (_isLogin) {
      // XỬ LÝ ĐĂNG NHẬP
      final userId = await AppDatabase.instance.loginUser(email, password);
      if (userId != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const MusicHomepage()),
          );
        }
      } else {
        setState(() => _message = 'Email hoặc mật khẩu không đúng!');
      }
    } else {
      // XỬ LÝ ĐĂNG KÝ
      if (username.isEmpty) {
        setState(() => _message = 'Vui lòng nhập Tên hiển thị!');
        return;
      }
      try {
        final newUserId = 'user_${DateTime.now().millisecondsSinceEpoch}'; // Tạo ID ngẫu nhiên
        await AppDatabase.instance.createUser({
          'id': newUserId,
          'username': username,
          'email': email,
          'password': password,
        });
        setState(() {
          _message = 'Đăng ký thành công! Vui lòng đăng nhập.';
          _isLogin = true; // Chuyển về màn hình đăng nhập
        });
      } catch (e) {
        // Lỗi thường do trùng Email (Ràng buộc UNIQUE trong DB)
        setState(() => _message = 'Email này đã được sử dụng!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_note, size: 80, color: Theme.of(context).primaryColor),
                const SizedBox(height: 20),
                Text(_isLogin ? 'Đăng Nhập' : 'Đăng Ký',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),

                // Ô nhập Tên (Chỉ hiện khi Đăng ký)
                if (!_isLogin) ...[
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Tên hiển thị', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Mật khẩu', border: OutlineInputBorder()),
                  obscureText: true,
                ),

                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_message, style: TextStyle(color: _message.contains('thành công') ? Colors.green : Colors.red)),
                  ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: Text(_isLogin ? 'Đăng nhập' : 'Tạo tài khoản'),
                  ),
                ),
                const SizedBox(height: 16),

                // Nút chuyển đổi giữa Login và Register
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _message = ''; // Xóa thông báo lỗi cũ
                    });
                  },
                  child: Text(_isLogin ? 'Chưa có tài khoản? Đăng ký ngay' : 'Đã có tài khoản? Đăng nhập'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}