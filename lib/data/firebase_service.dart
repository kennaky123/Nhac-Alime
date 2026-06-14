import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._init();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  FirebaseService._init();

  // --- AUTHENTICATION ---

  Future<User?> signUp(String email, String password, String username, {String role = 'user'}) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // Lưu thông tin user vào Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'username': username,
          'email': email,
          'photo_url': '',
          'role': role,
          'is_premium': false,
        });
      }
      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // --- PLAYLISTS ---

  Future<String> createPlaylist(String title, String userId) async {
    DocumentReference docRef = await _firestore.collection('playlists').add({
      'title': title,
      'user_id': userId,
      'is_collaborative': false,
      'collaborators': [],
      'created_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updatePlaylist(String id, String newTitle) async {
    await _firestore.collection('playlists').doc(id).update({'title': newTitle});
  }

  Future<void> deletePlaylist(String playlistId) async {
    // Xóa playlist
    await _firestore.collection('playlists').doc(playlistId).delete();
    // Xóa các bài hát trong playlist đó (trong thực tế có thể dùng collection group hoặc subcollection)
    var songs = await _firestore
        .collection('playlist_songs')
        .where('playlist_id', isEqualTo: playlistId)
        .get();
    for (var doc in songs.docs) {
      await doc.reference.delete();
    }
  }

  Future<List<Map<String, dynamic>>> getUserPlaylists(String userId) async {
    // 1. Lấy playlist sở hữu
    QuerySnapshot ownedSnapshot = await _firestore
        .collection('playlists')
        .where('user_id', isEqualTo: userId)
        .get();
        
    // 2. Lấy playlist được mời cộng tác
    QuerySnapshot collabSnapshot = await _firestore
        .collection('playlists')
        .where('collaborators', arrayContains: userId)
        .get();

    List<Map<String, dynamic>> playlists = [];
    
    for (var doc in ownedSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      playlists.add({
        'id': doc.id,
        'title': data['title'],
        'user_id': data['user_id'],
        'is_collaborative': data['is_collaborative'] ?? false,
        'is_owner': true,
      });
    }

    for (var doc in collabSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      playlists.add({
        'id': doc.id,
        'title': data['title'],
        'user_id': data['user_id'],
        'is_collaborative': data['is_collaborative'] ?? false,
        'is_owner': false,
      });
    }

    return playlists;
  }

  Future<void> toggleCollaborative(String playlistId, bool isCollaborative) async {
    await _firestore.collection('playlists').doc(playlistId).update({
      'is_collaborative': isCollaborative,
    });
  }

  Future<void> addCollaboratorByEmail(String playlistId, String email) async {
    // 1. Tìm User UID theo email
    QuerySnapshot userSearch = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (userSearch.docs.isEmpty) {
      throw Exception('Không tìm thấy người dùng với email này!');
    }

    String collaboratorId = userSearch.docs.first.id;
    String senderId = _auth.currentUser?.uid ?? '';
    
    // Lấy thông tin playlist và người gửi
    DocumentSnapshot playlistDoc = await _firestore.collection('playlists').doc(playlistId).get();
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(senderId).get();
    
    String playlistTitle = playlistDoc.get('title') ?? 'Playlist';
    String senderName = userDoc.get('username') ?? 'Ai đó';

    // 2. Tạo một thông báo mời thay vì add trực tiếp
    await _firestore.collection('notifications').add({
      'type': 'playlist_invitation',
      'receiver_id': collaboratorId,
      'sender_id': senderId,
      'sender_name': senderName,
      'playlist_id': playlistId,
      'playlist_title': playlistTitle,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    // Sửa lỗi Index: Tạm thời bỏ orderBy để không yêu cầu Index phức tạp
    // Bạn có thể sắp xếp thủ công ở phía Client nếu muốn giữ thứ tự.
    QuerySnapshot snapshot = await _firestore
        .collection('notifications')
        .where('receiver_id', isEqualTo: userId)
        .get();
    
    var list = snapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();

    // Sắp xếp thủ công theo timestamp (giảm dần)
    list.sort((a, b) {
      Timestamp? tA = a['timestamp'] as Timestamp?;
      Timestamp? tB = b['timestamp'] as Timestamp?;
      if (tA == null || tB == null) return 0;
      return tB.compareTo(tA);
    });

    return list;
  }

  Future<void> respondToInvitation(String notificationId, bool accept) async {
    DocumentReference notifRef = _firestore.collection('notifications').doc(notificationId);
    DocumentSnapshot notifDoc = await notifRef.get();
    
    if (!notifDoc.exists) return;
    
    if (accept) {
      String playlistId = notifDoc.get('playlist_id');
      String receiverId = notifDoc.get('receiver_id');
      
      // Thêm UID vào mảng collaborators
      await _firestore.collection('playlists').doc(playlistId).update({
        'collaborators': FieldValue.arrayUnion([receiverId]),
        'is_collaborative': true,
      });
      
      await notifRef.update({'status': 'accepted'});
    } else {
      await notifRef.update({'status': 'rejected'});
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  Future<List<Map<String, dynamic>>> getCollaborators(String playlistId) async {
    DocumentSnapshot playlistDoc = await _firestore.collection('playlists').doc(playlistId).get();
    if (!playlistDoc.exists) return [];
    
    List collaborators = playlistDoc.get('collaborators') ?? [];
    if (collaborators.isEmpty) return [];

    List<Map<String, dynamic>> result = [];
    for (String uid in collaborators) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        result.add({
          'uid': uid,
          'username': userDoc.get('username'),
          'email': userDoc.get('email'),
        });
      }
    }
    return result;
  }

  // --- PLAYLIST SONGS ---

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    await _firestore.collection('playlist_songs').doc('${playlistId}_$songId').set({
      'playlist_id': playlistId,
      'song_id': songId,
    });
  }

  Future<List<String>> getSongIdsFromPlaylist(String playlistId) async {
    QuerySnapshot snapshot = await _firestore
        .collection('playlist_songs')
        .where('playlist_id', isEqualTo: playlistId)
        .get();
    return snapshot.docs.map((doc) => doc['song_id'] as String).toList();
  }

  // --- FAVORITES ---

  Future<void> toggleFavorite(String userId, String songId) async {
    DocumentReference docRef = _firestore.collection('favorites').doc('${userId}_$songId');
    DocumentSnapshot doc = await docRef.get();

    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'user_id': userId,
        'song_id': songId,
      });
    }
  }

  Future<List<String>> getFavoriteSongIds(String userId) async {
    QuerySnapshot snapshot = await _firestore
        .collection('favorites')
        .where('user_id', isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) => doc['song_id'] as String).toList();
  }

  // --- ADMIN & ROLE LOGIC ---

  Future<String> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.get('role') ?? 'user';
      }
      return 'user';
    } catch (e) {
      return 'user';
    }
  }

  Future<void> setupAdminAccount() async {
    const adminEmail = 'admin@gmail.com';
    const adminPass = '123123';
    
    try {
      // Thử đăng nhập xem có chưa
      await _auth.signInWithEmailAndPassword(email: adminEmail, password: adminPass);
    } catch (e) {
      // Nếu chưa có thì tạo mới
      await signUp(adminEmail, adminPass, 'Admin Manager', role: 'admin');
    }
  }

  // --- PREMIUM LOGIC ---

  Future<bool> isUserPremium(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.get('is_premium') ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> updatePremiumStatus(String uid, bool status) async {
    await _firestore.collection('users').doc(uid).update({'is_premium': status});
  }

  // --- ADMIN: MUSIC MANAGEMENT ---

  Future<List<Map<String, dynamic>>> getAllSongs() async {
    QuerySnapshot snapshot = await _firestore.collection('songs').get();
    return snapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> addSong(Map<String, dynamic> songData) async {
    DocumentReference docRef = await _firestore.collection('songs').add(songData);
    
    // Gửi thông báo đến người dùng Premium khi có nhạc mới
    // Trong thực tế sẽ dùng Cloud Functions + FCM. Ở đây ta tạo record thông báo trong DB.
    QuerySnapshot premiumUsers = await _firestore.collection('users').where('is_premium', isEqualTo: true).get();
    for (var userDoc in premiumUsers.docs) {
      await _firestore.collection('notifications').add({
        'type': 'new_premium_song',
        'receiver_id': userDoc.id,
        'song_id': docRef.id,
        'song_title': songData['title'],
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unread',
      });
    }
  }

  Future<void> updateSong(String id, Map<String, dynamic> songData) async {
    await _firestore.collection('songs').doc(id).update(songData);
  }

  Future<void> deleteSong(String id) async {
    // Nếu là nhạc từ Firebase Storage, ta nên xóa file trong Storage nữa (nếu có URL)
    // Tuy nhiên ở bản đơn giản này ta chỉ xóa record trong Firestore.
    await _firestore.collection('songs').doc(id).delete();
  }

  // --- FIREBASE STORAGE: UPLOAD ---

  Future<String> uploadFile(File file, String folder) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      Reference ref = _storage.ref().child('$folder/$fileName');
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('❌ Lỗi upload file lên Storage: $e');
      rethrow;
    }
  }

  // --- ADMIN: USER MANAGEMENT ---

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    QuerySnapshot snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<void> updateUserRole(String uid, String role) async {
    await _firestore.collection('users').doc(uid).update({'role': role});
  }

  // --- ADMIN: COUPON MANAGEMENT ---

  Future<void> createCoupon(String code, int discount, int maxUsage) async {
    await _firestore.collection('coupons').doc(code).set({
      'code': code,
      'discount': discount,
      'max_usage': maxUsage,
      'used_count': 0,
      'is_active': true,
    });
  }

  Future<void> deleteCoupon(String code) async {
    await _firestore.collection('coupons').doc(code).delete();
  }

  Future<void> toggleCouponStatus(String code, bool isActive) async {
    await _firestore.collection('coupons').doc(code).update({'is_active': isActive});
  }

  Future<List<Map<String, dynamic>>> getAllCoupons() async {
    QuerySnapshot snapshot = await _firestore.collection('coupons').get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> validateCoupon(String code) async {
    DocumentSnapshot doc = await _firestore.collection('coupons').doc(code).get();
    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      bool isActive = data['is_active'] ?? true;
      if (isActive && data['used_count'] < data['max_usage']) {
        return data;
      }
    }
    return null;
  }

  Future<void> useCoupon(String code) async {
    await _firestore.collection('coupons').doc(code).update({
      'used_count': FieldValue.increment(1),
    });
  }

  // --- ADMIN: PREMIUM REQUESTS ---

  Future<void> requestPremium(String userId, String username) async {
    await _firestore.collection('premium_requests').doc(userId).set({
      'userId': userId,
      'username': username,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingPremiumRequests() async {
    QuerySnapshot snapshot = await _firestore
        .collection('premium_requests')
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<void> approvePremiumRequest(String userId) async {
    // 1. Update request status
    await _firestore.collection('premium_requests').doc(userId).update({
      'status': 'approved',
    });
    // 2. Update user status
    await updatePremiumStatus(userId, true);
  }

  Future<bool> hasPendingPremiumRequest(String userId) async {
    DocumentSnapshot doc = await _firestore.collection('premium_requests').doc(userId).get();
    if (doc.exists) {
      return doc.get('status') == 'pending';
    }
    return false;
  }

  Future<void> logPlayHistory(String userId, String songId, {String? songTitle, String? artist, String? image, String? source}) async {
    await _firestore.collection('play_history').add({
      'user_id': userId,
      'song_id': songId,
      'song_title': songTitle, // Hỗ trợ lưu thông tin nhạc API
      'artist': artist,
      'image': image,
      'source': source,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> logActivity(String userId, String type, String message) async {
    await _firestore.collection('activities').add({
      'user_id': userId,
      'type': type,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getPlayHistory(String userId) async {
    QuerySnapshot history = await _firestore
        .collection('play_history')
        .where('user_id', isEqualTo: userId)
        .get();
    
    List<Map<String, dynamic>> result = [];
    for (var doc in history.docs) {
      String songId = doc.get('song_id');
      
      // Nếu có song_title thì đây là nhạc lưu trực tiếp (API hoặc Lossless cache)
      Map<String, dynamic> data;
      if (doc.data() is Map && (doc.data() as Map).containsKey('song_title') && doc.get('song_title') != null) {
        data = {
          'id': songId,
          'title': doc.get('song_title'),
          'artist': doc.get('artist'),
          'image': doc.get('image'),
          'source': doc.get('source'),
          'played_at': doc.get('timestamp'),
        };
      } else {
        // Nếu không thì tra cứu trong Firestore songs (nhạc Lossless)
        DocumentSnapshot songDoc = await _firestore.collection('songs').doc(songId).get();
        if (songDoc.exists) {
          data = songDoc.data() as Map<String, dynamic>;
          data['id'] = songDoc.id;
          data['played_at'] = doc.get('timestamp');
        } else {
          continue;
        }
      }
      result.add(data);
    }

    result.sort((a, b) {
      Timestamp? tA = a['played_at'] as Timestamp?;
      Timestamp? tB = b['played_at'] as Timestamp?;
      if (tA == null || tB == null) return 0;
      return tB.compareTo(tA);
    });

    return result;
  }

  // --- FRIENDS SYSTEM (REWRITTEN FOR INVITATIONS) ---

  Future<void> sendFriendRequest(String senderId, String email) async {
    // 1. Tìm người nhận
    QuerySnapshot userSearch = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (userSearch.docs.isEmpty) {
      throw Exception('Không tìm thấy người dùng với email này!');
    }

    String receiverId = userSearch.docs.first.id;
    if (receiverId == senderId) {
      throw Exception('Bạn không thể kết bạn với chính mình!');
    }

    // Kiểm tra xem đã là bạn chưa
    DocumentSnapshot myDoc = await _firestore.collection('users').doc(senderId).get();
    List friends = (myDoc.data() as Map<String, dynamic>)['friends'] ?? [];
    if (friends.contains(receiverId)) {
      throw Exception('Hai người đã là bạn bè rồi!');
    }

    // 2. Gửi thông báo
    DocumentSnapshot senderDoc = await _firestore.collection('users').doc(senderId).get();
    String senderName = senderDoc.get('username') ?? 'Ai đó';

    await _firestore.collection('notifications').add({
      'type': 'friend_request',
      'receiver_id': receiverId,
      'sender_id': senderId,
      'sender_name': senderName,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> respondToFriendRequest(String notificationId, bool accept) async {
    DocumentReference notifRef = _firestore.collection('notifications').doc(notificationId);
    DocumentSnapshot notifDoc = await notifRef.get();
    
    if (!notifDoc.exists) return;
    
    if (accept) {
      String senderId = notifDoc.get('sender_id');
      String receiverId = notifDoc.get('receiver_id');
      
      // Thêm vào danh sách bạn bè của cả 2
      await _firestore.collection('users').doc(senderId).update({
        'friends': FieldValue.arrayUnion([receiverId]),
      });
      await _firestore.collection('users').doc(receiverId).update({
        'friends': FieldValue.arrayUnion([senderId]),
      });
      
      await notifRef.update({'status': 'accepted'});
    } else {
      await notifRef.update({'status': 'rejected'});
    }
  }

  Future<void> unfriend(String myUserId, String friendId) async {
    await _firestore.collection('users').doc(myUserId).update({
      'friends': FieldValue.arrayUnion([]), // Đảm bảo field tồn tại
    });
    await _firestore.collection('users').doc(myUserId).update({
      'friends': FieldValue.arrayRemove([friendId]),
    });
    await _firestore.collection('users').doc(friendId).update({
      'friends': FieldValue.arrayRemove([myUserId]),
    });
  }

  Future<List<Map<String, dynamic>>> getFriendList(String userId) async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return [];
    
    List friendIds = (userDoc.data() as Map<String, dynamic>)['friends'] ?? [];
    if (friendIds.isEmpty) return [];

    List<Map<String, dynamic>> friends = [];
    for (String fid in friendIds) {
      DocumentSnapshot fDoc = await _firestore.collection('users').doc(fid).get();
      if (fDoc.exists) {
        var data = fDoc.data() as Map<String, dynamic>;
        data['uid'] = fDoc.id;
        friends.add(data);
      }
    }
    return friends;
  }

  Future<List<Map<String, dynamic>>> getSocialFeed(String userId) async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
    List friends = (userDoc.data() as Map<String, dynamic>)['friends'] ?? [];
    if (friends.isEmpty) return [];

    List<String> queryIds = friends.cast<String>().toList();
    List<Map<String, dynamic>> result = [];

    // Duyệt qua từng người bạn để lấy 3 bài hát gần nhất
    for (String friendId in queryIds) {
      DocumentSnapshot fDoc = await _firestore.collection('users').doc(friendId).get();
      if (!fDoc.exists) continue;
      String username = fDoc.get('username') ?? 'Bạn bè';

      QuerySnapshot historySnapshot = await _firestore
          .collection('play_history')
          .where('user_id', isEqualTo: friendId)
          .limit(30) // Lấy nhiều hơn một chút để sắp xếp
          .get();

      if (historySnapshot.docs.isNotEmpty) {
        // Sắp xếp thủ công trên client để tránh lỗi Index
        var sortedDocs = historySnapshot.docs.toList()
          ..sort((a, b) {
            Timestamp? tA = a.get('timestamp') as Timestamp?;
            Timestamp? tB = b.get('timestamp') as Timestamp?;
            if (tA == null || tB == null) return 0;
            return tB.compareTo(tA);
          });

        List<Map<String, dynamic>> recentSongs = [];
        for (var doc in sortedDocs.take(3)) {
          var data = doc.data() as Map<String, dynamic>;
          recentSongs.add({
            'song_id': data['song_id'],
            'title': data['song_title'] ?? 'Unknown',
            'artist': data['artist'] ?? 'Unknown',
            'timestamp': data['timestamp'],
          });
        }
        
        result.add({
          'user_id': friendId,
          'username': username,
          'recent_songs': recentSongs,
          // Dùng timestamp của bài gần nhất để sắp xếp danh sách bạn bè
          'last_active': recentSongs[0]['timestamp'],
        });
      }
    }

    // Sắp xếp danh sách bạn bè theo thời gian hoạt động gần nhất
    result.sort((a, b) {
      Timestamp? tA = a['last_active'] as Timestamp?;
      Timestamp? tB = b['last_active'] as Timestamp?;
      if (tA == null || tB == null) return 0;
      return tB.compareTo(tA);
    });

    return result;
  }

  Future<List<Map<String, dynamic>>> getFriendsTopSongs(String userId) async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
    List friends = (userDoc.data() as Map<String, dynamic>)['friends'] ?? [];
    if (friends.isEmpty) return [];

    List<String> queryIds = friends.cast<String>().take(10).toList();
    
    // Lấy history của toàn bộ nhóm bạn bè
    QuerySnapshot history = await _firestore
        .collection('play_history')
        .where('user_id', whereIn: queryIds)
        .get();
    
    Map<String, Map<String, dynamic>> songDetails = {};
    Map<String, int> songCounts = {};

    for (var doc in history.docs) {
      String songId = doc.get('song_id');
      // Tích lũy lượt nghe: 2 người nghe 1 bài thì count sẽ tăng lên
      songCounts[songId] = (songCounts[songId] ?? 0) + 1;
      
      if (!songDetails.containsKey(songId)) {
        var data = doc.data() as Map;
        if (data.containsKey('song_title') && data['song_title'] != null) {
          songDetails[songId] = {
            'id': songId,
            'title': data['song_title'],
            'artist': data['artist'],
            'image': data['image'],
          };
        }
      }
    }
    
    var sortedEntries = songCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    List<Map<String, dynamic>> topSongs = [];
    for (var entry in sortedEntries.take(5)) {
      Map<String, dynamic> data;
      if (songDetails.containsKey(entry.key)) {
        data = Map<String, dynamic>.from(songDetails[entry.key]!);
      } else {
        DocumentSnapshot songDoc = await _firestore.collection('songs').doc(entry.key).get();
        if (songDoc.exists) {
          data = songDoc.data() as Map<String, dynamic>;
          data['id'] = songDoc.id;
        } else {
          continue;
        }
      }
      data['play_count'] = entry.value; // Số lượt nghe tổng cộng từ các bạn bè
      topSongs.add(data);
    }
    return topSongs;
  }

  Future<Map<String, dynamic>> getUserStats(String userId) async {
    QuerySnapshot history = await _firestore
        .collection('play_history')
        .where('user_id', isEqualTo: userId)
        .get();
    
    Map<String, int> songCounts = {};
    Map<String, String> songTitles = {};

    for (var doc in history.docs) {
      String songId = doc.get('song_id');
      songCounts[songId] = (songCounts[songId] ?? 0) + 1;
      
      // Cache title if available in the history doc
      var data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('song_title') && data['song_title'] != null) {
        songTitles[songId] = data['song_title'];
      }
    }
    
    // Sort and take Top 3
    var sortedSongs = songCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    List<String> topSongDisplayNames = [];
    for (var entry in sortedSongs.take(3)) {
      String songId = entry.key;
      String? title = songTitles[songId];
      
      // If not in history, look in songs collection
      if (title == null) {
        DocumentSnapshot songDoc = await _firestore.collection('songs').doc(songId).get();
        if (songDoc.exists) {
          title = songDoc.get('title') ?? 'Unknown Title';
        } else {
          title = 'Song ID: $songId';
        }
      }
      topSongDisplayNames.add(title!);
    }
    
    return {
      'total_plays': history.docs.length,
      'top_songs': topSongDisplayNames,
    };
  }

  Future<List<Map<String, dynamic>>> getGlobalTopSongs() async {
    QuerySnapshot history = await _firestore.collection('play_history').get();
    
    Map<String, int> songCounts = {};
    Map<String, Map<String, dynamic>> songDetails = {};

    for (var doc in history.docs) {
      String songId = doc.get('song_id');
      songCounts[songId] = (songCounts[songId] ?? 0) + 1;
      
      var data = doc.data() as Map<String, dynamic>;
      if (!songDetails.containsKey(songId) && data['song_title'] != null) {
        songDetails[songId] = {
          'id': songId,
          'title': data['song_title'],
          'artist': data['artist'],
          'image': data['image'],
        };
      }
    }
    
    var sortedEntries = songCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    List<Map<String, dynamic>> topSongs = [];
    for (var entry in sortedEntries.take(20)) {
      Map<String, dynamic> data;
      if (songDetails.containsKey(entry.key)) {
        data = Map<String, dynamic>.from(songDetails[entry.key]!);
      } else {
        DocumentSnapshot songDoc = await _firestore.collection('songs').doc(entry.key).get();
        if (songDoc.exists) {
          data = songDoc.data() as Map<String, dynamic>;
          data['id'] = songDoc.id;
        } else {
          data = {'id': entry.key, 'title': 'Unknown Song'};
        }
      }
      data['play_count'] = entry.value;
      topSongs.add(data);
    }
    return topSongs;
  }
}
