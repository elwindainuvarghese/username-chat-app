import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/anonymous_chat_service.dart';

/// Full-screen anonymous chat.
///
/// Privacy features:
/// • Real names / emails are never shown — only random aliases.
/// • The top bar shows a 🔒 icon and the partner's alias.
/// • When the user presses Back or the "End & Erase" button the
///   entire room (+ all messages) are permanently deleted from Firestore.
/// • A "self-destruct" banner is visible at all times.
class AnonymousChatScreen extends StatefulWidget {
  final String roomId;
  final String myAlias;
  final String partnerAlias;

  const AnonymousChatScreen({
    super.key,
    required this.roomId,
    required this.myAlias,
    required this.partnerAlias,
  });

  @override
  State<AnonymousChatScreen> createState() => _AnonymousChatScreenState();
}

class _AnonymousChatScreenState extends State<AnonymousChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AnonymousChatService _anonService = AnonymousChatService();
  bool _isDestroyed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    // Auto-destroy when screen is disposed (back button, etc.)
    if (!_isDestroyed) {
      _anonService.destroyRoom(widget.roomId);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Also destroy if the app goes to background (extra safety)
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!_isDestroyed) {
        _isDestroyed = true;
        _anonService.destroyRoom(widget.roomId);
      }
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await _anonService.sendMessage(widget.roomId, text);
  }

  Future<void> _endAndErase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.delete_forever, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                'End & Erase Chat',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'All messages in this anonymous chat will be permanently deleted. '
            'This action cannot be undone.',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Erase', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _isDestroyed = true;
      await _anonService.destroyRoom(widget.roomId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colour palette
    final bgColor = isDark ? const Color(0xFF0A0A14) : const Color(0xFFF2F2F7);
    final surfaceColor =
        isDark ? const Color(0xFF16162A) : const Color(0xFFEAEAF0);
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final primaryText = isDark ? Colors.white : Colors.black;
    final secondaryText = isDark ? Colors.white54 : Colors.black45;
    const accentPurple = Color(0xFF7C4DFF);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Room destruction is already handled in dispose()
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── TOP BAR ──────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF12122A)
                      : const Color(0xFFE8E0F0),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: primaryText),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    // Anonymous avatar
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [accentPurple, Color(0xFFB388FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentPurple.withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.theater_comedy,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.partnerAlias,
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.lock,
                                  size: 12, color: accentPurple),
                              const SizedBox(width: 4),
                              Text(
                                'Anonymous · Encrypted',
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // End & Erase button
                    IconButton(
                      tooltip: 'End & Erase Chat',
                      icon: const Icon(Icons.delete_forever,
                          color: Colors.redAccent),
                      onPressed: _endAndErase,
                    ),
                  ],
                ),
              ),

              // ── SELF-DESTRUCT BANNER ──────────────────────────────
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentPurple.withValues(alpha: 0.15),
                      Colors.redAccent.withValues(alpha: 0.08),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: accentPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Messages auto-erase when you leave this chat',
                        style: TextStyle(
                          color: primaryText.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── MESSAGES ──────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _anonService.getMessages(widget.roomId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline,
                                size: 48,
                                color: primaryText.withValues(alpha: 0.2)),
                            const SizedBox(height: 12),
                            Text(
                              'Private conversation started',
                              style: TextStyle(
                                color: primaryText.withValues(alpha: 0.4),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final messages = snapshot.data!.docs;

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_off,
                                size: 48,
                                color: primaryText.withValues(alpha: 0.2)),
                            const SizedBox(height: 12),
                            Text(
                              'Say something anonymously…',
                              style: TextStyle(
                                color: primaryText.withValues(alpha: 0.4),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg =
                            messages[index].data() as Map<String, dynamic>;
                        final isMe =
                            msg['senderId'] == _anonService.currentUid;
                        final text = (msg['text'] ?? '').toString();

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              gradient: isMe
                                  ? const LinearGradient(
                                      colors: [
                                        accentPurple,
                                        Color(0xFF9C27B0)
                                      ],
                                    )
                                  : null,
                              color: isMe ? null : surfaceColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMe ? 18 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isMe
                                          ? accentPurple
                                          : Colors.black)
                                      .withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // alias label
                                Text(
                                  isMe
                                      ? widget.myAlias
                                      : widget.partnerAlias,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isMe
                                        ? Colors.white70
                                        : accentPurple.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  text,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : primaryText,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // ── INPUT ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF12122A)
                      : const Color(0xFFE8E0F0),
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: accentPurple.withValues(alpha: 0.25),
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(color: primaryText),
                          decoration: InputDecoration(
                            hintText: 'Type anonymously…',
                            hintStyle: TextStyle(color: secondaryText),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.visibility_off,
                                size: 18, color: secondaryText),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [accentPurple, Color(0xFF9C27B0)],
                        ),
                      ),
                      child: IconButton(
                        icon:
                            const Icon(Icons.send_rounded, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
