import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/connection_service.dart';
import '../widgets/glass_container.dart';

/// Screen for searching users by email and sending chat requests.
///
/// Previously this screen directly added contacts; now it sends a
/// mutual-consent request instead. The button state changes based on
/// the current request/connection status between the two users.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _emailController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ConnectionService _connectionService = ConnectionService();

  bool _isLoading = false;
  Map<String, dynamic>? _searchedUser;
  String? _errorMessage;

  /// Tracks the request status for the searched user:
  /// null = no interaction, 'sent' = request pending, 'received' = they sent to us,
  /// 'connected' = mutual connection exists.
  String? _requestStatus;

  void _searchUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchedUser = null;
      _requestStatus = null;
    });

    final user = await _chatService.searchUserByEmail(email);

    if (!mounted) return;

    if (user != null) {
      // Check existing request/connection status
      final status =
          await _connectionService.getRequestStatus(user['uid']);
      setState(() {
        _isLoading = false;
        _searchedUser = user;
        _requestStatus = status;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "User not found with this email.";
      });
    }
  }

  void _sendRequest() async {
    if (_searchedUser == null) return;

    setState(() => _isLoading = true);

    final result = await _connectionService.sendRequest(
      receiverUid: _searchedUser!['uid'],
      receiverName: _searchedUser!['displayName'] ?? 'User',
      receiverEmail: _searchedUser!['email'] ?? '',
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    final isSuccess = result['success'] == true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: isSuccess ? const Color(0xFF00A884) : Colors.redAccent,
      ),
    );

    if (isSuccess) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find People'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // ── Search bar ────────────────────────────────────
            GlassContainer(
              opacity: isDark ? 0.1 : 0.6,
              blur: 15,
              borderRadius: 16,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: "Enter user's email…",
                        hintStyle: TextStyle(
                            color: textColor.withValues(alpha: 0.5)),
                        border: InputBorder.none,
                        icon: Icon(Icons.search,
                            color: textColor.withValues(alpha: 0.5)),
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

            const SizedBox(height: 24),

            // ── Consent notice ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF00A884).withValues(alpha: 0.08),
                border: Border.all(
                  color: const Color(0xFF00A884).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user,
                      color: Color(0xFF00A884), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bit Chat requires mutual approval before messaging. '
                      'Send a request and wait for the other person to accept.',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.7),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Results ───────────────────────────────────────
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              const Color(0xFF00A884).withValues(alpha: 0.2),
                          child: Text(
                            (_searchedUser!['displayName'] ?? '?')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF00A884),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _searchedUser!['displayName'] ?? 'Unknown',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _searchedUser!['email'] ?? '',
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildActionButton(textColor),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Dynamically renders the correct button based on request status.
  Widget _buildActionButton(Color textColor) {
    switch (_requestStatus) {
      case 'connected':
        return _statusChip(
          icon: Icons.check_circle,
          label: 'Already Connected',
          color: const Color(0xFF00A884),
        );

      case 'sent':
        return _statusChip(
          icon: Icons.hourglass_top,
          label: 'Request Pending…',
          color: Colors.orange,
        );

      case 'received':
        // They sent us a request — sending ours will auto-accept (cross-request)
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.handshake),
            label: const Text('Accept & Connect'),
            onPressed: _sendRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A884),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        );

      default:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Send Request'),
            onPressed: _sendRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A884),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        );
    }
  }

  Widget _statusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}
