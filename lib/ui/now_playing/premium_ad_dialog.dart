import 'package:flutter/material.dart';
import '../setting/premium_screen.dart';

class PremiumAdDialog extends StatelessWidget {
  final String userId;
  final VoidCallback onDismiss;

  const PremiumAdDialog({
    super.key,
    required this.userId,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(top: 16, right: 16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, size: 80, color: Colors.amber),
                const SizedBox(height: 24),
                const Text(
                  'MUSIC PREMIUM',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nâng cấp ngay để tận hưởng âm nhạc không giới hạn, không quảng cáo và chất lượng Lossless đỉnh cao!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDismiss(); // Cần resume nhạc trước khi chuyển trang
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PremiumScreen(userId: userId)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('NÂNG CẤP CHỈ 2K', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onDismiss();
                  },
                  child: const Text('Để sau', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onDismiss();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
