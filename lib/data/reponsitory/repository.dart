import '../model/song.dart';

abstract class Repository {
  // Lấy toàn bộ bài hát (Lọc theo quyền Premium của User)
  Future<List<Song>> fetchSongs(String userId);

  // --- Các hàm tương tác với Firebase ---
  Future<String> createPlaylist(String title, String userId);
  Future<List<String>> getFavoriteSongIds(String userId);
  Future<void> toggleFavorite(String userId, String songId);
  Future<List<Map<String, dynamic>>> getUserPlaylists(String userId);
  Future<void> addSongToPlaylist(String playlistId, String songId);
  Future<void> deletePlaylist(String playlistId);
  Future<List<String>> getSongIdsFromPlaylist(String playlistId);
  Future<void> updatePlaylist(String id, String newTitle);

  Future<List<Map<String, dynamic>>> getRecommendedSongs(String userId);
  Future<List<Map<String, dynamic>>> getTrendingSongs(String userId);

  // --- Collaborative Playlists ---
  Future<void> toggleCollaborative(String playlistId, bool isCollaborative);
  Future<void> addCollaboratorByEmail(String playlistId, String email);
  Future<List<Map<String, dynamic>>> getCollaborators(String playlistId);
  Future<List<Map<String, dynamic>>> getNotifications(String userId);
  Future<void> respondToInvitation(String notificationId, bool accept);
  Future<void> deleteNotification(String notificationId);
  Future<List<Map<String, dynamic>>> getPlayHistory(String userId);
}
