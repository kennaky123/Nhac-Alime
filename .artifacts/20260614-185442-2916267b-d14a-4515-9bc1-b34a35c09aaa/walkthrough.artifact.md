# Admin Panel Enhancements Walkthrough

I have updated the Admin panel with global song statistics, enhanced coupon management, and a cleaner dashboard interface.

## Changes Overview

### 1. Global Song Statistics
- Added a new `getGlobalTopSongs()` method in `FirebaseService` to aggregate play counts across all users.
- Updated `AdminUserStatsScreen` to use a tabbed interface.
- **"Người dùng" Tab**: Displays the existing user-specific play history and top songs.
- **"Bài hát" Tab**: Shows a ranked list of the most played songs globally with their total play counts.

### 2. Enhanced Coupon Management
- Updated `AdminCouponManagerScreen` with new capabilities:
    - **Disable/Enable**: A switch allows admins to toggle coupons between active and inactive states. Inactive coupons are visually dimmed and marked with a "Vô hiệu hóa" tag.
    - **Delete**: A delete button allows for permanent removal of coupons after a confirmation dialog.
- `FirebaseService.validateCoupon` was updated to reject inactive coupons even if they haven't reached their usage limit.

### 3. Admin Dashboard Cleanup
- Removed the empty "Settings" card from the `AdminDashboard` to simplify the interface.

## Verification Summary

### UI Verification
- [x] **Dashboard**: Confirmed "Settings" card is removed.
- [x] **Stats Screen**: Confirmed tab navigation works and both User/Global stats display correctly.
- [x] **Coupon Manager**: Confirmed toggle switch updates UI and Firestore state. Confirmed delete dialog works.

### Logic Verification
- [x] **Coupon Validation**: Verified that `validateCoupon` now checks the `is_active` flag.
- [x] **Stats Aggregation**: Verified that `getGlobalTopSongs` correctly counts occurrences of `song_id` in the `play_history` collection.
