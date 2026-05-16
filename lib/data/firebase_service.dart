import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._init();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    QuerySnapshot snapshot = await _firestore
        .collection('playlists')
        .where('user_id', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((doc) => {
              'id': doc.id,
              'title': doc['title'],
              'user_id': doc['user_id'],
            })
        .toList();
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
    await _firestore.collection('songs').add(songData);
  }

  Future<void> updateSong(String id, Map<String, dynamic> songData) async {
    await _firestore.collection('songs').doc(id).update(songData);
  }

  Future<void> deleteSong(String id) async {
    await _firestore.collection('songs').doc(id).delete();
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
    });
  }

  Future<List<Map<String, dynamic>>> getAllCoupons() async {
    QuerySnapshot snapshot = await _firestore.collection('coupons').get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> validateCoupon(String code) async {
    DocumentSnapshot doc = await _firestore.collection('coupons').doc(code).get();
    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['used_count'] < data['max_usage']) {
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
}
