import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/firebase_service.dart';
import '../../data/reponsitory/music_repository_impl.dart';
import '../../data/playlist_event_bus.dart';
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
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  StreamSubscription? _playlistSubscription;

  // Biến lưu thông tin người dùng
  String _userName = "Đang tải...";
  File? _avatarImage;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
    _loadUserData(); // Tải dữ liệu từ Firestore
    _loadNotifications();
    _playlistSubscription = PlaylistEventBus().onPlaylistChanged.listen((_) {
      _loadPlaylists();
    });
  }

  Future<void> _loadNotifications() async {
    final notifs = await _repository.getNotifications(widget.userId);
    if (mounted) {
      setState(() {
        _notifications = notifs;
      });
    }
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thông báo'),
          content: SizedBox(
            width: double.maxFinite,
            child: _notifications.isEmpty
                ? const Center(child: Text('Không có thông báo nào'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      if (notif['type'] == 'playlist_invitation') {
                        return _buildInvitationTile(notif, setDialogState);
                      } else if (notif['type'] == 'new_premium_song') {
                        return _buildPremiumSongTile(notif, setDialogState);
                      } else if (notif['type'] == 'friend_request') {
                        return _buildFriendRequestTile(notif, setDialogState);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendRequestTile(Map<String, dynamic> notif, StateSetter setDialogState) {
    bool isPending = notif['status'] == 'pending';
    return ListTile(
      leading: const Icon(Icons.person_add, color: Colors.blue),
      title: Text('${notif['sender_name']} muốn kết bạn'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPending) ...[
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () async {
                await FirebaseService.instance.respondToFriendRequest(notif['id'], true);
                await _loadNotifications();
                setDialogState(() {});
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () async {
                await FirebaseService.instance.respondToFriendRequest(notif['id'], false);
                await _loadNotifications();
                setDialogState(() {});
              },
            ),
          ] else ...[
            Text(notif['status'] == 'accepted' ? 'Đã chấp nhận' : 'Đã từ chối',
                style: TextStyle(color: notif['status'] == 'accepted' ? Colors.green : Colors.red, fontSize: 12)),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () async {
                await _repository.deleteNotification(notif['id']);
                await _loadNotifications();
                setDialogState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvitationTile(Map<String, dynamic> notif, StateSetter setDialogState) {
    bool isPending = notif['status'] == 'pending';
    return ListTile(
      title: Text('${notif['sender_name']} mời bạn cộng tác'),
      subtitle: Text('Playlist: ${notif['playlist_title']}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPending) ...[
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () async {
                await _repository.respondToInvitation(notif['id'], true);
                await _loadNotifications();
                await _loadPlaylists();
                setDialogState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () async {
                await _repository.respondToInvitation(notif['id'], false);
                await _loadNotifications();
                setDialogState(() {});
              },
            ),
          ] else ...[
            Text(notif['status'] == 'accepted' ? 'Đã chấp nhận' : 'Đã từ chối',
                style: TextStyle(color: notif['status'] == 'accepted' ? Colors.green : Colors.red, fontSize: 12)),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () async {
                await _repository.deleteNotification(notif['id']);
                await _loadNotifications();
                setDialogState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumSongTile(Map<String, dynamic> notif, StateSetter setDialogState) {
    return ListTile(
      leading: const Icon(Icons.stars, color: Colors.amber),
      title: const Text('Nhạc Premium mới!'),
      subtitle: Text('Bài hát "${notif['song_title']}" vừa được thêm.'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.grey),
        onPressed: () async {
          await _repository.deleteNotification(notif['id']);
          await _loadNotifications();
          setDialogState(() {});
        },
      ),
      onTap: () {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
    );
  }

  @override
  void dispose() {
    _playlistSubscription?.cancel();
    super.dispose();
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

  void _showAddFriendDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gửi lời mời kết bạn'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nhập email người muốn kết bạn...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseService.instance.sendFriendRequest(widget.userId, controller.text);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi lời mời kết bạn!')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }

  void _showFriendListDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Danh sách bạn bè'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: FirebaseService.instance.getFriendList(widget.userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final friends = snapshot.data!;
                if (friends.isEmpty) return const Center(child: Text('Chưa có bạn bè nào.'));
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(friend['username'] ?? 'No Name'),
                      subtitle: Text(friend['email'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_remove, color: Colors.red),
                        onPressed: () async {
                          await FirebaseService.instance.unfriend(widget.userId, friend['uid']);
                          setDialogState(() {});
                          setState(() {}); // Reload main screen
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          ],
        ),
      ),
    );
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

                PlaylistEventBus().notifyPlaylistChanged();

                if (context.mounted) Navigator.pop(context);
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
    PlaylistEventBus().notifyPlaylistChanged();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _playlists.removeAt(oldIndex);
      _playlists.insert(newIndex, item);
    });
  }

  Widget _buildFriendsFeedSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _showFriendListDialog,
                child: const Row(
                  children: [
                    Text('Bạn bè', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.list_alt, size: 20, color: Colors.blue),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _showAddFriendDialog,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Thêm bạn'),
              ),
            ],
          ),
        ),
        ExpansionTile(
          leading: const Icon(Icons.people_outline, color: Colors.blue),
          title: const Text('Bạn bè của bạn vừa nghe gì', style: TextStyle(fontWeight: FontWeight.bold)),
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: FirebaseService.instance.getSocialFeed(widget.userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final friendsActivity = snapshot.data!;
                if (friendsActivity.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('Chưa có hoạt động nào từ bạn bè.'));
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: friendsActivity.length,
                  itemBuilder: (context, index) {
                    final friend = friendsActivity[index];
                    final recentSongs = friend['recent_songs'] as List;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person, size: 20)),
                          title: Text(friend['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('3 bài hát gần nhất:'),
                        ),
                        ...recentSongs.map((song) => Padding(
                          padding: const EdgeInsets.only(left: 72, bottom: 8, right: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.music_note, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${song['title']} - ${song['artist']}',
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatTimestamp(song['timestamp']),
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        )),
                        const Divider(indent: 72),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
        ExpansionTile(
          leading: const Icon(Icons.trending_up, color: Colors.orange),
          title: const Text('Bài hát bạn bè nghe nhiều nhất', style: TextStyle(fontWeight: FontWeight.bold)),
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: FirebaseService.instance.getFriendsTopSongs(widget.userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final topSongs = snapshot.data!;
                if (topSongs.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('Chưa có dữ liệu bài hát.'));
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topSongs.length,
                  itemBuilder: (context, index) {
                    final song = topSongs[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(song['image'] ?? '', width: 40, height: 40, fit: BoxFit.cover),
                      ),
                      title: Text(song['title'] ?? 'Unknown'),
                      subtitle: Text('${song['artist']} - ${song['play_count']} lượt nghe'),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.hour}:${date.minute}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    int unreadCount = _notifications.where((n) => n['status'] == 'pending' || n['status'] == 'unread').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ của tôi'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: _showNotificationsDialog,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _showLogoutDialog
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
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

                  // PHẦN BẢNG TIN (BẠN BÈ)
                  _buildFriendsFeedSection(),

                  const Divider(),

                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Danh sách phát của bạn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // SỬ DỤNG LISTVIEW BUILDER TRONG COLUMN (PHẢI CÓ shrinkWrap: true VÀ NeverScrollableScrollPhysics)
                  _playlists.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: Text('Chưa có danh sách phát nào.')),
                        )
                      : ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
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
                                leading: Stack(
                                  children: [
                                    const Icon(Icons.album, color: Colors.deepPurple),
                                    if (playlist['is_collaborative'] == true)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(1),
                                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                          child: const Icon(Icons.group, size: 10, color: Colors.deepPurple),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(playlist['title']),
                                subtitle: playlist['is_owner'] == false ? const Text('Được chia sẻ với bạn', style: TextStyle(fontSize: 12)) : null,
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
                  const SizedBox(height: 100), // Khoảng trống cho Mini Player nếu cần
                ],
              ),
            ),
    );

  }
}