import 'dart:convert';
import 'package:flutter/services.dart';

import '../firebase_service.dart';
import '../model/song.dart';
import '../source/source.dart';
import 'repository.dart';

class MusicRepositoryImpl implements Repository {
  final FirebaseService _fb = FirebaseService.instance;
  final RemoteDataSource _api = RemoteDataSource();

  @override
  Future<List<Song>> fetchSongs(String userId) async {
    // 1. Lấy nhạc từ API JSON cũ (Tất cả mọi người đều thấy)
    final apiSongs = await _api.loadData() ?? [];

    // 2. Kiểm tra quyền Premium
    bool isPremium = false;
    if (userId.isNotEmpty) {
      isPremium = await _fb.isUserPremium(userId);
    }

    List<Song> allSongs;

    if (isPremium) {
      // 3. Nếu là Premium: Lấy thêm nhạc từ Firestore (Nhạc Lossless do Admin thêm)
      final firestoreData = await _fb.getAllSongs();
      final firestoreSongs = firestoreData.map((data) => Song(
        id: data['id'],
        title: data['title'] ?? 'Unknown',
        album: data['album'] ?? 'Unknown',
        artist: data['artist'] ?? 'Unknown',
        source: data['source'] ?? '',
        image: data['image'] ?? '',
        duration: data['duration'] ?? 240,
      )).toList();
      
      allSongs = [...apiSongs, ...firestoreSongs];
    } else {
      // Nếu không phải Premium: Chỉ trả về nhạc API
      allSongs = apiSongs;
    }

    // 4. Kiểm tra trạng thái yêu thích
    final favIds = await getFavoriteSongIds(userId);

    for (var song in allSongs) {
      if (favIds.contains(song.id)) {
        song.isFavorite = true;
      }
    }
    return allSongs;
  }

  @override
  Future<List<String>> getFavoriteSongIds(String userId) async {
    if (userId.isEmpty) return [];
    return await _fb.getFavoriteSongIds(userId);
  }

  @override
  Future<void> toggleFavorite(String userId, String songId) async {
    if (userId.isEmpty) return;
    await _fb.toggleFavorite(userId, songId);
  }

  @override
  Future<List<Map<String, dynamic>>> getUserPlaylists(String userId) async {
    if (userId.isEmpty) return [];
    return await _fb.getUserPlaylists(userId);
  }

  @override
  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    await _fb.addSongToPlaylist(playlistId, songId);
  }

  @override
  Future<String> createPlaylist(String title, String userId) async {
    return await _fb.createPlaylist(title, userId);
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    await _fb.deletePlaylist(playlistId);
  }

  @override
  Future<List<String>> getSongIdsFromPlaylist(String playlistId) async {
    return await _fb.getSongIdsFromPlaylist(playlistId);
  }

  @override
  Future<void> updatePlaylist(String id, String newTitle) async {
    await _fb.updatePlaylist(id, newTitle);
  }

  // --- DISCOVERY ---

  Future<List<Map<String, dynamic>>> _getAllSongsFromJson() async {
    final String response = await rootBundle.loadString('assets/songs.json');
    final data = await json.decode(response);
    return List<Map<String, dynamic>>.from(data['songs']);
  }

  @override
  Future<List<Map<String, dynamic>>> getTrendingSongs(String userId) async {
    final songs = await _getAllSongsFromJson();
    
    // Nếu là Premium, gộp thêm nhạc từ Firestore
    bool isPremium = await _fb.isUserPremium(userId);
    if (isPremium) {
      final firestoreSongs = await _fb.getAllSongs();
      songs.addAll(firestoreSongs);
    }

    songs.sort((a, b) {
      int counterA = a['counter'] is int ? a['counter'] : int.tryParse(a['counter'].toString()) ?? 0;
      int counterB = b['counter'] is int ? b['counter'] : int.tryParse(b['counter'].toString()) ?? 0;
      return counterB.compareTo(counterA);
    });
    return songs.take(10).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getRecommendedSongs(String userId) async {
    final songs = await _getAllSongsFromJson();

    // Nếu là Premium, gộp thêm nhạc từ Firestore
    bool isPremium = await _fb.isUserPremium(userId);
    if (isPremium) {
      final firestoreSongs = await _fb.getAllSongs();
      songs.addAll(firestoreSongs);
    }

    songs.shuffle();
    final recommended = songs.where((song) {
      int counter = song['counter'] is int ? song['counter'] : int.tryParse(song['counter'].toString()) ?? 0;
      // Nhạc từ Firestore không có counter, mặc định cho phép hiện ở Recommended
      return counter > 0 || !song.containsKey('counter');
    }).take(8).toList();
    return recommended;
  }
}
