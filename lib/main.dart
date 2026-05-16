import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:music_app/ui/user/login.dart';

// 1. THÊM BIẾN NÀY ĐỂ ĐIỀU KHIỂN GIAO DIỆN SÁNG/TỐI
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  // Đảm bảo Flutter đã khởi tạo xong trước khi đụng vào Database hoặc Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Lưu ý: Code sẽ lỗi ở đây nếu chưa có file google-services.json
  }

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

          // --- CẤU HÌNH THEME SÁNG (Ocean Blue) ---
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0288D1),
              primary: const Color(0xFF0288D1),
              secondary: const Color(0xFF26C6DA),
              tertiary: const Color(0xFF009688),
              surfaceVariant: const Color(0xFFE1F5FE),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              titleTextStyle: TextStyle(color: Color(0xFF01579B), fontSize: 20, fontWeight: FontWeight.bold),
              iconTheme: IconThemeData(color: Color(0xFF0288D1)),
            ),
            scaffoldBackgroundColor: const Color(0xFFF0F8FF),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0288D1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.blue.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.blue.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF0288D1), width: 2),
              ),
            ),
          ),

          // --- CẤU HÌNH THEME TỐI (Deep Sea) ---
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00B0FF),
              primary: const Color(0xFF40C4FF),
              secondary: const Color(0xFF1DE9B6),
              tertiary: const Color(0xFF00E5FF),
              surface: const Color(0xFF001219),
              surfaceVariant: const Color(0xFF001E2B),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF000B14),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              titleTextStyle: TextStyle(color: Color(0xFFE1F5FE), fontSize: 20, fontWeight: FontWeight.bold),
              iconTheme: IconThemeData(color: Color(0xFF40C4FF)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0091EA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shadowColor: const Color(0xFF00B0FF).withOpacity(0.4),
                elevation: 8,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF001E2B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF40C4FF), width: 2),
              ),
            ),
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