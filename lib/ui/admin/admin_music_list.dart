import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../data/firebase_service.dart';
import '../../data/youtube_service.dart';

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
    final youtubeController = TextEditingController();

    bool isFetching = false;
    bool isUploadingImage = false;
    bool isUploadingMusic = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(song == null ? 'Add New Song' : 'Edit Song'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (song == null) ...[
                  const Text('Option 1: Import from YouTube', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: youtubeController,
                          decoration: const InputDecoration(
                            labelText: 'YouTube URL',
                            hintText: 'Dán link để lấy thông tin...',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: isFetching 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.download_rounded, color: Colors.red),
                        onPressed: isFetching ? null : () async {
                          if (youtubeController.text.isNotEmpty) {
                            setDialogState(() => isFetching = true);
                            final details = await YouTubeService.instance.getVideoDetails(youtubeController.text);
                            if (details != null) {
                              String title = details['title'];
                              String artist = details['artist'];
                              if (title.contains(' - ')) {
                                final parts = title.split(' - ');
                                artist = parts[0].trim();
                                title = parts[1].split('(')[0].split('[')[0].trim();
                              }
                              titleController.text = title;
                              artistController.text = artist;
                              imageController.text = details['image'];
                              sourceController.text = details['source'];
                              durationController.text = details['duration'].toString();
                            }
                            if (context.mounted) {
                              setDialogState(() => isFetching = false);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text('Option 2: Direct Upload to Firebase', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: isUploadingMusic ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.music_note),
                        label: const Text('Music'),
                        onPressed: isUploadingMusic ? null : () async {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
                          if (result != null) {
                            setDialogState(() => isUploadingMusic = true);
                            File file = File(result.files.single.path!);
                            String url = await _fb.uploadFile(file, 'music');
                            sourceController.text = url;
                            setDialogState(() => isUploadingMusic = false);
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        icon: isUploadingImage ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.image),
                        label: const Text('Image'),
                        onPressed: isUploadingImage ? null : () async {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                          if (result != null) {
                            setDialogState(() => isUploadingImage = true);
                            File file = File(result.files.single.path!);
                            String url = await _fb.uploadFile(file, 'thumbnails');
                            imageController.text = url;
                            setDialogState(() => isUploadingImage = false);
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                ],
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: artistController, decoration: const InputDecoration(labelText: 'Artist')),
                TextField(controller: albumController, decoration: const InputDecoration(labelText: 'Album')),
                TextField(controller: imageController, decoration: const InputDecoration(labelText: 'Image URL/Path')),
                TextField(controller: sourceController, decoration: const InputDecoration(labelText: 'Source URL/Path')),
                TextField(controller: durationController, decoration: const InputDecoration(labelText: 'Duration (seconds)'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: (isUploadingImage || isUploadingMusic) ? null : () async {
                final data = {
                  'title': titleController.text.trim(),
                  'artist': artistController.text.trim(),
                  'album': albumController.text.trim(),
                  'image': imageController.text.trim(),
                  'source': sourceController.text.trim(),
                  'duration': int.tryParse(durationController.text) ?? 240,
                };

                if (song == null) {
                  await _fb.addSong(data);
                } else {
                  await _fb.updateSong(song['id'], data);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadSongs();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
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
