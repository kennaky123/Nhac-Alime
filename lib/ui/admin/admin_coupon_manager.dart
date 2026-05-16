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
                return ListTile(
                  leading: const Icon(Icons.card_giftcard, color: Colors.orange),
                  title: Text(coupon['code']),
                  subtitle: Text('Discount: ${coupon['discount']} VNĐ'),
                  trailing: Text('Used: ${coupon['used_count']} / ${coupon['max_usage']}'),
                );
              },
            ),
    );
  }
}
