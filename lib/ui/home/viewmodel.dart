import 'package:flutter/material.dart';
import '../../data/model/song.dart';
import '../../data/reponsitory/repository.dart';

class MusicViewModel extends ChangeNotifier {
  final Repository _repository;

  List<Song> _songs = [];
  List<Song> get songs => _songs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  MusicViewModel({required Repository repository}) : _repository = repository;

  // 1. Hàm load nhạc (đã bao gồm trạng thái Favorite từ DB)
  Future<void> loadSongs() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Gọi hàm fetchSongs từ Repository mới (hàm này đã mix API + DB)
      _songs = await _repository.fetchSongs();
    } catch (e) {
      debugPrint("Error loading songs: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. Hàm xử lý khi người dùng nhấn nút "Tim"
  Future<void> toggleFavorite(Song song) async {
    const userId = "user_01"; // Sau này lấy từ Auth của bạn

    // Lưu vào Database thông qua Repository
    await _repository.toggleFavorite(userId, song.id);

    // Cập nhật trạng thái trực tiếp trên Model để UI thay đổi ngay lập tức
    song.isFavorite = !song.isFavorite;

    notifyListeners();
  }
  List<Map<String, dynamic>> _playlists = [];
  List<Map<String, dynamic>> get playlists => _playlists;

  // Tải danh sách Playlist của người dùng
  Future<void> loadUserPlaylists() async {
    const userId = "user_01"; // Sau này lấy từ Auth
    _playlists = await _repository.getUserPlaylists(userId);
    notifyListeners();
  }

  // Tạo một Playlist mới
  Future<void> createNewPlaylist(String title) async {
    const userId = "user_01";
    await _repository.createPlaylist(title, userId);
    await loadUserPlaylists(); // Tải lại danh sách sau khi tạo
  }

  // Thêm bài hát vào Playlist
  Future<void> addSongToPlaylist(int playlistId, String songId) async {
    await _repository.addSongToPlaylist(playlistId, songId);
  }
  // hàm thêm nhạc vào playlist
  Future<void> addToPlaylist(int playlistId, String songId) async {
    await _repository.addSongToPlaylist(playlistId, songId);
    // Có thể thêm thông báo "Đã thêm vào danh sách" ở đây
  }
  // Hàm đổi tên danh sách phát
  Future<void> renamePlaylist(String playlistId, String newName) async {
    // Gọi hàm từ repository của bạn ở đây (nếu bạn có lưu database)
    // Ví dụ: await repository.renamePlaylist(playlistId, newName);

    // Tạm thời trên UI, nếu danh sách playlist là biến nội bộ:
    for (var playlist in playlists) {
      if (playlist['id'] == playlistId) {
        playlist['title'] = newName;
        break;
      }
    }
    notifyListeners(); // Báo cho UI load lại tên mới
  }
}