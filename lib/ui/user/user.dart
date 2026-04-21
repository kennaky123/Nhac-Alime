import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/reponsitory/music_repository_impl.dart';
import '../../main.dart'; // ĐẢM BẢO IMPORT ĐÚNG FILE CHỨA CLASS MusicApp
import 'playlist_detail.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  final _repository = MusicRepositoryImpl();
  List<Map<String, dynamic>> _playlists = [];
  bool _isLoading = true;

  // Biến lưu thông tin người dùng
  String _userName = "Người Dùng";
  File? _avatarImage;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
    _loadUserData(); // Tải tên và ảnh đã lưu
  }

  // --- LOGIC NGƯỜI DÙNG (ẢNH & TÊN) ---
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('username') ?? "Người Dùng";
      String? imagePath = prefs.getString('avatar_path');
      if (imagePath != null && imagePath.isNotEmpty) {
        _avatarImage = File(imagePath);
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatar_path', pickedFile.path);
      setState(() {
        _avatarImage = File(pickedFile.path);
      });
    }
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên người dùng'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('username', controller.text);
                setState(() => _userName = controller.text);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  // --- LOGIC PLAYLIST ---
  Future<void> _loadPlaylists() async {
    const userId = "user_01";
    final data = await _repository.getUserPlaylists(userId);
    setState(() {
      // SỬA TẠI ĐÂY: Chuyển toàn bộ dữ liệu từ DB sang Map có thể chỉnh sửa (Mutable)
      _playlists = data.map((item) => Map<String, dynamic>.from(item)).toList();
      _isLoading = false;
    });
  }

  // HÀM ĐỔI TÊN PLAYLIST: Đã sửa để tránh lỗi Read-only
  void _showRenamePlaylistDialog(int playlistId, String currentTitle, int index) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên danh sách phát'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                // 1. Cập nhật vào Database thực tế
                await _repository.updatePlaylist(playlistId, controller.text);

                // 2. Cập nhật UI: Vì ở trên đã dùng Map.from nên ở đây sửa trực tiếp được
                setState(() {
                  _playlists[index]['title'] = controller.text;
                });

                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Đổi tên'),
          ),
        ],
      ),
    );
  }

  // HÀM ĐĂNG XUẤT: Thoát hoàn toàn về màn hình chính
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn thoát không?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')
          ),
          ElevatedButton(
            onPressed: () async {
              // Dùng rootNavigator: true để che khuất thanh TabBar khi quay về màn hình chính
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MusicApp()),
                    (route) => false, // Xóa toàn bộ lịch sử các trang trước đó
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Thoát', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlaylist(int playlistId, int index) async {
    await _repository.deletePlaylist(playlistId);
    setState(() {
      _playlists.removeAt(index);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _playlists.removeAt(oldIndex);
      _playlists.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ của tôi'),
        actions: [
          // SỬA TẠI ĐÂY: Gọi hàm _showLogoutDialog thay vì chỉ Navigator.pop
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _showLogoutDialog
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // PHẦN HEADER: Ảnh đại diện và tên người dùng
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: _avatarImage != null ? FileImage(_avatarImage!) : null,
                        child: _avatarImage == null ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
                      ),
                      Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          )
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(_userName,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                          ),
                          IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: _showEditNameDialog),
                        ],
                      ),
                      const Text('Người yêu nhạc', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              ],
            ),
          ),
          const Divider(),

          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Danh sách phát của bạn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),

          Expanded(
            child: _playlists.isEmpty
                ? const Center(child: Text('Chưa có danh sách phát nào.'))
                : ReorderableListView.builder(
              onReorder: _onReorder,
              itemCount: _playlists.length,
              itemBuilder: (context, index) {
                final playlist = _playlists[index];
                return Dismissible(
                  key: ValueKey(playlist['id']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) => _deletePlaylist(playlist['id'], index),
                  child: ListTile(
                    leading: const Icon(Icons.album, color: Colors.deepPurple),
                    title: Text(playlist['title']),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PlaylistDetailScreen(
                        playlistId: playlist['id'],
                        playlistTitle: playlist['title'],
                      )));
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.blue),
                          onPressed: () => _showRenamePlaylistDialog(playlist['id'], playlist['title'], index),
                        ),
                        const Icon(Icons.drag_handle, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}