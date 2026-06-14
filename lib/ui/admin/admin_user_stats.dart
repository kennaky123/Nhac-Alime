import 'package:flutter/material.dart';
import '../../data/firebase_service.dart';

class AdminUserStatsScreen extends StatelessWidget {
  const AdminUserStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thống kê', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Người dùng', icon: Icon(Icons.people)),
              Tab(text: 'Bài hát', icon: Icon(Icons.music_note)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UserStatsList(),
            _GlobalSongStatsList(),
          ],
        ),
      ),
    );
  }
}

class _UserStatsList extends StatelessWidget {
  const _UserStatsList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FirebaseService.instance.getAllUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final users = snapshot.data!;
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ExpansionTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user['username'] ?? 'No Name'),
              subtitle: Text(user['email'] ?? ''),
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: FirebaseService.instance.getUserStats(user['uid']),
                  builder: (context, statsSnapshot) {
                    if (!statsSnapshot.hasData) return const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator());
                    final stats = statsSnapshot.data!;
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tổng lượt nghe: ${stats['total_plays']}'),
                          const SizedBox(height: 8),
                          const Text('Top bài hát:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ...(stats['top_songs'] as List).map((songName) => Text('- $songName')),
                        ],
                      ),
                    );
                  },
                )
              ],
            );
          },
        );
      },
    );
  }
}

class _GlobalSongStatsList extends StatelessWidget {
  const _GlobalSongStatsList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FirebaseService.instance.getGlobalTopSongs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final songs = snapshot.data!;
        if (songs.isEmpty) return const Center(child: Text('Chưa có dữ liệu lượt nghe'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: song['image'] != null
                      ? Image.network(song['image'], width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note))
                      : const Icon(Icons.music_note, size: 50),
                ),
                title: Text(song['title'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(song['artist'] ?? 'Unknown Artist'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${song['play_count']} lượt nghe',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
