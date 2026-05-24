import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/firebase_service.dart';
import '../../data/model/song.dart';
import '../now_playing/playing.dart';

class HistoryTab extends StatefulWidget {
  final String userId;
  const HistoryTab({super.key, required this.userId});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await FirebaseService.instance.getPlayHistory(widget.userId);
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  void _onSongTap(Map<String, dynamic> songData) {
    Song selectedSong = Song(
      id: songData['id']?.toString() ?? '',
      title: songData['title']?.toString() ?? 'Unknown',
      album: songData['album']?.toString() ?? 'Unknown',
      artist: songData['artist']?.toString() ?? 'Unknown',
      source: songData['source']?.toString() ?? '',
      image: songData['image']?.toString() ?? '',
      duration: int.tryParse(songData['duration']?.toString() ?? '0') ?? 0,
    );

    List<Song> playlist = _history.map((data) => Song(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? 'Unknown',
      album: data['album']?.toString() ?? 'History',
      artist: data['artist']?.toString() ?? 'Unknown',
      source: data['source']?.toString() ?? '',
      image: data['image']?.toString() ?? '',
      duration: int.tryParse(data['duration']?.toString() ?? '0') ?? 0,
    )).toList();

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => NowPlaying(songs: playlist, playingSong: selectedSong),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử nghe nhạc', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
        ],
      ),
      body: _history.isEmpty
          ? const Center(child: Text('Bạn chưa nghe bài hát nào.'))
          : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final song = _history[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      song['image'] ?? '',
                      width: 50, height: 50, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
                    ),
                  ),
                  title: Text(song['title'] ?? 'Unknown'),
                  subtitle: Text(song['artist'] ?? 'Unknown'),
                  onTap: () => _onSongTap(song),
                );
              },
            ),
    );
  }
}
