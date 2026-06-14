import 'package:flutter/material.dart';
import '../../data/firebase_service.dart';

class AdminCouponManagerScreen extends StatefulWidget {
  const AdminCouponManagerScreen({super.key});

  @override
  State<AdminCouponManagerScreen> createState() => _AdminCouponManagerScreenState();
}

class _AdminCouponManagerScreenState extends State<AdminCouponManagerScreen> {
  final _fb = FirebaseService.instance;
  List<Map<String, dynamic>> _coupons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    setState(() => _isLoading = true);
    final data = await _fb.getAllCoupons();
    setState(() {
      _coupons = data;
      _isLoading = false;
    });
  }

  void _showAddCouponDialog() {
    final codeController = TextEditingController();
    final discountController = TextEditingController();
    final usageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Coupon'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Coupon Code (e.g. KM50)')),
            TextField(controller: discountController, decoration: const InputDecoration(labelText: 'Discount Amount (VNĐ)'), keyboardType: TextInputType.number),
            TextField(controller: usageController, decoration: const InputDecoration(labelText: 'Max Usage Limit'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.isNotEmpty) {
                await _fb.createCoupon(
                  codeController.text.toUpperCase(),
                  int.tryParse(discountController.text) ?? 500,
                  int.tryParse(usageController.text) ?? 10,
                );
                if (mounted) {
                  Navigator.pop(context);
                  _loadCoupons();
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa coupon "$code"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _fb.deleteCoupon(code);
      _loadCoupons();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coupon Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCouponDialog,
        child: const Icon(Icons.confirmation_number),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _coupons.length,
              itemBuilder: (context, index) {
                final coupon = _coupons[index];
                final code = coupon['code'];
                final isActive = coupon['is_active'] ?? true;

                return Opacity(
                  opacity: isActive ? 1.0 : 0.5,
                  child: ListTile(
                    leading: const Icon(Icons.card_giftcard, color: Colors.orange),
                    title: Row(
                      children: [
                        Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (!isActive)
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Chip(
                              label: Text('Vô hiệu hóa', style: TextStyle(fontSize: 10, color: Colors.white)),
                              backgroundColor: Colors.red,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text('Giảm: ${coupon['discount']} VNĐ\nSử dụng: ${coupon['used_count']} / ${coupon['max_usage']}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: isActive,
                          onChanged: (value) async {
                            await _fb.toggleCouponStatus(code, value);
                            _loadCoupons();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _confirmDelete(code),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
