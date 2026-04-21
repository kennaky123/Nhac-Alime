import 'package:sqflite/sqflite.dart';
import '../database.dart';
import '../model/song.dart';

abstract class Repository {
  // Lấy toàn bộ bài hát từ API
  Future<List<Song>> fetchSongs();

  // --- Các hàm tương tác với Database nội bộ ---
  Future<int> createPlaylist(String title, String userId);
  Future<List<String>> getFavoriteSongIds(String userId);
  Future<void> toggleFavorite(String userId, String songId);
  Future<List<Map<String, dynamic>>> getUserPlaylists(String userId);
  Future<void> addSongToPlaylist(int playlistId, String songId);
  Future<void> deletePlaylist(int playlistId);
  Future<List<String>> getSongIdsFromPlaylist(int playlistId);
  Future<void> updatePlaylist(int id, String newTitle);

  // SỬA LỖI: Chuyển 2 hàm này vào BÊN TRONG class Repository
  Future<List<Map<String, dynamic>>> getRecommendedSongs(String userId);
  Future<List<Map<String, dynamic>>> getTrendingSongs();
}

// Code chạy tạm để có tài khoản test đăng nhập để ngoài class
void createTestUser() async {
  await AppDatabase.instance.createUser({
    'id': 'user_01',
    'username': 'Admin Nhạc',
    'email': 'admin@gmail.com',
    'password': '123'
  });
}