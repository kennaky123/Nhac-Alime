import 'package:flutter/material.dart';
import '../../data/firebase_service.dart';

class AdminUserManagerScreen extends StatefulWidget {
  const AdminUserManagerScreen({super.key});

  @override
  State<AdminUserManagerScreen> createState() => _AdminUserManagerScreenState();
}

class _AdminUserManagerScreenState extends State<AdminUserManagerScreen> {
  final _fb = FirebaseService.instance;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final data = await _fb.getAllUsers();
    setState(() {
      _users = data;
      _isLoading = false;
    });
  }

  Future<void> _confirmDelete(String userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa người dùng "$username" khỏi hệ thống không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _fb.deleteUser(userId);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa người dùng thành công')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final bool isPremium = user['is_premium'] ?? false;
                final String role = user['role'] ?? 'user';

                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user['username'] ?? 'No name'),
                  subtitle: Text('${user['email']}\nRole: $role | Premium: ${isPremium ? "Yes" : "No"}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'toggle_premium') {
                        await _fb.updatePremiumStatus(user['uid'], !isPremium);
                        _loadUsers();
                      } else if (value == 'make_admin') {
                        await _fb.updateUserRole(user['uid'], 'admin');
                        _loadUsers();
                      } else if (value == 'make_user') {
                        await _fb.updateUserRole(user['uid'], 'user');
                        _loadUsers();
                      } else if (value == 'delete_user') {
                        _confirmDelete(user['uid'], user['username'] ?? 'No name');
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'toggle_premium', child: Text(isPremium ? 'Remove Premium' : 'Grant Premium')),
                      if (role == 'user') const PopupMenuItem(value: 'make_admin', child: Text('Make Admin')),
                      if (role == 'admin') const PopupMenuItem(value: 'make_user', child: Text('Revoke Admin')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete_user',
                        child: Text('Delete User', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
