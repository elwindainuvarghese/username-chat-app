import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app());
  final FirebaseAuth _auth = FirebaseAuth.instanceFor(app: Firebase.app());

  /// Generate a consistent Chat Room ID given two User IDs
  String getChatRoomId(String uid1, String uid2) {
    List<String> userIds = [uid1, uid2];
    userIds.sort();
    return userIds.join('_');
  }

  /// Search for a user by email
  Future<Map<String, dynamic>?> searchUserByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print("Error searching user: $e");
      return null;
    }
  }

  /// Add a user to the current user's contacts sub-collection
  Future<bool> addContact(String contactUid, String contactEmail, String contactName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    // Prevent adding oneself
    if (currentUser.uid == contactUid) return false;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('contacts')
          .doc(contactUid)
          .set({
        'uid': contactUid,
        'email': contactEmail,
        'displayName': contactName,
        'addedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print("Error adding contact: $e");
      return false;
    }
  }

  /// Stream of user's contacts
  Stream<QuerySnapshot> getContactsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('contacts')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  /// Send a message in a 1-on-1 chat room
  Future<void> sendMessage(String receiverId, String receiverName, String messageText) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatRoomId = getChatRoomId(currentUser.uid, receiverId);

    // 1. Create or update the Chat Room metadata
    await _firestore.collection('chatRooms').doc(chatRoomId).set({
      'participants': [currentUser.uid, receiverId],
      'lastMessage': messageText,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Add message to messages sub-collection
    await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .add({
      'senderId': currentUser.uid,
      'text': messageText,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get messages stream for a specific chat room
  Stream<QuerySnapshot> getMessages(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
