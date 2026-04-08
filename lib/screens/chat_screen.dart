import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/link_safety_result.dart';
import '../services/chat_service.dart';
import '../services/link_safety_service.dart';
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
  final LinkSafetyService _linkSafetyService = LinkSafetyService.instance;
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

  Future<void> _openMessageUrl(
    BuildContext context,
    String url,
    LinkSafetyResult? safetyResult,
  ) async {
    final Uri uri = Uri.parse(url);

    if (safetyResult == null || safetyResult.isSafe) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (!context.mounted) return;

    final bool? shouldOpen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            safetyResult.isUnsafe ? 'Unsafe link detected' : 'Link check unavailable',
          ),
          content: Text(
            safetyResult.isUnsafe
                ? 'This link was flagged as ${safetyResult.threatTypesLabel}. Opening it may expose your device or data to risk. Do you still want to open it?'
                : 'The app could not verify this link. Opening it may still be unsafe. Do you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open anyway'),
            ),
          ],
        );
      },
    );

    if (shouldOpen == true && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
                      final String messageText = (msg['text'] ?? '').toString();

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
                                if (messageText.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: _MessageTextWithLinks(
                                      messageText: messageText,
                                      textColor: textColor,
                                      isDark: isDark,
                                      linkSafetyService: _linkSafetyService,
                                      onOpenUrl: _openMessageUrl,
                                    ),
                                  ),
                                if (messageText.isNotEmpty)
                                  _MessageLinkSafetyIndicators(
                                    messageText: messageText,
                                    isDark: isDark,
                                    linkSafetyService: _linkSafetyService,
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

class _MessageLinkSafetyIndicators extends StatelessWidget {
  final String messageText;
  final bool isDark;
  final LinkSafetyService linkSafetyService;

  const _MessageLinkSafetyIndicators({
    required this.messageText,
    required this.isDark,
    required this.linkSafetyService,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LinkSafetyResult>>(
      // URL checks run in the background and are cached by the service.
      future: linkSafetyService.checkMessageLinks(messageText),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final List<LinkSafetyResult> results = snapshot.data!;
        if (results.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: results
                .map((result) => _SafetyBadge(result: result, isDark: isDark))
                .toList(growable: false),
          ),
        );
      },
    );
  }
}

class _MessageTextWithLinks extends StatelessWidget {
  final String messageText;
  final Color textColor;
  final bool isDark;
  final LinkSafetyService linkSafetyService;
  final Future<void> Function(
    BuildContext context,
    String url,
    LinkSafetyResult? safetyResult,
  ) onOpenUrl;

  const _MessageTextWithLinks({
    required this.messageText,
    required this.textColor,
    required this.isDark,
    required this.linkSafetyService,
    required this.onOpenUrl,
  });

  static final RegExp _urlRegex = RegExp(
    r"((https?:\/\/)|(www\.))[\w\-._~:\/?#[\]@!$&'()*+,;=%]+",
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LinkSafetyResult>>(
      future: linkSafetyService.checkMessageLinks(messageText),
      builder: (context, snapshot) {
        final Map<String, LinkSafetyResult> safetyByUrl = <String, LinkSafetyResult>{};
        final List<LinkSafetyResult> results = snapshot.data ?? const <LinkSafetyResult>[];
        for (final result in results) {
          safetyByUrl[result.url] = result;
        }

        final List<InlineSpan> spans = <InlineSpan>[];
        int currentIndex = 0;

        for (final RegExpMatch match in _urlRegex.allMatches(messageText)) {
          final int start = match.start;
          final int end = match.end;
          final String rawUrl = messageText.substring(start, end);
          final List<String> normalizedCandidates = linkSafetyService.extractUrls(rawUrl);
          final String normalizedUrl = normalizedCandidates.isNotEmpty
              ? normalizedCandidates.first
              : _normalizeUrlForDisplay(rawUrl);

          if (start > currentIndex) {
            spans.add(
              TextSpan(
                text: messageText.substring(currentIndex, start),
                style: TextStyle(color: textColor),
              ),
            );
          }

          final LinkSafetyResult? safetyResult = safetyByUrl[normalizedUrl];
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _ClickableMessageLink(
                displayText: rawUrl,
                url: normalizedUrl,
                textColor: textColor,
                safetyResult: safetyResult,
                onTap: () => onOpenUrl(context, normalizedUrl, safetyResult),
              ),
            ),
          );

          currentIndex = end;
        }

        if (currentIndex < messageText.length) {
          spans.add(
            TextSpan(
              text: messageText.substring(currentIndex),
              style: TextStyle(color: textColor),
            ),
          );
        }

        if (spans.isEmpty) {
          return Text(messageText, style: TextStyle(color: textColor));
        }

        return RichText(
          text: TextSpan(
            style: TextStyle(color: textColor, height: 1.35),
            children: spans,
          ),
        );
      },
    );
  }

  String _normalizeUrlForDisplay(String input) {
    String value = input.trim();
    value = value.replaceAll(RegExp(r'[),.;!?]+$'), '');
    if (value.startsWith('www.')) {
      value = 'https://$value';
    }
    return value;
  }
}

class _ClickableMessageLink extends StatelessWidget {
  final String displayText;
  final String url;
  final Color textColor;
  final LinkSafetyResult? safetyResult;
  final VoidCallback onTap;

  const _ClickableMessageLink({
    required this.displayText,
    required this.url,
    required this.textColor,
    required this.safetyResult,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color linkColor = safetyResult == null
        ? Colors.blueAccent
        : safetyResult!.isUnsafe
            ? Colors.redAccent
            : Colors.blueAccent;

    return InkWell(
      onTap: onTap,
      child: Text(
        displayText,
        style: TextStyle(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
      ),
    );
  }
}

class _SafetyBadge extends StatelessWidget {
  final LinkSafetyResult result;
  final bool isDark;

  const _SafetyBadge({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color backgroundColor;
    IconData icon;
    String label;

    if (result.status == LinkSafetyStatus.safe) {
      textColor = Colors.green.shade800;
      backgroundColor = Colors.green.shade100;
      icon = Icons.verified;
      label = 'Safe Link';
    } else if (result.status == LinkSafetyStatus.unsafe) {
      textColor = Colors.red.shade800;
      backgroundColor = Colors.red.shade100;
      icon = Icons.warning_rounded;
      label = 'Scam/Unsafe Link';
    } else {
      textColor = isDark ? Colors.white70 : Colors.black54;
      backgroundColor = isDark ? Colors.white12 : Colors.black12;
      icon = Icons.help_outline;
      label = 'Link status unknown';
    }

    return Tooltip(
      message: result.isUnsafe
          ? '${result.threatTypesLabel}\n${result.url}'
          : result.url,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: textColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (result.isUnsafe && result.threatTypes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                result.threatTypesLabel,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
