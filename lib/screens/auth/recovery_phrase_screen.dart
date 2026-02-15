import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/glass_container.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';

class RecoveryPhraseScreen extends StatefulWidget {
  final String username;
  
  const RecoveryPhraseScreen({
    super.key,
    required this.username,
  });

  @override
  State<RecoveryPhraseScreen> createState() => _RecoveryPhraseScreenState();
}

class _RecoveryPhraseScreenState extends State<RecoveryPhraseScreen> {
  final AuthService _authService = AuthService();
  List<String> _recoveryPhrase = [];
  bool _isPhraseCopied = false;
  bool _isPhraseConfirmed = false;

  @override
  void initState() {
    super.initState();
    // Generate phrase in initState
    _generatePhrase();
  }

  void _generatePhrase() {
    setState(() {
      _recoveryPhrase = _authService.generateRecoveryPhrase();
    });
    print("UI Recovery phrase: $_recoveryPhrase"); // Debug log
    print("Phrase length: ${_recoveryPhrase.length}"); // Debug log
  }

  void _copyRecoveryPhrase() {
    if (_recoveryPhrase.isEmpty) {
      _showErrorSnackBar('Recovery phrase not ready yet');
      return;
    }
    
    final phraseText = _recoveryPhrase.join(' ');
    Clipboard.setData(ClipboardData(text: phraseText));
    
    setState(() => _isPhraseCopied = true);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recovery phrase copied: ${_recoveryPhrase.length} words'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _confirmAndProceed() {
    if (!_isPhraseConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please confirm that you have saved your recovery phrase'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Navigate to home screen after confirmation
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
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
              // Background Effects
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
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Section
                      Text(
                        'Your Recovery Phrase',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      
                      const SizedBox(height: 6),
                      
                      Text(
                        'These 16 words are the keys to your account. Store them safely!',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),

                      // Debug info (can be removed later)
                      if (_recoveryPhrase.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Generating recovery phrase...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Warning Section
                      GlassContainer(
                        blur: 20,
                        opacity: isDark ? 0.1 : 0.6,
                        borderRadius: 16,
                        padding: const EdgeInsets.all(16),
                        color: Colors.orange,
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Important!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Write these words down and store them safely. This is the only way to recover your account.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Recovery Phrase Grid (using Expanded to prevent overflow)
                      Expanded(
                        child: GlassContainer(
                          blur: 20,
                          opacity: isDark ? 0.1 : 0.6,
                          borderRadius: 24,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // 4x4 Grid of words
                              Expanded(
                                child: GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 6,
                                    mainAxisSpacing: 6,
                                    childAspectRatio: 2.2,
                                  ),
                                  itemCount: 16,
                                  itemBuilder: (context, index) {
                                    final word = index < _recoveryPhrase.length 
                                        ? _recoveryPhrase[index] 
                                        : 'loading...';
                                        
                                    return GlassContainer(
                                      blur: 10,
                                      opacity: isDark ? 0.15 : 0.3,
                                      borderRadius: 10,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 8,
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: textColor.withOpacity(0.6),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Flexible(
                                            child: Text(
                                              word,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Copy Button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _copyRecoveryPhrase,
                                  icon: Icon(
                                    _isPhraseCopied ? Icons.check : Icons.copy,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _isPhraseCopied ? 'Copied!' : 'Copy to Clipboard',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    foregroundColor: _isPhraseCopied ? Colors.green : textColor,
                                    side: BorderSide(
                                      color: _isPhraseCopied 
                                          ? Colors.green 
                                          : textColor.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Confirmation Checkbox
                      GlassContainer(
                        blur: 20,
                        opacity: isDark ? 0.1 : 0.6,
                        borderRadius: 16,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _isPhraseConfirmed,
                              onChanged: (value) {
                                setState(() => _isPhraseConfirmed = value ?? false);
                              },
                              activeColor: isDark ? Colors.white : Colors.black,
                              checkColor: isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'I have safely stored my recovery phrase and understand that I will need it to recover my account.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textColor.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Continue Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirmAndProceed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isPhraseConfirmed 
                                ? (isDark ? Colors.white : Colors.black)
                                : textColor.withOpacity(0.3),
                            foregroundColor: _isPhraseConfirmed
                                ? (isDark ? Colors.black : Colors.white)
                                : textColor.withOpacity(0.7),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'I have saved it',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
  }
}