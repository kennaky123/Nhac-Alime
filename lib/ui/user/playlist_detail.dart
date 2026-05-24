import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/model/song.dart';
import '../../data/reponsitory/music_repository_impl.dart';
import '../now_playing/playing.dart'; // Import màn hình phát nhạc vào đây

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final String playlistTitle;
  final String userId;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistTitle,
    required this.userId,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final _repository = MusicRepositoryImpl();
  List<Song> _playlistSongs = [];
  List<Map<String, dynamic>> _collaborators = [];
  bool _isLoading = true;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _checkOwnership();
    _loadSongsForPlaylist();
    _loadCollaborators();
  }

  Future<void> _checkOwnership() async {
    // Trong thực tế bạn có thể truyền biến isOwner từ màn hình trước, 
    // ở đây mình load lại từ DB để chính xác.
    final playlists = await _repository.getUserPlaylists(widget.userId);
    final current = playlists.firstWhere((p) => p['id'] == widget.playlistId, orElse: () => {});
    if (mounted) {
      setState(() {
        _isOwner = current['is_owner'] ?? false;
      });
    }
  }

  Future<void> _loadCollaborators() async {
    final collabs = await _repository.getCollaborators(widget.playlistId);
    if (mounted) {
      setState(() {
        _collaborators = collabs;
      });
    }
  }

  // Tải các bài hát thuộc Playlist này
  Future<void> _loadSongsForPlaylist() async {
    final songIds = await _repository.getSongIdsFromPlaylist(widget.playlistId);
    final allSongs = await _repository.fetchSongs(widget.userId);

    // Lọc ra những bài hát có trong playlist
    final filteredSongs = allSongs.where((song) => songIds.contains(song.id)).toList();

    setState(() {
      _playlistSongs = filteredSongs;
      _isLoading = false;
    });
  }

  // Hàm xử lý kéo thả để đổi vị trí
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _playlistSongs.removeAt(oldIndex);
      _playlistSongs.insert(newIndex, item);
    });
  }

  // HÀM ĐIỀU HƯỚNG SANG MÀN HÌNH PHÁT NHẠC
  void _playMusic(Song selectedSong) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => NowPlaying(
          songs: _playlistSongs, // Truyền nguyên danh sách hiện tại vào
          playingSong: selectedSong, // Truyền bài hát được chọn để phát luôn
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlistTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => _showCollaboratorsDialog(),
            tooltip: 'Cộng tác viên',
          ),
        ],
      ),

      // THÊM NÚT "PHÁT TẤT CẢ" Ở ĐÂY
      floatingActionButton: _playlistSongs.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 60), // Đẩy lên để không bị che bởi MiniPlayer/TabBar
              child: FloatingActionButton.extended(
                onPressed: () {
                  // Nhấn phát tất cả -> Chọn bài đầu tiên trong list làm bài đang phát
                  _playMusic(_playlistSongs.first);
                },
                icon: const Icon(Icons.play_arrow, size: 30),
                label: const Text('Phát tất cả', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            )
          : null, // Nếu playlist trống thì ẩn nút đi

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlistSongs.isEmpty
          ? const Center(child: Text('Danh sách phát này chưa có bài hát nào.'))
          : ReorderableListView.builder(
        onReorder: _onReorder,
        itemCount: _playlistSongs.length,
        padding: const EdgeInsets.only(bottom: 140), // Tăng khoảng trống ở dưới
        itemBuilder: (context, index) {
          final song = _playlistSongs[index];
          return ListTile(
            key: ValueKey(song.id),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FadeInImage.assetNetwork(
                placeholder: 'assets/apple-music-app-for-windows-icon.png',
                image: song.image,
                width: 48,
                height: 48,
                imageErrorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.music_note, size: 48);
                },
              ),
            ),
            title: Text(song.title),
            subtitle: Text(song.artist),
            trailing: const Icon(Icons.drag_handle, color: Colors.grey),

            // SỰ KIỆN: NHẤN BỪA 1 BÀI ĐỂ PHÁT
            onTap: () {
              _playMusic(song);
            },
          );
        },
      ),
    );
  }

  void _showCollaboratorsDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cộng tác viên'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isOwner) ...[
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Mời bạn bè qua Email',
                      hintText: 'example@gmail.com',
                      suffixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (emailController.text.isNotEmpty) {
                        try {
                          await _repository.addCollaboratorByEmail(widget.playlistId, emailController.text);
                          await _loadCollaborators();
                          emailController.clear();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã thêm người cộng tác!')),
                            );
                            setDialogState(() {}); // Update dialog list
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Mời'),
                  ),
                  const Divider(),
                ],
                const Text('Danh sách hiện tại:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (_collaborators.isEmpty)
                  const Text('Chưa có người cộng tác nào.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _collaborators.length,
                    itemBuilder: (context, index) {
                      final collab = _collaborators[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(collab['username'] ?? 'No Name'),
                        subtitle: Text(collab['email'] ?? ''),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          ],
        ),
      ),
    );
  }
}
