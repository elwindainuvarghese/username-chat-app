import 'package:flutter/material.dart';
import 'new_chat_screen.dart';
import 'calls_screen.dart';
import 'settings_screen.dart'; // NEW
import 'image_detection_screen.dart';
import '../widgets/glass_container.dart';
import '../services/auth_service.dart';
import 'welcome_screen.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
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

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  void _showLogoutDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Logout",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox(); // Placeholder, we use transitionBuilder
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.elasticOut);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = Theme.of(context).colorScheme.onSurface;

        return ScaleTransition(
          scale: curve,
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            contentPadding: EdgeInsets.zero,
            content: GlassContainer(
              borderRadius: 24,
              blur: 35, // Increased blur for premium feel
              opacity: isDark ? 0.05 : 0.65, // More transparent
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              color: isDark ? Colors.black : Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: Colors.redAccent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Text
                  Text(
                    "Sorry to see you go 😢",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Are you sure you want to log out of Bit Chat?",
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: textColor.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleLogout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            "Logout",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Chats Tab Content (WhatsApp Style)
  Widget _buildChatsTab() {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 1. Search Pill "Ask Meta AI or Search"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GlassContainer(
            opacity: isDark ? 0.1 : 0.6,
            blur: 15,
            borderRadius: 50, // Pill Shape
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(
              children: [
                // Icon(Icons.circle_outlined, color: Colors.blueAccent), // Meta AI Ring (Placeholder)
                Image.asset(
                  'images/icon.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (c, e, s) =>
                      Icon(Icons.auto_awesome, color: textColor),
                ),
                const SizedBox(width: 12),
                Text(
                  "Ask Meta AI or Search",
                  style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. Filter Chips (All, Unread, Favorites, Groups)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildGlassChip("All", true),
              const SizedBox(width: 8),
              _buildGlassChip("Unread", false),
              const SizedBox(width: 8),
              _buildGlassChip("Favorites", false),
              const SizedBox(width: 8),
              _buildGlassChip("Groups", false),
              const SizedBox(width: 8),
              // Add icon placeholder
              GlassContainer(
                opacity: isDark ? 0.1 : 0.4,
                borderRadius: 20,
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),

        // 3. Chat List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: 8,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  // Use defaults for Frosty Look: Blur 25, Opacity 0.12, Border 1.2
                  borderRadius: 18,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {}, // Go to Chat
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                color: textColor.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(width: 15),

                            // Name & Msg
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    index == 0
                                        ? "$_username (You)"
                                        : "User ${index + 1}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    index == 0
                                        ? "Message to yourself"
                                        : "Hey, are you free tonight?",
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Time & Status
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "10:30 PM",
                                  style: TextStyle(
                                    color: index == 1
                                        ? const Color(0xFF00A884)
                                        : textColor.withOpacity(
                                            0.4,
                                          ), // Green if unread
                                    fontSize: 12,
                                    fontWeight: index == 1
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (index == 0)
                                  Icon(
                                    Icons.push_pin,
                                    size: 16,
                                    color: textColor.withOpacity(0.5),
                                  ),
                                if (index == 1)
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00A884),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "2",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGlassChip(String label, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return GlassContainer(
      opacity: isSelected ? (isDark ? 0.2 : 0.8) : (isDark ? 0.05 : 0.4),
      blur: 5,
      borderRadius: 20,

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isSelected
          ? const Color(0xFF00A884)
          : Colors.white, // Green tint if selected
      child: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? const Color(0xFF00A884)
              : textColor.withOpacity(0.7),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // Get current screen based on selected index
  Widget _getCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildChatsTab();
      case 1:
        return const Center(child: Text("Updates")); // Placeholder
      case 2:
        return const Center(child: Text("Communities")); // Placeholder
      case 3:
        return const CallsScreen();
      default:
        return _buildChatsTab();
    }
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine gradient based on theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Background Gradient
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
            bottom: false,
            child: Column(
              children: [
                // Custom App Bar Row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Bit Chat', // Renamed from WhatsApp
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      // Image Detection Button
                      IconButton(
                        tooltip: 'Detail AI',
                        icon: const Icon(Icons.image_search_rounded),
                        color: textColor,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ImageDetectionScreen(),
                            ),
                          );
                        },
                      ),
                      // Theme Toggle
                      IconButton(
                        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                        color: textColor,
                        onPressed: () {
                          themeNotifier.toggleTheme();
                        },
                      ),
                      // Popup Menu (Settings, Logout)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: textColor),
                        color: isDark ? const Color(0xFF1F1F2E) : Colors.white,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: (value) {
                          if (value == 'settings') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          } else if (value == 'logout') {
                            _showLogoutDialog();
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'settings',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.settings,
                                      color: textColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Settings',
                                      style: TextStyle(color: textColor),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.logout,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Logout',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(child: _getCurrentScreen()),
              ],
            ),
          ),
        ],
      ),

      // FAB (Green Square-ish)
      floatingActionButton: _selectedIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NewChatScreen()),
                  );
                },
                backgroundColor: const Color(0xFF00A884), // WhatsApp Green
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ), // Squircle
                child: const Icon(Icons.add_comment, color: Colors.black),
              ),
            )
          : null,

      // Bottom Navigation
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(left: 10, right: 10, bottom: 20, top: 0),
        color: Colors.transparent,
        child: GlassContainer(
          borderRadius: 30,
          blur: 25,
          opacity: isDark ? 0.15 : 0.65,
          borderGradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.4),
              Colors.white.withOpacity(0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(Icons.chat, 0, "Chats", isDark),
              _buildNavItem(Icons.update, 1, "Updates", isDark),
              _buildNavItem(Icons.groups, 2, "Communities", isDark),
              _buildNavItem(Icons.call, 3, "Calls", isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, String label, bool isDark) {
    final isSelected = _selectedIndex == index;
    // WhatsApp style bottom nav has labels
    return GestureDetector(
      onTap: () => _onBottomNavTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: isSelected
                ? BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: Icon(
              icon,
              size: 24,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
