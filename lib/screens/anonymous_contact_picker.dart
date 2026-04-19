import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/anonymous_chat_service.dart';
import '../widgets/glass_container.dart';
import 'anonymous_chat_screen.dart';

/// "Pick a contact" screen that launches an Anonymous Chat.
class AnonymousContactPicker extends StatefulWidget {
  const AnonymousContactPicker({super.key});

  @override
  State<AnonymousContactPicker> createState() =>
      _AnonymousContactPickerState();
}

class _AnonymousContactPickerState extends State<AnonymousContactPicker> {
  final AnonymousChatService _anonService = AnonymousChatService();
  bool _isLoading = false;

  Future<void> _startAnonymousChat(String partnerUid) async {
    setState(() => _isLoading = true);

    try {
      final room = await _anonService.createRoom(partnerUid);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AnonymousChatScreen(
            roomId: room['roomId']!,
            myAlias: room['myAlias']!,
            partnerAlias: room['partnerAlias']!,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start anonymous chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    const accentPurple = Color(0xFF7C4DFF);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF12122A)
                    : const Color(0xFFE8E0F0),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [accentPurple, Color(0xFFB388FF)],
                      ),
                    ),
                    child: const Icon(Icons.theater_comedy,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anonymous Chat',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose a contact to chat privately',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Privacy notice ──────────────────────────────────────
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    accentPurple.withValues(alpha: 0.12),
                    Colors.deepPurple.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(
                  color: accentPurple.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield, color: accentPurple, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your identity stays hidden. Random aliases are assigned. '
                      'All messages are erased when either person leaves.',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.7),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Contact list ────────────────────────────────────────
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: accentPurple),
                      SizedBox(height: 16),
                      Text(
                        'Setting up anonymous room…',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _anonService.getContactsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child:
                              CircularProgressIndicator(color: accentPurple));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_off,
                                size: 56,
                                color: textColor.withValues(alpha: 0.25)),
                            const SizedBox(height: 12),
                            Text(
                              'No contacts yet',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.5),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add friends first from the home screen',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.35),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final contacts = snapshot.data!.docs;

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: contacts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final contact =
                            contacts[index].data() as Map<String, dynamic>;
                        final name =
                            contact['displayName'] ?? 'Unknown User';

                        return GlassContainer(
                          borderRadius: 16,
                          opacity: isDark ? 0.1 : 0.5,
                          blur: 12,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () =>
                                  _startAnonymousChat(contact['uid']),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    // Masked avatar
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            accentPurple.withValues(
                                                alpha: 0.6),
                                            const Color(0xFFB388FF)
                                                .withValues(alpha: 0.4),
                                          ],
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.person_outline,
                                        color: Colors.white
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Tap to start anonymous chat',
                                            style: TextStyle(
                                              color: accentPurple.withValues(
                                                  alpha: 0.7),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios,
                                        size: 16,
                                        color:
                                            textColor.withValues(alpha: 0.3)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
