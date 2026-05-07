import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('music_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      // Cấu hình cho Web
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase(
        filePath, // Trên web không cần join(dbPath, filePath)
        version: 1,
        onCreate: _createDB,
      );
    } else {
      // Cấu hình cho Mobile (Android/iOS)
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDB,
      );
    }
  }

  Future _createDB(Database db, int version) async {
    // 1. Bảng Users: Lưu thông tin người dùng
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        photo_url TEXT
      )
    ''');

    // 2. Bảng Playlists: Lưu tên danh sách phát
    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        user_id TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 3. Bảng Playlist_Songs: Liên kết ID bài hát từ API vào Playlist (Quan hệ n-n)
    await db.execute('''
      CREATE TABLE playlist_songs (
        playlist_id INTEGER NOT NULL,
        song_id TEXT NOT NULL, -- ID bài hát từ API (ví dụ: "1121429554") 
        PRIMARY KEY (playlist_id, song_id),
        FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE
      )
    ''');

    // 4. Bảng Favorites: Lưu bài hát yêu thích của từng User
    await db.execute('''
      CREATE TABLE favorites (
        user_id TEXT NOT NULL,
        song_id TEXT NOT NULL,
        PRIMARY KEY (user_id, song_id),
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- CÁC HÀM XỬ LÝ DỮ LIỆU (CRUD) ---

  // Thêm User mới
  Future<int> createUser(Map<String, dynamic> user) async {
    final db = await instance.database;
    return await db.insert('users', user);
  }

  // Kiểm tra đăng nhập
  // Trả về user_id (String) nếu thành công, trả về null nếu thất bại
  Future<String?> loginUser(String email, String password) async {
    final db = await instance.database;

    // Truy vấn tìm user có email và mật khẩu khớp
    final result = await db.query(
      'users',
      columns: ['id'], // Chỉ cần lấy ID
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );

    if (result.isNotEmpty) {
      return result.first['id'] as String;
    } else {
      return null; // Sai email hoặc mật khẩu
    }
  }

  // Kiểm tra email tồn tại
  Future<bool> checkEmailExists(String email) async {
    final db = await instance.database;
    final result = await db.query('users', where: 'email = ?', whereArgs: [email]);
    return result.isNotEmpty;
  }

  // Cập nhật mật khẩu mới
  Future<int> resetPassword(String email, String newPassword) async {
    final db = await instance.database;
    return await db.update(
      'users',
      {'password': newPassword},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  // Thêm bài hát vào Favorite
  Future<void> toggleFavorite(String userId, String songId) async {
    final db = await instance.database;
    final exists = await db.query('favorites',
        where: 'user_id = ? AND song_id = ?', whereArgs: [userId, songId]);

    if (exists.isEmpty) {
      await db.insert('favorites', {'user_id': userId, 'song_id': songId});
    } else {
      await db.delete('favorites',
          where: 'user_id = ? AND song_id = ?', whereArgs: [userId, songId]);
    }
  }

  // Tạo Playlist mới
  Future<int> createPlaylist(String title, String userId) async {
    final db = await instance.database;
    return await db.insert('playlists', {'title': title, 'user_id': userId});
  }

  // Thêm bài hát vào Playlist
  Future<int> addSongToPlaylist(int playlistId, String songId) async {
    final db = await instance.database;
    return await db.insert('playlist_songs', {
      'playlist_id': playlistId,
      'song_id': songId,
    }, conflictAlgorithm: ConflictAlgorithm.replace); // Thay đổi ở đây: Thêm conflictAlgorithm để tránh lỗi nếu thêm 1 bài 2 lần
  }

  // Lấy danh sách ID bài hát trong một Playlist
  Future<List<String>> getSongIdsFromPlaylist(int playlistId) async {
    final db = await instance.database;
    final result = await db.query('playlist_songs',
        where: 'playlist_id = ?', whereArgs: [playlistId]);

    return result.map((json) => json['song_id'] as String).toList();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
  // Xóa Playlist
  Future<int> deletePlaylist(int playlistId) async {
    final db = await instance.database;
    return await db.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
  }
  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<Object?>? whereArgs}) async {
    final db = await instance.database; // Hoặc biến database của bạn
    return await db.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
    );
  }
} // Dấu ngoặc đóng duy nhất của class AppDatabase nằm ở đây