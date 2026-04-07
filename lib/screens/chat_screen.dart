import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class ChatScreen extends StatefulWidget {
  final String chatWithUser;
  final String receiverId;

  const ChatScreen({
    super.key,
    required this.chatWithUser,
    required this.receiverId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final ImagePicker _picker = ImagePicker();

  final String _currentUid =
      FirebaseAuth.instanceFor(app: Firebase.app()).currentUser?.uid ?? '';

  late String _chatRoomId;
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _chatRoomId = _chatService.getChatRoomId(_currentUid, widget.receiverId);
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text;
    final isEditing = _editingMessageId != null;
    final editingId = _editingMessageId;

    _messageController.clear();
    _editingMessageId = null;

    if (isEditing && editingId != null) {
      await _chatService.updateMessage(_chatRoomId, editingId, text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message updated')));
      }
    } else {
      await _chatService.sendMessage(
        widget.receiverId,
        widget.chatWithUser,
        text,
      );
    }

    if (mounted) setState(() {});
  }

  Future<void> _deleteMessage(String messageId) async {
    await _chatService.deleteMessage(_chatRoomId, messageId);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message deleted')));
    }
  }

  void _startEditingMessage(String messageId, String messageText) {
    setState(() {
      _editingMessageId = messageId;
      _messageController.text = messageText;
    });
  }

  Future<void> _sendAttachment(
    Uint8List fileBytes,
    String filename,
    String attachmentType,
  ) async {
    try {
      await _chatService.sendAttachment(
        widget.receiverId,
        widget.chatWithUser,
        fileBytes,
        filename,
        attachmentType,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sent $filename')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send $filename: $e')));
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      await _sendAttachment(bytes, pickedFile.name, 'image');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image send failed: $e')));
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xlsx', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      Uint8List? bytes = picked.bytes;
      if (bytes == null && picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }
      if (bytes == null) return;

      await _sendAttachment(bytes, picked.name, 'document');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Document send failed: $e')));
      }
    }
  }

  Future<void> _showAttachmentOptions() async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Send image'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Send document / PPT'),
              onTap: () {
                Navigator.of(context).pop();
                _pickDocument();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download attachments'),
              onTap: () {
                Navigator.of(context).pop();
                _showAttachmentLibrary();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAttachmentLibrary() async {
    final snapshot = await _chatService.getMessagesOnce(_chatRoomId);
    final attachments = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['attachmentUrl'] != null;
    }).toList();

    if (!mounted) return;

    if (attachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attachments found in this chat.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final doc in attachments)
              Builder(
                builder: (context) {
                  final data = doc.data() as Map<String, dynamic>;
                  final url = data['attachmentUrl'] as String;
                  final name =
                      data['attachmentName'] as String? ?? 'Attachment';
                  final type = data['attachmentType'] as String? ?? 'file';
                  return ListTile(
                    leading: Icon(
                      type == 'image' ? Icons.photo : Icons.insert_drive_file,
                    ),
                    title: Text(name),
                    subtitle: Text(type),
                    onTap: () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMessageOptions(String messageId, String messageText) async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit message'),
              onTap: () {
                Navigator.of(context).pop();
                _startEditingMessage(messageId, messageText);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete message'),
              onTap: () {
                Navigator.of(context).pop();
                _deleteMessage(messageId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark ? Colors.black : Colors.white;
    final surfaceColor = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF5F5F5);
    final borderColor = isDark ? Colors.white24 : Colors.black12;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 TOP BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: primaryTextColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.chatWithUser,
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 MESSAGES (FIREBASE)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatService.getMessages(_chatRoomId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!.docs;

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg =
                          messages[index].data() as Map<String, dynamic>;

                      final isMe = msg['senderId'] == _currentUid;

                      final bubbleColor = isMe
                          ? (isDark
                                ? const Color(0xFF262A35)
                                : const Color(0xFFE0F2F1))
                          : surfaceColor;
                      final textColor = isMe
                          ? (isDark ? Colors.white : Colors.black)
                          : primaryTextColor;

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: isMe
                              ? () => _showMessageOptions(
                                  messages[index].id,
                                  msg['text'] ?? '',
                                )
                              : null,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (msg['text'] != null &&
                                    msg['text'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text(
                                      msg['text'] ?? '',
                                      style: TextStyle(color: textColor),
                                    ),
                                  ),
                                if (msg['attachmentUrl'] != null)
                                  GestureDetector(
                                    onTap: () async {
                                      final url =
                                          msg['attachmentUrl'] as String;
                                      final uri = Uri.parse(url);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 260,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? (isDark
                                                  ? const Color(0xFF1F2430)
                                                  : const Color(0xFFD7F0EA))
                                            : const Color(0xFF2A2A2A),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            msg['attachmentType'] == 'image'
                                                ? Icons.photo
                                                : Icons.insert_drive_file,
                                            color: isMe
                                                ? (isDark
                                                      ? Colors.white
                                                      : Colors.black)
                                                : Colors.white,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              msg['attachmentName'] ??
                                                  'Attachment',
                                              style: TextStyle(
                                                color: isMe
                                                    ? (isDark
                                                          ? Colors.white
                                                          : Colors.black)
                                                    : Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // 🔹 INPUT
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.attach_file, color: primaryTextColor),
                      onPressed: _showAttachmentOptions,
                      tooltip: 'Send image or document',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: primaryTextColor),
                      decoration: InputDecoration(
                        hintText: "Message",
                        hintStyle: TextStyle(color: secondaryTextColor),
                        filled: true,
                        fillColor: surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: primaryTextColor),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: primaryTextColor),
                      onPressed: _sendMessage,
                      tooltip: 'Send message',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
