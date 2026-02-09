import 'dart:convert';
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
}
