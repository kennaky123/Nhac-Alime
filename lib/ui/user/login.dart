import 'package:flutter/material.dart';
import '../../data/firebase_service.dart';
import '../admin/admin_dashboard.dart';
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Tự động tạo admin nếu chưa có
    FirebaseService.instance.setupAdminAccount();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _message = 'Vui lòng nhập đủ thông tin!');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      if (_isLogin) {
        // XỬ LÝ ĐĂNG NHẬP VỚI FIREBASE
        final user = await FirebaseService.instance.login(email, password);
        if (user != null) {
          // LẤY QUYỀN CỦA USER
          final role = await FirebaseService.instance.getUserRole(user.uid);
          
          if (mounted) {
            if (role == 'admin') {
              // CHUYỂN SANG TRANG ADMIN
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
              );
            } else {
              // CHUYỂN SANG TRANG NGƯỜI DÙNG THƯỜNG
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MusicHomepage(userId: user.uid)),
              );
            }
          }
        }
      } else {
        // XỬ LÝ ĐĂNG KÝ VỚI FIREBASE
        if (username.isEmpty) {
          setState(() {
            _message = 'Vui lòng nhập Tên hiển thị!';
            _isLoading = false;
          });
          return;
        }
        await FirebaseService.instance.signUp(email, password, username);
        setState(() {
          _message = 'Đăng ký thành công! Vui lòng đăng nhập.';
          _isLogin = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Lỗi: ${e.toString()}';
        _isLoading = false;
      });
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
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
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