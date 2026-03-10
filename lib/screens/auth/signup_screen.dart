import 'package:flutter/material.dart';
import '../../widgets/glass_container.dart';
import '../../services/auth_service.dart';
import 'recovery_phrase_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final AuthService _authService;
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authService.signup(
        _emailController.text.trim(),
        _usernameController.text.trim(),
        _passwordController.text,
        _confirmPasswordController.text,
      );

      if (result['success']) {
        if (mounted) {
          // Navigate to recovery phrase screen after successful signup
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RecoveryPhraseScreen(
                username: _usernameController.text.trim(),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          _showErrorDialog(result['message'] ?? 'Signup failed');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An error occurred. Please try again.\n\nDetails: $e');
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F1F2E) : Colors.white,
          title: Text(
            'Signup Error',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: SelectableText(
            message,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Stack(
            children: [
              // Background Effects (matching login screen style)
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
                          const Color(0xFF7F00FF).withOpacity(0.5),
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

              // Main Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_ios,
                          color: textColor,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark 
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Title
                      Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'Join BitChat and start connecting',
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Signup Form
                      GlassContainer(
                        blur: 20,
                        opacity: isDark ? 0.1 : 0.6,
                        borderRadius: 24,
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                style: TextStyle(color: textColor),
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  labelStyle: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (value) {
                                  if (value?.trim().isEmpty ?? true) {
                                    return 'Please enter your email';
                                  }
                                  if (!value!.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // Username Field
                              TextFormField(
                                controller: _usernameController,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  labelStyle: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (value) {
                                  if (value?.trim().isEmpty ?? true) {
                                    return 'Please enter a username';
                                  }
                                  if (value!.trim().length < 3) {
                                    return 'Username must be at least 3 characters';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    },
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Please enter a password';
                                  }
                                  if (value!.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // Confirm Password Field
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: !_isConfirmPasswordVisible,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  labelStyle: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                      });
                                    },
                                    icon: Icon(
                                      _isConfirmPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 32),

                              // Create Account Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSignup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? Colors.white : Colors.black,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              isDark ? Colors.black : Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Text(
                                          'Create Account',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Terms and Privacy Note
                              Text(
                                'By creating an account, you agree to our Terms of Service and Privacy Policy.',
                                style: TextStyle(
                                  color: textColor.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
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
  }
}