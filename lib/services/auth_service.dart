import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // Use Ed25519 (Modern, fast, and very secure)
  final algorithm = Ed25519();
  final storage = const FlutterSecureStorage();

  // Key for storage
  static const _privateKeyStorageKey = 'user_private_key';
  static const _usernameStorageKey = 'user_display_name';

  /// Generates a new key pair and stores the private key securely.
  /// Returns the Base64 encoded public key (User ID).
  Future<String> registerNewUser({String? username}) async {
    // 1. Generate the Key Pair
    final keyPair = await algorithm.newKeyPair();

    // 2. Extract Keys
    // The Private Key (Keep this SAFE!)
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    // The Public Key (This becomes the User ID)
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBytes = publicKey.bytes;

    // 3. Store Private Key Securely
    // We encode it to Base64 to store it as a string
    await storage.write(
      key: _privateKeyStorageKey,
      value: base64Encode(privateKeyBytes),
    );

    if (username != null) {
      await storage.write(key: _usernameStorageKey, value: username);
    }

    // Log for verification
    final userId = base64Encode(publicKeyBytes);
    print("User Registered. ID: $userId");

    return userId;
  }

  /// Checks if a user is already registered (private key exists).
  Future<bool> isLoggedIn() async {
    final privateKey = await storage.read(key: _privateKeyStorageKey);
    return privateKey != null;
  }

  /// Retrieves the current user's Public Key (ID) if logged in.
  Future<String?> getPublicKey() async {
    final privateKeyBase64 = await storage.read(key: _privateKeyStorageKey);
    if (privateKeyBase64 == null) return null;

    try {
      final privateKeyBytes = base64Decode(privateKeyBase64);
      // Reconstruct key pair from private key bytes to get public key
      final keyPair = await algorithm.newKeyPairFromSeed(privateKeyBytes);
      final publicKey = await keyPair.extractPublicKey();
      return base64Encode(publicKey.bytes);
    } catch (e) {
      print("Error retrieving public key: $e");
      return null;
    }
  }

  Future<String?> getUsername() async {
    return await storage.read(key: _usernameStorageKey);
  }

  Future<void> saveUsername(String name) async {
    await storage.write(key: _usernameStorageKey, value: name);
  }

  /// Clear session (Logout logic if needed)
  Future<void> logout() async {
    await storage.delete(key: _privateKeyStorageKey);
    await storage.delete(key: _usernameStorageKey);
  }

  // ============== NEW AUTHENTICATION METHODS ==============
  // These are placeholder methods for Firebase integration later
  
  /// Login with username and password
  /// TODO: Connect to Firebase Authentication
  Future<Map<String, dynamic>> login(String username, String password) async {
    // Placeholder implementation
    // Firebase will handle password verification
    print("LOGIN: Username: $username, Password: [HIDDEN]");
    
    // Mock delay for UI testing
    await Future.delayed(const Duration(seconds: 2));
    
    // For now, simulate successful login
    // TODO: Replace with Firebase Auth login logic
    await saveUsername(username);
    await storage.write(key: _privateKeyStorageKey, value: 'mock_private_key');
    
    return {
      'success': true,
      'message': 'Login successful',
      'user': {'username': username}
    };
  }
  
  /// Sign up new user with username and password
  /// TODO: Connect to Firebase Authentication  
  Future<Map<String, dynamic>> signup(String username, String password, String confirmPassword) async {
    // Placeholder implementation
    print("SIGNUP: Username: $username");
    
    // Basic validation
    if (password != confirmPassword) {
      return {
        'success': false,
        'message': 'Passwords do not match'
      };
    }
    
    if (username.trim().isEmpty || password.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Username and password cannot be empty'
      };
    }
    
    // Mock delay for UI testing
    await Future.delayed(const Duration(seconds: 2));
    
    // TODO: Replace with Firebase Auth signup logic
    // For now, create the user locally
    final userId = await registerNewUser(username: username);
    
    return {
      'success': true,
      'message': 'Account created successfully',
      'user': {'username': username, 'userId': userId}
    };
  }
  
  /// Recover account using recovery phrase
  /// TODO: Connect to Firebase and recovery phrase logic
  Future<Map<String, dynamic>> recoverWithPhrase(String recoveryPhrase) async {
    print("RECOVER: Recovery phrase provided");
    
    // Basic validation
    final words = recoveryPhrase.trim().split(RegExp(r'\s+'));
    if (words.length != 16) {
      return {
        'success': false,
        'message': 'Recovery phrase must contain exactly 16 words'
      };
    }
    
    // Mock delay for UI testing
    await Future.delayed(const Duration(seconds: 3));
    
    // TODO: Replace with actual recovery phrase validation
    // For now, simulate successful recovery
    await saveUsername('RecoveredUser');
    await storage.write(key: _privateKeyStorageKey, value: 'recovered_private_key');
    
    return {
      'success': true,
      'message': 'Account recovered successfully',
      'user': {'username': 'RecoveredUser'}
    };
  }
  
  /// Generate mock recovery phrase (16 words)
  /// TODO: Replace with actual cryptographic recovery phrase generation
  List<String> generateRecoveryPhrase() {
    // Mock word list for demonstration (BIP39 style words)
    final words = [
      'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 
      'abstract', 'absurd', 'abuse', 'access', 'accident', 'account', 
      'accuse', 'achieve', 'acid', 'acoustic', 'acquire', 'across', 'act',
      'action', 'actor', 'actress', 'actual', 'adapt', 'add', 'addict', 
      'address', 'adjust', 'admit', 'adult', 'advance', 'advice', 'aerobic', 
      'affair', 'afford', 'afraid', 'again', 'against', 'agent', 'agree',
      'ahead', 'aim', 'air', 'airport', 'aisle', 'alarm', 'album', 'alcohol',
      'alert', 'alien', 'all', 'alley', 'allow', 'almost', 'alone', 'alpha',
      'already', 'also', 'alter', 'always', 'amateur', 'amazing', 'among',
      'amount', 'amused', 'analyst', 'anchor', 'ancient', 'anger', 'angle',
      'angry', 'animal', 'ankle', 'announce', 'annual', 'another', 'answer',
      'antenna', 'antique', 'anxiety', 'any', 'apart', 'apology', 'appear',
      'apple', 'approve', 'april', 'area', 'arena', 'argue', 'arm', 'armed',
      'armor', 'army', 'around', 'arrange', 'arrest', 'arrive', 'arrow', 
      'art', 'article', 'artist', 'artwork', 'ask', 'aspect', 'assault', 
      'asset', 'assist', 'assume', 'asthma', 'athlete', 'atom', 'attack'
    ];
    
    // Create a proper random instance with a seed for this user session
    final random = Random(DateTime.now().microsecondsSinceEpoch);
    
    // Generate 16 unique random words
    final phrase = <String>[];
    final usedIndices = <int>{}; // To ensure no duplicate words
    
    while (phrase.length < 16) {
      final index = random.nextInt(words.length);
      if (!usedIndices.contains(index)) {
        usedIndices.add(index);
        phrase.add(words[index]);
      }
    }
    
    print("GENERATED RECOVERY PHRASE: ${phrase.join(' ')}");
    print("FIRST 3 WORDS: ${phrase.take(3).join(', ')}"); // Extra debug
    return phrase;
  }
}
