import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../widgets/glass_container.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _emailController = TextEditingController();
  final ChatService _chatService = ChatService();
  
  bool _isLoading = false;
  Map<String, dynamic>? _searchedUser;
  String? _errorMessage;

  void _searchUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchedUser = null;
    });

    final user = await _chatService.searchUserByEmail(email);
    
    setState(() {
      _isLoading = false;
      if (user != null) {
        _searchedUser = user;
      } else {
        _errorMessage = "User not found with this email.";
      }
    });
  }

  void _addContact() async {
    if (_searchedUser == null) return;

    setState(() => _isLoading = true);

    final success = await _chatService.addContact(
      _searchedUser!['uid'],
      _searchedUser!['email'],
      _searchedUser!['displayName'] ?? 'User',
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_searchedUser!['displayName']} added to contacts!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add contact. Note: You cannot add yourself.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Contact'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GlassContainer(
              opacity: isDark ? 0.1 : 0.6,
              blur: 15,
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: "Enter user's email...",
                        hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: textColor.withOpacity(0.5)),
                      ),
                      onSubmitted: (_) => _searchUser(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    color: const Color(0xFF00A884),
                    onPressed: _searchUser,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            if (_isLoading)
              const CircularProgressIndicator()
            else if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
              )
            else if (_searchedUser != null)
              GlassContainer(
                opacity: isDark ? 0.15 : 0.8,
                blur: 20,
                borderRadius: 16,
                padding: const EdgeInsets.all(16),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF00A884).withOpacity(0.2),
                    child: const Icon(Icons.person, color: Color(0xFF00A884)),
                  ),
                  title: Text(
                    _searchedUser!['displayName'] ?? 'Unknown',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _searchedUser!['email'] ?? '',
                    style: TextStyle(color: textColor.withOpacity(0.7)),
                  ),
                  trailing: ElevatedButton(
                    onPressed: _addContact,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A884),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text("Add"),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
