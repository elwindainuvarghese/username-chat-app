import 'package:flutter/material.dart';

class NewChatScreen extends StatelessWidget {
  const NewChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF3B3B3B),
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: const Center(
        child: Text(
          'New Chat Screen',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B1B3A),
          ),
        ),
      ),
    );
  }
}
