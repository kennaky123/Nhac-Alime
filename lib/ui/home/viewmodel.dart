import 'package:flutter/material.dart';
import '../../data/model/song.dart';
import '../../data/reponsitory/repository.dart';

class MusicViewModel extends ChangeNotifier {
  final Repository _repository;
  final String userId;

  List<Song> _songs = [];
  List<Song> _filteredSongs = [];
  List<Song> get songs => _filteredSongs.isEmpty && _searchQuery.isEmpty ? _songs : _filteredSongs;

  String _searchQuery = "";
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  MusicViewModel({required Repository repository, required this.userId}) : _repository = repository;

  // 1. Hàm load nhạc (đã bao gồm trạng thái Favorite từ DB)
  Future<void> loadSongs() async {
    _isLoading = true;
    notifyListeners();

    try {
      _songs = await _repository.fetchSongs(userId);
      _filterSongs(); // Áp dụng lọc ngay sau khi tải
    } catch (e) {
      debugPrint("Error loading songs: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchSongs(String query) {
    _searchQuery = query;
    _filterSongs();
    notifyListeners();
  }

  void _filterSongs() {
    if (_searchQuery.isEmpty) {
      _filteredSongs = _songs;
    } else {
      _filteredSongs = _songs
          .where((song) =>
              song.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              song.artist.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  // 2. Hàm xử lý khi người dùng nhấn nút "Tim"
  Future<void> toggleFavorite(Song song) async {
    await _repository.toggleFavorite(userId, song.id);
    song.isFavorite = !song.isFavorite;
    notifyListeners();
  }

  List<Map<String, dynamic>> _playlists = [];
  List<Map<String, dynamic>> get playlists => _playlists;

  Future<void> loadUserPlaylists() async {
    _playlists = await _repository.getUserPlaylists(userId);
    notifyListeners();
  }

  Future<void> createNewPlaylist(String title) async {
    await _repository.createPlaylist(title, userId);
    await loadUserPlaylists();
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    await _repository.addSongToPlaylist(playlistId, songId);
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    for (var playlist in _playlists) {
      if (playlist['id'].toString() == playlistId) {
        playlist['title'] = newName;
        break;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
