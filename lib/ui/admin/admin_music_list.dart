import 'package:flutter/material.dart';
import '../../data/firebase_service.dart';

class AdminMusicListScreen extends StatefulWidget {
  const AdminMusicListScreen({super.key});

  @override
  State<AdminMusicListScreen> createState() => _AdminMusicListScreenState();
}

class _AdminMusicListScreenState extends State<AdminMusicListScreen> {
  final _fb = FirebaseService.instance;
  List<Map<String, dynamic>> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    final data = await _fb.getAllSongs();
    setState(() {
      _songs = data;
      _isLoading = false;
    });
  }

  void _showSongDialog({Map<String, dynamic>? song}) {
    final titleController = TextEditingController(text: song?['title'] ?? '');
    final artistController = TextEditingController(text: song?['artist'] ?? '');
    final albumController = TextEditingController(text: song?['album'] ?? '');
    final imageController = TextEditingController(text: song?['image'] ?? '');
    final sourceController = TextEditingController(text: song?['source'] ?? '');
    final durationController = TextEditingController(text: song?['duration']?.toString() ?? '240');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(song == null ? 'Add New Song' : 'Edit Song'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: artistController, decoration: const InputDecoration(labelText: 'Artist')),
              TextField(controller: albumController, decoration: const InputDecoration(labelText: 'Album')),
              TextField(controller: imageController, decoration: const InputDecoration(labelText: 'Image URL')),
              TextField(controller: sourceController, decoration: const InputDecoration(labelText: 'Source URL (Lossless)')),
              TextField(controller: durationController, decoration: const InputDecoration(labelText: 'Duration (seconds)'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'title': titleController.text,
                'artist': artistController.text,
                'album': albumController.text,
                'image': imageController.text,
                'source': sourceController.text,
                'duration': int.tryParse(durationController.text) ?? 240,
              };

              if (song == null) {
                await _fb.addSong(data);
              } else {
                await _fb.updateSong(song['id'], data);
              }
              if (mounted) {
                Navigator.pop(context);
                _loadSongs();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSong(String id) async {
    await _fb.deleteSong(id);
    _loadSongs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSongDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final song = _songs[index];
                return ListTile(
                  leading: song['image'] != null && song['image'].isNotEmpty
                      ? Image.network(song['image'], width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note))
                      : const Icon(Icons.music_note),
                  title: Text(song['title']),
                  subtitle: Text(song['artist']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showSongDialog(song: song)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteSong(song['id'])),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
