import 'package:flutter/material.dart';
import '../../data/firebase_service.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  final _fb = FirebaseService.instance;
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final data = await _fb.getPendingPremiumRequests();
    setState(() {
      _requests = data;
      _isLoading = false;
    });
  }

  Future<void> _approveRequest(String userId) async {
    await _fb.approvePremiumRequest(userId);
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium Approvals')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(child: Text('No pending requests.'))
              : ListView.builder(
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(request['username'] ?? 'Unknown'),
                      subtitle: Text('ID: ${request['userId']}'),
                      trailing: ElevatedButton(
                        onPressed: () => _approveRequest(request['userId']),
                        child: const Text('Approve'),
                      ),
                    );
                  },
                ),
    );
  }
}
