import 'dart:ui';
import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import '../widgets/glass_container.dart';
import '../main.dart'; // For themeNotifier

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: Stack(
        children: [
          // Ambient Background
          if (isDark) ...[
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: size.width * 1.2,
                height: size.width * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7F00FF).withOpacity(0.5), // Violet
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: -50,
              child: Container(
                width: size.width,
                height: size.width,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.blueAccent.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Noise/blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                color: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withOpacity(0.6),
              ),
            ),
          ),

          // Theme Toggle
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: textColor,
                size: 28,
              ),
              onPressed: () {
                themeNotifier.toggleTheme();
              },
            ),
          ),

          // Main Content - Floating Glass Card
          Center(
            child: SingleChildScrollView(
              // Safety for small screens
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: GlassContainer(
                    blur: 25,
                    opacity: isDark ? 0.1 : 0.4,
                    borderRadius: 30,
                    borderGradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Beyond\nMessaging',
                          style: TextStyle(
                            fontSize: 42,
                            height: 1.1,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Experience the future of secure communication. No servers. No traces. Just you and them.',
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor.withOpacity(0.7),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Embedded Feature Grid (Simplified to fit inside card)
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: textColor.withOpacity(0.7),
                                size: 30,
                              ),
                              Text(
                                "End-to-End\nEncryption",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textColor.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: Colors.white24,
                              ),
                              Icon(
                                Icons.bolt_outlined,
                                color: textColor.withOpacity(0.7),
                                size: 30,
                              ),
                              Text(
                                "Ed25519\nIdentity",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textColor.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Get Started Button (Login)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const LoginScreen(),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    },
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: isDark ? Colors.white : Colors.black,
                              boxShadow: [
                                BoxShadow(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                "Login",
                                style: TextStyle(
                                  color: isDark ? Colors.black : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Create Account Button
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const SignupScreen(),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    },
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.3) 
                                              : Colors.black.withOpacity(0.3),
                                width: 1.5,
                              ),
                              color: Colors.transparent,
                            ),
                            child: Center(
                              child: Text(
                                "Create Account",
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
