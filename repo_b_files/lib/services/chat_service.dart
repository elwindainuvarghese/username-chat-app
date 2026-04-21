import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/connection.dart';

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

  /// Forward a message to another user
  Future<void> forwardMessage(
    String receiverId,
    Map<String, dynamic> originalMessageData,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatRoomId = getChatRoomId(currentUser.uid, receiverId);

    int currentForwardCount =
        (originalMessageData['forwardCount'] as num?)?.toInt() ?? 0;


    String lastMessageText = (originalMessageData['text'] ?? '').toString();
    if (originalMessageData['attachmentUrl'] != null) {
      lastMessageText = 'Forwarded attachment';
    } else if (lastMessageText.isEmpty) {
      lastMessageText = 'Forwarded message';
    }

    // 1. Create or update the Chat Room metadata
    await _firestore.collection('chatRooms').doc(chatRoomId).set({
      'participants': [currentUser.uid, receiverId],
      'lastMessage': lastMessageText,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Add message to messages sub-collection
    Map<String, dynamic> newMessage = {
      'senderId': currentUser.uid,
      'text': originalMessageData['text'] ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'forwardCount': currentForwardCount + 1,
      'isForwarded': true,
    };

    if (originalMessageData['attachmentUrl'] != null) {
      newMessage['attachmentUrl'] = originalMessageData['attachmentUrl'];
      newMessage['attachmentName'] = originalMessageData['attachmentName'];
      newMessage['attachmentType'] = originalMessageData['attachmentType'];
    }

    await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(newMessage);
  }

  /// Search for a user by email (case-insensitive & fast)
  Future<Map<String, dynamic>?> searchUserByEmail(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      // Run both queries concurrently to halve the response time
      final results = await Future.wait([
        _firestore
            .collection('users')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get(),
        _firestore
            .collection('users')
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get(),
      ]);

      final lowerQuery = results[0];
      final exactQuery = results[1];

      if (lowerQuery.docs.isNotEmpty) {
        return lowerQuery.docs.first.data();
      }
      if (exactQuery.docs.isNotEmpty) {
        return exactQuery.docs.first.data();
      }
      return null;
    } catch (e) {
      print("Error searching user: $e");
      return null;
    }
  }

  /// Add a user to the current user's contacts sub-collection
  /// and also create a connections document for mutual access.
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
      final batch = _firestore.batch();

      // Add to my contacts
      batch.set(
        _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('contacts')
            .doc(contactUid),
        {
          'uid': contactUid,
          'email': contactEmail,
          'displayName': contactName,
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      // Create connection document so chat screen unlocks
      final connId = Connection.generateId(currentUser.uid, contactUid);
      final sorted = [currentUser.uid, contactUid]..sort();
      batch.set(
        _firestore.collection('connections').doc(connId),
        {
          'user1Id': sorted[0],
          'user2Id': sorted[1],
          'createdAt': FieldValue.serverTimestamp(),
          'active': true,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      return true;
    } catch (e) {
      print("Error adding contact: $e");
      return false;
    }
  }

  /// Stream of user's contacts (no ordering to avoid excluding docs missing addedAt)
  Stream<QuerySnapshot> getContactsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('contacts')
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
    String attachmentType, {
    String messageText = '',
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatRoomId = getChatRoomId(currentUser.uid, receiverId);
    
    // Use the default instance for better compatibility across platforms
    final storageRef = FirebaseStorage.instance.ref().child(
      'chatRooms/$chatRoomId/attachments/${DateTime.now().millisecondsSinceEpoch}_$attachmentName',
    );

    final contentType = _getContentType(attachmentName, attachmentType);
    final metadata = SettableMetadata(contentType: contentType);

    // Upload with standard await
    final uploadTask = storageRef.putData(fileBytes, metadata);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    final lastMessageText = messageText.isNotEmpty 
        ? messageText 
        : (attachmentType == 'image'
            ? 'Sent an image'
            : 'Sent a file: $attachmentName');

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
          'text': messageText,
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
