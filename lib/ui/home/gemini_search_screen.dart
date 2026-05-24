import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../data/firebase_service.dart';
import '../../data/gemini_service.dart';
import '../../data/youtube_service.dart';
import '../../data/model/song.dart';
import '../now_playing/playing.dart';
import '../../data/playlist_event_bus.dart';

class GeminiSearchScreen extends StatefulWidget {
  final List<Song> allSongs;
  const GeminiSearchScreen({super.key, required this.allSongs});

  @override
  State<GeminiSearchScreen> createState() => _GeminiSearchScreenState();
}

class _GeminiSearchScreenState extends State<GeminiSearchScreen> {
  final _controller = TextEditingController();
  List<Song> _results = [];
  bool _isSearching = false;
  String? _geminiReason;
  bool _isPlaylistCreation = false;

  Future<void> _handleSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _geminiReason = null;
      _results = [];
      _isPlaylistCreation = false;
    });

    try {
      String finalQuery = query;
      
      // KIỂM TRA NẾU LÀ LINK YOUTUBE THÌ TRÍCH XUẤT TIÊU ĐỀ TRƯỚC
      if (query.contains('youtube.com/') || query.contains('youtu.be/')) {
        final videoTitle = await YouTubeService.instance.getVideoTitle(query);
        if (videoTitle != null) {
          finalQuery = 'Video YouTube này có tiêu đề là "$videoTitle". Hãy xác định đây là bài hát nào.';
        }
      }

      final responseText = await GeminiService.instance.analyzeMusicQuery(finalQuery, widget.allSongs);
      if (responseText != null && mounted) {
        // Trích xuất JSON từ markdown nếu có
        String cleanJson = responseText;
        if (responseText.contains('```json')) {
          cleanJson = responseText.split('```json')[1].split('```')[0].trim();
        } else if (responseText.contains('```')) {
          cleanJson = responseText.split('```')[1].split('```')[0].trim();
        }

        final data = jsonDecode(cleanJson);
        final reason = data['reason'];
        final isPlaylist = data['is_playlist_creation'] ?? false;

        if (isPlaylist) {
          final List<dynamic> ids = data['playlist_ids'] ?? [];
          final List<Song> foundSongs = widget.allSongs.where((s) => ids.contains(s.id)).toList();
          setState(() {
            _results = foundSongs;
            _geminiReason = reason;
            _isPlaylistCreation = true;
          });
        } else {
          final matchedId = data['matched_song_id'];
          if (matchedId != null) {
            final matchedSong = widget.allSongs.firstWhere((s) => s.id == matchedId);
            setState(() {
              _results = [matchedSong];
              _geminiReason = reason;
            });
          } else {
            setState(() {
              _geminiReason = "Gemini xác định: ${data['identified_song']}. \n\nLý do: $reason \n\n(Tiếc là bài này chưa có trong thư viện của app)";
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString().contains('quota') ? 'Hết hạn mức API Gemini' : 'Không thể kết nối Gemini'}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _saveAsPlaylist() async {
    if (_results.isEmpty) return;
    
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final titleController = TextEditingController(text: 'AI Playlist: ${_controller.text}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lưu thành danh sách phát'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Tên danh sách'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final playlistId = await FirebaseService.instance.createPlaylist(titleController.text, userId);
              for (var song in _results) {
                await FirebaseService.instance.addSongToPlaylist(playlistId, song.id);
              }
              // Log activity cho Social Feed
              await FirebaseService.instance.logActivity(userId, 'create_playlist', 'vừa tạo một playlist AI "${titleController.text}"');
              
              PlaylistEventBus().notifyPlaylistChanged();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu playlist thành công!')));
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Music Assistant', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withValues(alpha: 0.05),
              colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dán link YouTube hoặc mô tả bài hát để Gemini tìm giúp bạn trong thư viện app.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'https://youtube.com/...',
                            prefixIcon: const Icon(Icons.link_rounded, color: Colors.blue),
                            filled: true,
                            fillColor: colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: colorScheme.outlineVariant),
                            ),
                          ),
                          onSubmitted: (_) => _handleSearch(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isSearching ? null : _handleSearch,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                          child: _isSearching 
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : const Icon(Icons.send_rounded),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_geminiReason != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.psychology_outlined, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _geminiReason!,
                          style: TextStyle(color: Colors.blue.shade900, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  if (_isPlaylistCreation && _results.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: ElevatedButton.icon(
                        onPressed: _saveAsPlaylist,
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: const Text('Lưu danh sách phát này'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, size: 48, color: Colors.blue.withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                const Text('Kết quả tìm thấy sẽ hiện ở đây', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final song = _results[index];
                              return _buildSongTile(song);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongTile(Song song) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            song.image,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
          ),
        ),
        title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(song.artist),
        trailing: const Icon(Icons.play_circle_fill, color: Colors.blue, size: 32),
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => NowPlaying(songs: [song], playingSong: song),
            ),
          );
        },
      ),
    );
  }
}
