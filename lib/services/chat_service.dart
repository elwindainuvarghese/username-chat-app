import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
  );
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
  Future<bool> addContact(
    String contactUid,
    String contactEmail,
    String contactName,
  ) async {
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
  Future<void> sendMessage(
    String receiverId,
    String receiverName,
    String messageText,
  ) async {
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

  /// Send an attachment in a 1-on-1 chat room
  Future<void> sendAttachment(
    String receiverId,
    String receiverName,
    Uint8List fileBytes,
    String attachmentName,
    String attachmentType,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatRoomId = getChatRoomId(currentUser.uid, receiverId);
    final storage = FirebaseStorage.instanceFor(app: Firebase.app());
    final storageRef = storage.ref().child(
      'chatRooms/$chatRoomId/attachments/${DateTime.now().millisecondsSinceEpoch}_$attachmentName',
    );

    final contentType = _getContentType(attachmentName, attachmentType);
    final metadata = SettableMetadata(contentType: contentType);

    final uploadTask = storageRef.putData(fileBytes, metadata);
    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();

    final lastMessageText = attachmentType == 'image'
        ? 'Sent an image'
        : 'Sent a file: $attachmentName';

    await _firestore.collection('chatRooms').doc(chatRoomId).set({
      'participants': [currentUser.uid, receiverId],
      'lastMessage': lastMessageText,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .add({
          'senderId': currentUser.uid,
          'text': '',
          'timestamp': FieldValue.serverTimestamp(),
          'attachmentUrl': downloadUrl,
          'attachmentName': attachmentName,
          'attachmentType': attachmentType,
        });
  }

  String _getContentType(String attachmentName, String attachmentType) {
    final ext = attachmentName.split('.').last.toLowerCase();

    if (attachmentType == 'image') {
      if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
      if (ext == 'png') return 'image/png';
      if (ext == 'gif') return 'image/gif';
      return 'image/*';
    }

    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.ms-powerpoint';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// Delete a message if the current user is the sender
  Future<void> deleteMessage(String chatRoomId, String messageId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final messageRef = _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);

    final messageSnapshot = await messageRef.get();
    if (!messageSnapshot.exists) return;

    final data = messageSnapshot.data();
    if (data == null || data['senderId'] != currentUser.uid) return;

    await messageRef.delete();
  }

  /// Edit a message if the current user is the sender
  Future<void> updateMessage(
    String chatRoomId,
    String messageId,
    String newText,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || newText.trim().isEmpty) return;

    final messageRef = _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);

    final messageSnapshot = await messageRef.get();
    if (!messageSnapshot.exists) return;

    final data = messageSnapshot.data();
    if (data == null || data['senderId'] != currentUser.uid) return;

    await messageRef.update({
      'text': newText,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get one-time message snapshot for attachments
  Future<QuerySnapshot> getMessagesOnce(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .get();
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
