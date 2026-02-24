import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatWithUser;

  const ChatScreen({super.key, required this.chatWithUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final AuthService _authService = AuthService();
  String _currentUser = 'User';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final name = await _authService.getUsername();
    if (name != null && mounted) {
      setState(() {
        _currentUser = name;
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text;
    _messageController.clear(); // Clear immediately for UX

    await FirebaseFirestore.instance.collection('messages').add({
      'text': text,
      'senderId': _currentUser,
      'receiverId': widget.chatWithUser,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatWithUser),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', 
                      style: TextStyle(color: textColor)
                    )
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No messages yet. Say hi!', 
                      style: TextStyle(color: textColor.withOpacity(0.6))
                    )
                  );
                }

                // Filter messages client-side for simplicity in demo
                // (In production, use where() in the Firestore query)
                final allMessages = snapshot.data!.docs;
                final chatMessages = allMessages.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final sender = data['senderId'] as String?;
                  final receiver = data['receiverId'] as String?;
                  
                  return (sender == _currentUser && receiver == widget.chatWithUser) ||
                         (sender == widget.chatWithUser && receiver == _currentUser);
                }).toList();

                if (chatMessages.isEmpty) {
                  return Center(
                    child: Text('No messages with ${widget.chatWithUser} yet.', 
                      style: TextStyle(color: textColor.withOpacity(0.6))
                    )
                  );
                }

                return ListView.builder(
                  reverse: true, // Start from bottom
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: chatMessages.length,
                  itemBuilder: (context, index) {
                    final messageData = chatMessages[index].data() as Map<String, dynamic>;
                    final isMe = messageData['senderId'] == _currentUser;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8, top: 8, left: isMe ? 50.0 : 0.0, right: isMe ? 0.0 : 50.0),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe 
                              ? const Color(0xFF00A884) 
                              : (isDark ? const Color(0xFF1F2C34) : Colors.white),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            )
                          ]
                        ),
                        child: Text(
                          messageData['text'] ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.white : textColor,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Chat Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F1F2E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                )
              ]
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A3C) : const Color(0xFFF0F0F5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: textColor),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'Message',
                          hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A884),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
