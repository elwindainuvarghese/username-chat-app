import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_request.dart';
import '../services/connection_service.dart';
import '../widgets/glass_container.dart';

/// Screen showing incoming and outgoing chat requests.
///
/// Tabs: Incoming | Outgoing
/// Incoming: Accept / Reject buttons
/// Outgoing: Cancel button
class ChatRequestsScreen extends StatefulWidget {
  const ChatRequestsScreen({super.key});

  @override
  State<ChatRequestsScreen> createState() => _ChatRequestsScreenState();
}

class _ChatRequestsScreenState extends State<ChatRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ConnectionService _connectionService = ConnectionService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Accept ─────────────────────────────────────────────────
  Future<void> _accept(String requestId) async {
    final result = await _connectionService.acceptRequest(requestId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor:
            result['success'] ? const Color(0xFF00A884) : Colors.redAccent,
      ),
    );
  }

  // ── Reject ─────────────────────────────────────────────────
  Future<void> _reject(String requestId) async {
    final result = await _connectionService.rejectRequest(requestId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? Colors.orange : Colors.redAccent,
      ),
    );
  }

  // ── Cancel ─────────────────────────────────────────────────
  Future<void> _cancel(String requestId) async {
    final result = await _connectionService.cancelRequest(requestId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? Colors.orange : Colors.redAccent,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    const accent = Color(0xFF00A884);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF0E0E1A) : const Color(0xFFF2F2F7),
        foregroundColor: textColor,
        elevation: 0,
        title: const Text('Chat Requests'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accent,
          labelColor: accent,
          unselectedLabelColor: textColor.withValues(alpha: 0.5),
          tabs: const [
            Tab(text: 'Incoming'),
            Tab(text: 'Outgoing'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIncoming(isDark, textColor),
          _buildOutgoing(isDark, textColor),
        ],
      ),
    );
  }

  // ── INCOMING TAB ───────────────────────────────────────────

  Widget _buildIncoming(bool isDark, Color textColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _connectionService.incomingRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState(
            icon: Icons.inbox_rounded,
            title: 'No incoming requests',
            subtitle: 'When someone sends you a request, it will appear here',
            textColor: textColor,
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final request = ChatRequest.fromDoc(docs[index]);

            // Skip expired requests visually
            if (request.isExpired) {
              return const SizedBox.shrink();
            }

            return GlassContainer(
              borderRadius: 16,
              opacity: isDark ? 0.1 : 0.55,
              blur: 12,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    backgroundColor:
                        const Color(0xFF00A884).withValues(alpha: 0.15),
                    child: Text(
                      request.senderName.isNotEmpty
                          ? request.senderName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFF00A884),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.senderName,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          request.senderEmail,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.55),
                            fontSize: 13,
                          ),
                        ),
                        if (request.createdAt != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            _timeAgo(request.createdAt!),
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.35),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionButton(
                        icon: Icons.check,
                        color: const Color(0xFF00A884),
                        tooltip: 'Accept',
                        onTap: () => _accept(request.id),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        icon: Icons.close,
                        color: Colors.redAccent,
                        tooltip: 'Reject',
                        onTap: () => _reject(request.id),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── OUTGOING TAB ───────────────────────────────────────────

  Widget _buildOutgoing(bool isDark, Color textColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _connectionService.outgoingRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState(
            icon: Icons.outbox_rounded,
            title: 'No outgoing requests',
            subtitle: 'Requests you send will appear here until accepted',
            textColor: textColor,
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final request = ChatRequest.fromDoc(docs[index]);

            return GlassContainer(
              borderRadius: 16,
              opacity: isDark ? 0.1 : 0.55,
              blur: 12,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.orange.withValues(alpha: 0.15),
                    child: Text(
                      request.receiverName.isNotEmpty
                          ? request.receiverName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.receiverName,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          request.receiverEmail,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.55),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: request.isExpired
                                    ? Colors.grey
                                    : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              request.isExpired ? 'Expired' : 'Pending…',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.45),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!request.isExpired)
                    _actionButton(
                      icon: Icons.cancel_outlined,
                      color: Colors.redAccent,
                      tooltip: 'Cancel request',
                      onTap: () => _cancel(request.id),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── HELPERS ────────────────────────────────────────────────

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: textColor.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  color: textColor.withValues(alpha: 0.5), fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textColor.withValues(alpha: 0.3), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
