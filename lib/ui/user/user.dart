import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/reponsitory/music_repository_impl.dart';
import '../../main.dart'; // ĐẢM BẢO IMPORT ĐÚNG FILE CHỨA CLASS MusicApp
import '../setting/premium_screen.dart';
import 'playlist_detail.dart';

class AccountTab extends StatefulWidget {
  final String userId;
  const AccountTab({super.key, required this.userId});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  final _repository = MusicRepositoryImpl();
  List<Map<String, dynamic>> _playlists = [];
  bool _isLoading = true;

  // Biến lưu thông tin người dùng
  String _userName = "Đang tải...";
  File? _avatarImage;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
    _loadUserData(); // Tải dữ liệu từ Firestore
  }

  // --- LOGIC NGƯỜI DÙNG (ẢNH & TÊN TỪ FIRESTORE) ---
  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _userName = userDoc.get('username') ?? "Người Dùng";
          // Ảnh đại diện vẫn có thể dùng SharedPreferences hoặc Firestore tùy bạn, 
          // hiện tại tôi giữ logic cũ cho ảnh hoặc bạn có thể nâng cấp sau.
        });
      }
    } catch (e) {
      if (mounted) setState(() => _userName = "Người Dùng");
    }
    
    // Tải ảnh đại diện cục bộ (nếu có)
    final prefs = await SharedPreferences.getInstance();
    String? imagePath = prefs.getString('avatar_path');
    if (imagePath != null && imagePath.isNotEmpty && mounted) {
      setState(() {
        _avatarImage = File(imagePath);
      });
    }
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
                // Cập nhật tên lên Firestore
                await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
                  'username': controller.text,
                });
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
    final data = await _repository.getUserPlaylists(widget.userId);
    setState(() {
      // SỬA TẠI ĐÂY: Chuyển toàn bộ dữ liệu từ DB sang Map có thể chỉnh sửa (Mutable)
      _playlists = data.map((item) => Map<String, dynamic>.from(item)).toList();
      _isLoading = false;
    });
  }

  // HÀM ĐỔI TÊN PLAYLIST: Đã sửa để tránh lỗi Read-only
  void _showRenamePlaylistDialog(String playlistId, String currentTitle, int index) {
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

  Future<void> _deletePlaylist(String id, int index) async {
    await _repository.deletePlaylist(id);
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
          // NÚT ĐĂNG KÝ PREMIUM
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PremiumScreen(userId: widget.userId)),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.orange, Colors.amber]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.stars, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Đăng ký Music Premium',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
              ),
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
                  onDismissed: (direction) => _deletePlaylist(playlist['id'].toString(), index),
                  child: ListTile(
                    leading: const Icon(Icons.album, color: Colors.deepPurple),
                    title: Text(playlist['title']),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PlaylistDetailScreen(
                        playlistId: playlist['id'].toString(),
                        playlistTitle: playlist['title'],
                        userId: widget.userId,
                      )));
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.blue),
                          onPressed: () => _showRenamePlaylistDialog(playlist['id'].toString(), playlist['title'], index),
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