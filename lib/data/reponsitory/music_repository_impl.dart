import 'dart:convert';
import 'package:flutter/services.dart';

import '../database.dart';
import '../model/song.dart';
import '../source/source.dart';
import 'repository.dart';

class MusicRepositoryImpl implements Repository {
  final AppDatabase _db = AppDatabase.instance;
  final RemoteDataSource _api = RemoteDataSource();

  // ==========================================
  // PHẦN 1: CÁC HÀM TỪ API VÀ DATABASE CŨ CỦA BẠN
  // ==========================================

  @override
  Future<List<Song>> fetchSongs() async {
    final allSongs = await _api.loadData();

    if (allSongs == null) {
      return [];
    }

    String currentUserId = "user_01";
    final favIds = await getFavoriteSongIds(currentUserId);

    for (var song in allSongs) {
      if (favIds.contains(song.id)) {
        song.isFavorite = true;
      }
    }
    return allSongs;
  }

  @override
  Future<List<String>> getFavoriteSongIds(String userId) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorites',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) => maps[i]['song_id'] as String);
  }

  @override
  Future<void> toggleFavorite(String userId, String songId) async {
    await _db.toggleFavorite(userId, songId);
  }

  @override
  Future<List<Map<String, dynamic>>> getUserPlaylists(String userId) async {
    final db = await _db.database;
    return await db.query('playlists', where: 'user_id = ?', whereArgs: [userId]);
  }

  @override
  Future<void> addSongToPlaylist(int playlistId, String songId) async {
    await _db.addSongToPlaylist(playlistId, songId);
  }

  @override
  Future<int> createPlaylist(String title, String userId) async {
    return await _db.createPlaylist(title, userId);
  }

  @override
  Future<void> deletePlaylist(int playlistId) async {
    await _db.deletePlaylist(playlistId);
  }

  @override
  Future<List<String>> getSongIdsFromPlaylist(int playlistId) async {
    return await _db.getSongIdsFromPlaylist(playlistId);
  }

  @override
  Future<void> updatePlaylist(int id, String newTitle) async {
    final db = await _db.database;
    await db.update(
      'playlists',
      {'title': newTitle},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // PHẦN 2: CHỨC NĂNG KHÁM PHÁ (DISCOVERY) MỚI
  // ==========================================

  // Hàm phụ trợ: Đọc toàn bộ danh sách bài hát từ file JSON
  Future<List<Map<String, dynamic>>> _getAllSongsFromJson() async {
    final String response = await rootBundle.loadString('assets/songs.json');
    final data = await json.decode(response);
    return List<Map<String, dynamic>>.from(data['songs']);
  }

  @override
  Future<List<Map<String, dynamic>>> getTrendingSongs() async {
    final songs = await _getAllSongsFromJson();

    // Sắp xếp giảm dần theo cột 'counter'
    songs.sort((a, b) {
      int counterA = a['counter'] is int ? a['counter'] : int.tryParse(a['counter'].toString()) ?? 0;
      int counterB = b['counter'] is int ? b['counter'] : int.tryParse(b['counter'].toString()) ?? 0;
      return counterB.compareTo(counterA);
    });

    // Lấy 10 bài đứng đầu
    return songs.take(10).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getRecommendedSongs(String userId) async {
    final songs = await _getAllSongsFromJson();

    // Xáo trộn để có sự mới mẻ
    songs.shuffle();

    // Ưu tiên chọn những bài hát có counter lớn hơn 0
    final recommended = songs.where((song) {
      int counter = song['counter'] is int ? song['counter'] : int.tryParse(song['counter'].toString()) ?? 0;
      return counter > 0;
    }).take(8).toList();

    return recommended;
  }
}