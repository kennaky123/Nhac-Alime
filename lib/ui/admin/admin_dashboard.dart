import 'package:flutter/material.dart';
import '../../data/firebase_service.dart';
import '../../data/source/source.dart';
import '../user/login.dart';
import 'admin_music_list.dart';
import 'admin_user_manager.dart';
import 'admin_coupon_manager.dart';
import 'admin_approval_screen.dart';
import 'admin_user_stats.dart';
import 'admin_chat_list_screen.dart';
import 'admin_sales_stats_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseService.instance.logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(colorScheme),
            const SizedBox(height: 32),
            _buildStatsSection(colorScheme),
            const SizedBox(height: 32),
            const Text(
              'Management',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildManagementGrid(context, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 35),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, Admin',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                'System Control Center',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(ColorScheme colorScheme) {
    return FutureBuilder<List<int>>(
      future: Future.wait([
        FirebaseService.instance.getAllUsers().then((v) => v.length),
        Future(() async {
          // 1. Lấy nhạc từ API (RemoteDataSource)
          final apiSongs = await RemoteDataSource().loadData();
          final apiCount = apiSongs?.length ?? 0;
          
          // 2. Lấy nhạc từ Firestore (Premium/Admin songs)
          final firestoreSongs = await FirebaseService.instance.getAllSongs();
          final firestoreCount = firestoreSongs.length;
          
          return apiCount + firestoreCount;
        }),
      ]),
      builder: (context, snapshot) {
        String userCount = '...';
        String songCount = '...';
        
        if (snapshot.connectionState == ConnectionState.waiting) {
           return Row(
            children: [
              _buildStatCard('Users', '...', Icons.people, Colors.blue),
              const SizedBox(width: 16),
              _buildStatCard('Songs', '...', Icons.music_note, Colors.orange),
            ],
          );
        }

        if (snapshot.hasData) {
          userCount = snapshot.data![0].toString();
          songCount = snapshot.data![1].toString();
        }

        return Row(
          children: [
            _buildStatCard('Users', userCount, Icons.people, Colors.blue),
            const SizedBox(width: 16),
            _buildStatCard('Songs', songCount, Icons.music_note, Colors.orange),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: $count',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildManagementGrid(BuildContext context, ColorScheme colorScheme) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildMenuCard(
          context,
          'Music Library',
          'Manage all tracks',
          Icons.library_music,
          Colors.purple,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminMusicListScreen())),
        ),
        _buildMenuCard(
          context,
          'User Management',
          'Permissions & Roles',
          Icons.manage_accounts,
          Colors.green,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUserManagerScreen())),
        ),
        _buildMenuCard(
          context,
          'Coupon Manager',
          'Create & Track Codes',
          Icons.confirmation_number,
          Colors.orange,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCouponManagerScreen())),
        ),
        _buildMenuCard(
          context,
          'Premium Approvals',
          'Approve Requests',
          Icons.verified_user,
          Colors.blue,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalScreen())),
        ),
        _buildMenuCard(
          context,
          'User Statistics',
          'View user activity',
          Icons.analytics,
          Colors.indigo,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUserStatsScreen())),
        ),
        _buildMenuCard(
          context,
          'Sales Analytics',
          'Premium Conversion',
          Icons.bar_chart_rounded,
          Colors.amber,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSalesStatsScreen())),
        ),
        _buildMenuCard(
          context,
          'Support Chats',
          'Chat with Users',
          Icons.chat,
          Colors.teal,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminChatListScreen())),
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
