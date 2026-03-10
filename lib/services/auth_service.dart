import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instanceFor(app: Firebase.app());
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app());
  final storage = const FlutterSecureStorage();

  static const _usernameStorageKey = 'user_display_name';

  Future<void> saveUsername(String name) async {
    await storage.write(key: _usernameStorageKey, value: name);
  }

  Future<String?> getUsername() async {
    final user = _auth.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName;
      }
      // Fetch from firestore if not in Auth object
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return doc.data()?['displayName'] as String?;
        }
      } catch (e) {
        // ignore
      }
    }
    return await storage.read(key: _usernameStorageKey);
  }

  /// Expose the stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up new user with email, password, and username
  Future<Map<String, dynamic>> signup(String email, String username, String password, String confirmPassword) async {
    if (password != confirmPassword) {
      return {'success': false, 'message': 'Passwords do not match'};
    }
    
    if (email.trim().isEmpty || username.trim().isEmpty || password.trim().isEmpty) {
      return {'success': false, 'message': 'All fields are required'};
    }

    try {
      // 1. Create Auth User
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), 
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // 2. Update Auth display name
        await user.updateDisplayName(username.trim());
        // For waiting for changes
        await user.reload(); 
        
        // 3. Create Firestore User Document
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email.trim(),
          'displayName': username.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        await saveUsername(username.trim());
        return {'success': true, 'message': 'Account created successfully', 'user': user};
      }
      return {'success': false, 'message': 'Failed to create user account (user object was null)'};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': 'Firebase Error [${e.code}]: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': 'System Error: ${e.toString()}'};
    }
  }

  /// Login with email and password
  Future<Map<String, dynamic>> login(String email, String password) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      return {'success': false, 'message': 'Email and password are required'};
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        final username = user.displayName;
        if (username != null) {
          await saveUsername(username);
        } else {
            // Fetch username from Firestore if it's missing in Firebase Auth object
            final doc = await _firestore.collection('users').doc(user.uid).get();
            if (doc.exists && doc.data()!['displayName'] != null) {
                await saveUsername(doc.data()!['displayName']);
            }
        }
        return {'success': true, 'message': 'Login successful', 'user': user};
      }
      return {'success': false, 'message': 'Failed to login'};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': e.message ?? 'Invalid email or password'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Log out
  Future<void> logout() async {
    await _auth.signOut();
    await storage.delete(key: _usernameStorageKey);
  }

  // ============== MOCK RECOVERY METHODS FOR EXISTING UI ==============
  // Keeping these so the UI doesn't break, though they will be unused in Firebase Auth
  
  Future<Map<String, dynamic>> recoverWithPhrase(String recoveryPhrase) async {
    return {
      'success': false,
      'message': 'Account recovery via phrase is deprecated. Please use Firebase Auth password reset.'
    };
  }
  
  List<String> generateRecoveryPhrase() {
    final words = [
      'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 
      'abstract', 'absurd', 'abuse', 'access', 'accident', 'account', 
      'accuse', 'achieve', 'acid', 'acoustic', 'acquire', 'across', 'act',
    ];
    final random = Random(DateTime.now().microsecondsSinceEpoch);
    final phrase = <String>[];
    final usedIndices = <int>{};
    
    while (phrase.length < 16) {
      final index = random.nextInt(words.length);
      if (!usedIndices.contains(index)) {
        usedIndices.add(index);
        phrase.add(words[index]);
      }
    }
    return phrase;
  }
}
