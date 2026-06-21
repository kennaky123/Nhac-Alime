import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../data/firebase_service.dart';
import '../user/chat_screen.dart';

class AdminChatListScreen extends StatelessWidget {
  const AdminChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Chats'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.instance.getActiveChats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return const Center(child: Text('No active chats yet.'));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index].data() as Map<String, dynamic>;
              final String userId = chat['chatId'];
              final String lastMessage = chat['lastMessage'] ?? '';
              final bool hasNewMessage = chat['hasNewMessage'] ?? false;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                builder: (context, userSnapshot) {
                  String userName = 'Loading...';
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    userName = userSnapshot.data!.get('username') ?? 'Anonymous';
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?'),
                    ),
                    title: Text(
                      userName,
                      style: TextStyle(fontWeight: hasNewMessage ? FontWeight.bold : FontWeight.normal),
                    ),
                    subtitle: Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: hasNewMessage ? FontWeight.bold : FontWeight.normal),
                    ),
                    trailing: hasNewMessage
                        ? Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                          )
                        : null,
                    onTap: () {
                      FirebaseService.instance.markChatAsRead(userId);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            userId: userId,
                            userName: userName,
                            isAdmin: true,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
