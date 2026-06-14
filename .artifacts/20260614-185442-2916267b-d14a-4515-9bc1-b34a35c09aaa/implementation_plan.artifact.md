# Admin Panel Enhancements: Global Song Stats & Coupon Management

This plan outlines the changes to add global song statistics, enhance coupon management (delete/disable), and clean up the admin dashboard.

## User Review Required

> [!NOTE]
> I will be using a `DefaultTabController` in the `AdminUserStatsScreen` to separate User Stats and Global Song Stats.

## Proposed Changes

### Data Layer

#### [firebase_service.dart](file:///C:/Users/chipt/AndroidStudioProjects/Nhac-Alime/lib/data/firebase_service.dart)

- Add `getGlobalTopSongs()` to fetch the most played songs across all users.
- Add `deleteCoupon(String code)` to remove a coupon from Firestore.
- Add `toggleCouponStatus(String code, bool isActive)` to enable/disable a coupon.
- Update `createCoupon` to include an `is_active` field (defaulting to `true`).
- Update `validateCoupon` to ensure it only accepts active coupons.

```dart
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
    for (var entry in sortedEntries.take(10)) {
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
```

---

### UI Layer

#### [admin_dashboard.dart](file:///C:/Users/chipt/AndroidStudioProjects/Nhac-Alime/lib/ui/admin/admin_dashboard.dart)

- Remove the "Settings" card from `_buildManagementGrid`.

#### [admin_user_stats.dart](file:///C:/Users/chipt/AndroidStudioProjects/Nhac-Alime/lib/ui/admin/admin_user_stats.dart)

- Add a `DefaultTabController` with two tabs: "Người dùng" and "Bài hát".
- Move existing user stats list to the "Người dùng" tab.
- Add a list to the "Bài hát" tab showing global top songs using `getGlobalTopSongs()`.

#### [admin_coupon_manager.dart](file:///C:/Users/chipt/AndroidStudioProjects/Nhac-Alime/lib/ui/admin/admin_coupon_manager.dart)

- Add a `Switch` in each `ListTile` to toggle coupon status.
- Add a delete icon button to each `ListTile`.
- Update UI to show if a coupon is currently disabled (e.g., using opacity or a label).

## Verification Plan

### Automated Tests
- Not applicable for this UI/Firebase change without complex mocking.

### Manual Verification
1. **Admin Dashboard**: Open the dashboard and verify the "Settings" card is gone.
2. **Statistics**:
    - Open "User Statistics".
    - Verify two tabs are present.
    - Verify "Người dùng" tab still works.
    - Verify "Bài hát" tab displays a list of songs with their play counts.
3. **Coupon Management**:
    - Create a new coupon and verify it shows up as "Active".
    - Toggle a coupon to "Inactive" and verify the switch state persists.
    - Try to use a disabled coupon in the app (if there's a UI for it) to verify `validateCoupon` works.
    - Delete a coupon and verify it is removed from the list and Firestore.
