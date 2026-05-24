import 'package:flutter/material.dart';
import '../../data/firebase_service.dart';

class AdminUserStatsScreen extends StatelessWidget {
  const AdminUserStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê người dùng', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
      ),
    );
  }
}
