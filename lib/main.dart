import 'package:flutter/material.dart';
import 'package:music_app/ui/home/home.dart';
import 'package:music_app/ui/user/login.dart';

import 'data/database.dart';

// 1. THÊM BIẾN NÀY ĐỂ ĐIỀU KHIỂN GIAO DIỆN SÁNG/TỐI
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  // Đảm bảo Flutter đã khởi tạo xong trước khi đụng vào Database
  WidgetsFlutterBinding.ensureInitialized();

  // Tạo user mẫu để test (Chỉ cần chạy 1 lần hoặc dùng admin@gmail.com / 123)
  // await AppDatabase.instance.createUser({
  //   'id': 'user_01',
  //   'username': 'Nguyen Van A',
  //   'email': 'admin@gmail.com',
  //   'password': '123',
  // });

  runApp(const MusicApp());
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. BỌC MaterialApp BẰNG ValueListenableBuilder
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Music App',

          // --- CẤU HÌNH THEME SÁNG ---
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
            useMaterial3: true,
          ),

          // --- CẤU HÌNH THEME TỐI ---
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.black, // Cho nền đen hẳn luôn
          ),

          // 3. ÁP DỤNG THEME THEO TRẠNG THÁI CỦA NÚT GẠT
          themeMode: currentMode,

          // Giữ nguyên trang khởi đầu là LoginScreen của bạn
          home: const LoginScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}