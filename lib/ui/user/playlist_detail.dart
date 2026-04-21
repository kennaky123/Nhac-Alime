import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/model/song.dart';
import '../../data/reponsitory/music_repository_impl.dart';
import '../now_playing/playing.dart'; // Import màn hình phát nhạc vào đây

class PlaylistDetailScreen extends StatefulWidget {
  final int playlistId;
  final String playlistTitle;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistTitle
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final _repository = MusicRepositoryImpl();
  List<Song> _playlistSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongsForPlaylist();
  }

  // Tải các bài hát thuộc Playlist này
  Future<void> _loadSongsForPlaylist() async {
    final songIds = await _repository.getSongIdsFromPlaylist(widget.playlistId);
    final allSongs = await _repository.fetchSongs();

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
      ),

      // THÊM NÚT "PHÁT TẤT CẢ" Ở ĐÂY
      floatingActionButton: _playlistSongs.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: () {
          // Nhấn phát tất cả -> Chọn bài đầu tiên trong list làm bài đang phát
          _playMusic(_playlistSongs.first);
        },
        icon: const Icon(Icons.play_arrow, size: 30),
        label: const Text('Phát tất cả', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      )
          : null, // Nếu playlist trống thì ẩn nút đi

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlistSongs.isEmpty
          ? const Center(child: Text('Danh sách phát này chưa có bài hát nào.'))
          : ReorderableListView.builder(
        onReorder: _onReorder,
        itemCount: _playlistSongs.length,
        padding: const EdgeInsets.only(bottom: 80), // Cách đáy một khoảng để không bị nút Play che mất
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
}