import 'package:flutter/material.dart';
import '../widgets/glass_container.dart';
import '../services/auth_service.dart';
// For themes

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  String _username = 'User';

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final name = await _authService.getUsername();
    if (name != null) {
      if (mounted) setState(() => _username = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    // WhatsApp Colors (Dark Mode reference, adapted to Glass)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      // Keep existing gradient background from main.dart via Scaffold transparency or just let it inherit
      // To ensure continuity, we usually rely on the scaffold background set in Theme.
      // But we can add a subtle gradient overlay if we want "GlassApp" feel.
      body: Stack(
        children: [
          // Subtle Background Gradient (Consistent with Home)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF141414),
                          const Color(0xFF0F0F1E),
                        ] // Dark Mesh
                      : [
                          const Color(0xFFF0F0F5),
                          const Color(0xFFE0E5EC),
                        ], // Light Mesh
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. Header (AppBar substitute)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: textColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Settings",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.search, color: textColor),
                    ],
                  ),
                ),

                // 2. Profile Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 20,
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.withOpacity(0.3),
                            image: const DecorationImage(
                              image: AssetImage(
                                'images/avatar_placeholder.png',
                              ), // Fallback
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Name & Status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _username,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Hey there! I use Bit Chat.",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColor.withOpacity(0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // QR & Dropdown
                        Row(
                          children: [
                            Icon(Icons.qr_code, color: const Color(0xFF00A884)),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: const Color(0xFF00A884),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Settings List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    children: [
                      _buildSettingsItem(
                        Icons.key,
                        "Account",
                        "Security notifications, change number",
                        context,
                      ),
                      _buildSettingsItem(
                        Icons.lock_outline,
                        "Privacy",
                        "Block contacts, disappearing messages",
                        context,
                      ),
                      _buildSettingsItem(
                        Icons.face,
                        "Avatar",
                        "Create, edit, profile photo",
                        context,
                      ),
                      _buildSettingsItem(
                        Icons.list,
                        "Lists",
                        "Manage people and groups",
                        context,
                      ),
                      _buildSettingsItem(
                        Icons.chat_bubble_outline,
                        "Chats",
                        "Theme, wallpapers, chat history",
                        context,
                      ),
                      _buildSettingsItem(
                        Icons.broadcast_on_personal,
                        "Broadcasts",
                        "Message, group & call tones",
                        context,
                      ),
                      _buildSettingsItem(
                        Icons.notifications_none,
                        "Notifications",
                        "Message, group & call tones",
                        context,
                      ),
                      _buildSettingsItem(
                        Icons.data_usage,
                        "Storage and data",
                        "Network usage, auto-download",
                        context,
                      ),
                      _buildSettingsItem(
                        Icons.language,
                        "App language",
                        "English (device's language)",
                        context,
                      ),
                      _buildSettingsItem(
                        Icons.help_outline,
                        "Help and feedback",
                        "Help center, contact us, privacy policy",
                        context,
                      ),
                      _buildSettingsItem(
                        Icons.group_add_outlined,
                        "Invite a friend",
                        "",
                        context,
                      ),

                      const SizedBox(height: 30),

                      // Footer
                      Column(
                        children: [
                          Text(
                            "from",
                            style: TextStyle(
                              color: textColor.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.link,
                                size: 16,
                                color: textColor.withOpacity(0.7),
                              ), // Meta logo placeholder
                              const SizedBox(width: 4),
                              Text(
                                "Meta",
                                style: TextStyle(
                                  color: textColor.withOpacity(0.7),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "Accounts Center",
                            style: TextStyle(
                              color: textColor.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    IconData icon,
    String title,
    String subtitle,
    BuildContext context,
  ) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassContainer(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: textColor.withOpacity(0.7), size: 24),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: textColor.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}
