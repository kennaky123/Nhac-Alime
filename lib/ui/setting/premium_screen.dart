import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../data/firebase_service.dart';

class PremiumScreen extends StatefulWidget {
  final String userId;
  const PremiumScreen({super.key, required this.userId});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isPremium = false;
  bool _isLoading = true;
  bool _isPending = false;
  final _couponController = TextEditingController();
  int _currentPrice = 2000;
  String? _appliedCoupon;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await FirebaseService.instance.isUserPremium(widget.userId);
    final pending = await FirebaseService.instance.hasPendingPremiumRequest(widget.userId);
    if (mounted) {
      setState(() {
        _isPremium = status;
        _isPending = pending;
        _isLoading = false;
      });
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final coupon = await FirebaseService.instance.validateCoupon(code);
    if (coupon != null) {
      setState(() {
        _currentPrice = (2000 - (coupon['discount'] as int)).clamp(0, 2000);
        _appliedCoupon = code;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mã giảm giá đã áp dụng! Giảm ${coupon['discount']} VNĐ')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mã giảm giá không hợp lệ hoặc đã hết lượt dùng.')),
        );
      }
    }
  }

  void _showPaymentDialog() {
    // Thông tin VietQR
    const String bankId = 'MB'; // MB Bank
    const String accountNo = '0763550948';
    final String amount = _currentPrice.toString();
    final String description = 'PREMIUM ${widget.userId.substring(0, 5)}';
    
    // Link tạo mã QR từ VietQR
    final String qrUrl = 'https://img.vietqr.io/image/$bankId-$accountNo-compact2.png?amount=$amount&addInfo=$description';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thanh toán Premium', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Vui lòng quét mã QR bên dưới để chuyển khoản $_currentPrice VNĐ'),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.network(
                qrUrl,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 200,
                  child: Center(child: Icon(Icons.error_outline, size: 40)),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'MB Bank: 0763550948\nSố tiền: $_currentPrice VNĐ',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (_appliedCoupon != null) {
                await FirebaseService.instance.useCoupon(_appliedCoupon!);
              }
              // Gửi yêu cầu lên Admin thay vì nâng cấp luôn
              final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
              final username = userDoc.get('username') ?? 'Unknown';
              await FirebaseService.instance.requestPremium(widget.userId, username);
              
              if (mounted) {
                Navigator.pop(context);
                _loadStatus();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yêu cầu đã được gửi! Vui lòng chờ Admin phê duyệt.')),
                );
              }
            },
            child: const Text('Gửi yêu cầu nâng cấp'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Music Premium')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Header Image/Icon
            Icon(Icons.stars_rounded, size: 100, color: Colors.amber.shade700),
            const SizedBox(height: 16),
            const Text(
              'Nâng cấp Premium',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Trải nghiệm âm nhạc không giới hạn',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 40),

            // Benefits List
            _buildBenefitItem(
              Icons.block_flipped,
              'Không quảng cáo',
              'Nghe nhạc liên tục không bị gián đoạn bởi quảng cáo.',
              colorScheme,
            ),
            const SizedBox(height: 20),
            _buildBenefitItem(
              Icons.high_quality,
              'Âm thanh Lossless',
              'Thưởng thức chất lượng âm thanh cao cấp nhất (Hi-Fi).',
              colorScheme,
            ),
            const SizedBox(height: 20),
            _buildBenefitItem(
              Icons.download_for_offline,
              'Nghe Offline',
              'Tải nhạc về máy và nghe mọi lúc mọi nơi.',
              colorScheme,
            ),

            const SizedBox(height: 40),

            // Coupon Code Section
            if (!_isPremium) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _couponController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập mã giảm giá',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _applyCoupon,
                    child: const Text('Áp dụng'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Pricing & Button
            if (!_isPremium) ...[
              if (_isPending)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_empty, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Yêu cầu đang chờ phê duyệt. Vui lòng kiểm tra lại sau.',
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  'Giá: $_currentPrice VNĐ',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                if (_appliedCoupon != null)
                  const Text('Đã áp dụng mã giảm giá', style: TextStyle(color: Colors.green, fontSize: 12)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _showPaymentDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Đăng ký ngay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Text(
                      'Bạn đang sử dụng gói Premium',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(description, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
            ],
          ),
        ),
      ],
    );
  }
}
