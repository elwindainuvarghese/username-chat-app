import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/link_safety_result.dart';
import '../services/chat_service.dart';
import '../services/link_safety_service.dart';
import '../widgets/full_screen_image_viewer.dart';

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

  final String _currentUid =
      FirebaseAuth.instanceFor(app: Firebase.app()).currentUser?.uid ?? '';

  late String _chatRoomId;
  String? _editingMessageId;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatRoomId = _chatService.getChatRoomId(_currentUid, widget.receiverId);
  }

  void _sendMessage() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    if (_isSending) return;

    final isEditing = _editingMessageId != null;
    final editingId = _editingMessageId;

    try {
      if (isEditing && editingId != null) {
        await _chatService.updateMessage(_chatRoomId, editingId, text);
        _messageController.clear();
        _editingMessageId = null;
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
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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

  void _showForwardContacts(Map<String, dynamic> messageData) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Forward to...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatService.getContactsStream(),
                builder: (streamContext, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No contacts found."));
                  }

                  final contacts = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (listContext, index) {
                      final contact =
                          contacts[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade800,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          contact['displayName'] ?? contact['email'] ?? 'User',
                        ),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          try {
                            await _chatService.forwardMessage(
                              contact['uid'],
                              messageData,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Message forwarded to ${contact['displayName'] ?? 'user'}',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to forward: $e'),
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  );
                },
              ),
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
            safetyResult.isUnsafe
                ? 'Unsafe link detected'
                : 'Link check unavailable',
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

    // Theme-aware colors
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final surfaceColor = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF0F0F0);
    final tealColor = const Color(0xFF2BBBAD);
    final otherBubbleColor = isDark
        ? const Color(0xFF2A2D33)
        : const Color(0xFFEEEEEE);
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black45;
    final sentTextColor = Colors.white;
    final receivedTextColor = isDark ? Colors.white : Colors.black87;
    final inputTextColor = isDark ? Colors.white : Colors.black;
    final hintColor = isDark ? Colors.white60 : Colors.black38;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 TOP BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: primaryTextColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
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
                    return Center(
                      child: CircularProgressIndicator(color: tealColor),
                    );
                  }

                  final messages = snapshot.data!.docs;

                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet. Say hi!',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg =
                          messages[index].data() as Map<String, dynamic>;
                      final String messageText = (msg['text'] ?? '').toString();

                      final isMe = msg['senderId'] == _currentUid;

                      final bubbleColor = isMe ? tealColor : otherBubbleColor;
                      final textColor = isMe
                          ? sentTextColor
                          : receivedTextColor;

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
                              : () => _showForwardContacts(msg),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.70,
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (msg['isForwarded'] == true)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.forward,
                                          size: 11,
                                          color: isMe
                                              ? Colors.white70
                                              : secondaryTextColor,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Forwarded',
                                          style: TextStyle(
                                            color: isMe
                                                ? Colors.white70
                                                : secondaryTextColor,
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (messageText.isNotEmpty)
                                  _MessageTextWithLinks(
                                    messageText: messageText,
                                    textColor: textColor,
                                    isDark: isDark,
                                    linkSafetyService: _linkSafetyService,
                                    onOpenUrl: _openMessageUrl,
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
                                      if (msg['attachmentType'] == 'image') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                FullScreenImageViewer(
                                                  imageUrl: url,
                                                  fileName:
                                                      msg['attachmentName'] ??
                                                      'Image',
                                                ),
                                          ),
                                        );
                                      } else {
                                        final uri = Uri.parse(url);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      }
                                    },
                                    child: msg['attachmentType'] == 'image'
                                        ? Container(
                                            constraints: const BoxConstraints(
                                              maxWidth: 240,
                                              maxHeight: 300,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Hero(
                                                tag:
                                                    msg['attachmentUrl']
                                                        as String,
                                                child: Image.network(
                                                  msg['attachmentUrl']
                                                      as String,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder:
                                                      (
                                                        context,
                                                        child,
                                                        loadingProgress,
                                                      ) {
                                                        if (loadingProgress ==
                                                            null)
                                                          return child;
                                                        return const SizedBox(
                                                          width: 50,
                                                          height: 50,
                                                          child: Center(
                                                            child:
                                                                CircularProgressIndicator(),
                                                          ),
                                                        );
                                                      },
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            constraints: const BoxConstraints(
                                              maxWidth: 260,
                                            ),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.08,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: 0.05,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      msg['attachmentType'] ==
                                                              'video'
                                                          ? Icons.videocam
                                                          : (msg['attachmentType'] ==
                                                                    'audio'
                                                                ? Icons
                                                                      .audiotrack
                                                                : Icons
                                                                      .insert_drive_file),
                                                      color: textColor,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        msg['attachmentName'] ??
                                                            'File',
                                                        style: TextStyle(
                                                          color: textColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: TextButton.icon(
                                                    onPressed: () async {
                                                      final url =
                                                          msg['attachmentUrl']
                                                              as String;
                                                      final uri = Uri.parse(
                                                        url,
                                                      );
                                                      if (await canLaunchUrl(
                                                        uri,
                                                      )) {
                                                        await launchUrl(
                                                          uri,
                                                          mode: LaunchMode
                                                              .externalApplication,
                                                        );
                                                      }
                                                    },
                                                    style: TextButton.styleFrom(
                                                      backgroundColor: textColor
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      foregroundColor:
                                                          textColor,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 6,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                    icon: Icon(
                                                      msg['attachmentType'] ==
                                                                  'pdf' ||
                                                              (msg['attachmentName'] ??
                                                                      '')
                                                                  .toLowerCase()
                                                                  .endsWith(
                                                                    '.pdf',
                                                                  )
                                                          ? Icons.picture_as_pdf
                                                          : Icons.open_in_new,
                                                      size: 16,
                                                    ),
                                                    label: Text(
                                                      msg['attachmentType'] ==
                                                                  'pdf' ||
                                                              (msg['attachmentName'] ??
                                                                      '')
                                                                  .toLowerCase()
                                                                  .endsWith(
                                                                    '.pdf',
                                                                  )
                                                          ? '📄 Open PDF'
                                                          : 'Open File',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: inputTextColor),
                        decoration: InputDecoration(
                          hintText: "Message",
                          hintStyle: TextStyle(color: hintColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: tealColor,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 22,
                            ),
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
  )
  onOpenUrl;

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
        final Map<String, LinkSafetyResult> safetyByUrl =
            <String, LinkSafetyResult>{};
        final List<LinkSafetyResult> results =
            snapshot.data ?? const <LinkSafetyResult>[];
        for (final result in results) {
          safetyByUrl[result.url] = result;
        }

        final List<InlineSpan> spans = <InlineSpan>[];
        int currentIndex = 0;

        for (final RegExpMatch match in _urlRegex.allMatches(messageText)) {
          final int start = match.start;
          final int end = match.end;
          final String rawUrl = messageText.substring(start, end);
          final List<String> normalizedCandidates = linkSafetyService
              .extractUrls(rawUrl);
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
