import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../discovery/discovery.dart';
import '../home/home.dart';
import 'forgot_password.dart';

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
            context, MaterialPageRoute(builder: (context) => MusicHomepage(userId: userId)),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withOpacity(0.1),
              colorScheme.surface,
              colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.music_note_rounded, size: 80, color: colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    _isLogin ? 'Sign in to continue' : 'Join our music community',
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 16),
                  ),
                  const SizedBox(height: 40),

                  // Ô nhập Tên (Chỉ hiện khi Đăng ký)
                  if (!_isLogin) ...[
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                  ),

                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                  if (_message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
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
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                      ),
                      child: Text(
                        _isLogin ? 'Sign In' : 'Sign Up',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Nút chuyển đổi giữa Login và Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? "Don't have an account? " : "Already have an account? ",
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _message = '';
                          });
                        },
                        child: Text(
                          _isLogin ? 'Sign Up' : 'Sign In',
                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}