import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_request.dart';
import '../models/connection.dart';

/// Central service for the Mutual Consent Chat System.
///
/// Responsibilities:
///   • Send / cancel / accept / reject chat requests
///   • Detect cross-requests (both users requested each other)
///   • Create connections on mutual consent
///   • Add contacts to both users on connection
///   • Verify connections before messaging is allowed
///   • Rate-limit requests (max 20 pending per user)
///   • Auto-expire requests after 7 days
class ConnectionService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instanceFor(app: Firebase.app());
  final FirebaseAuth _auth =
      FirebaseAuth.instanceFor(app: Firebase.app());

  // ────────────────────────────────────────────────────────────
  //  HELPERS
  // ────────────────────────────────────────────────────────────

  String? get currentUid => _auth.currentUser?.uid;

  /// Canonical connection document ID for two UIDs.
  String _connectionId(String uid1, String uid2) =>
      Connection.generateId(uid1, uid2);

  /// Called once on startup to unlock old chats that were started
  /// before the mutual-consent system was added.
  Future<void> migrateLegacyContactsToConnections() async {
    final uid = currentUid;
    if (uid == null) return;

    try {
      final contactsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('contacts')
          .get();

      if (contactsSnap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in contactsSnap.docs) {
        final contactUid = doc.id;
        final connId = _connectionId(uid, contactUid);
        final sorted = [uid, contactUid]..sort();

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
      }
      await batch.commit();
      debugPrint("✅ Legacy contacts migrated to connections");
    } catch (e) {
      debugPrint("Error migrating legacy contacts: $e");
    }
  }

  // ────────────────────────────────────────────────────────────
  //  SEND REQUEST
  // ────────────────────────────────────────────────────────────

  /// Send a chat request from the current user to [receiverUid].
  ///
  /// Returns a result map `{ success: bool, message: String }`.
  Future<Map<String, dynamic>> sendRequest({
    required String receiverUid,
    required String receiverName,
    required String receiverEmail,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    // Prevent self-request
    if (currentUser.uid == receiverUid) {
      return {'success': false, 'message': 'You cannot send a request to yourself'};
    }

    // Check if already connected
    final connected = await isConnected(receiverUid);
    if (connected) {
      return {'success': false, 'message': 'You are already connected'};
    }

    // Rate-limiting: max 20 pending outgoing requests
    final outgoing = await _firestore
        .collection('chat_requests')
        .where('senderId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (outgoing.docs.length >= 20) {
      return {
        'success': false,
        'message': 'Too many pending requests. Wait for some to be accepted or cancel old ones.'
      };
    }

    // Check for duplicate pending request (same direction)
    final existing = await _firestore
        .collection('chat_requests')
        .where('senderId', isEqualTo: currentUser.uid)
        .where('receiverId', isEqualTo: receiverUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (existing.docs.isNotEmpty) {
      return {'success': false, 'message': 'Request already sent'};
    }

    // Fetch sender info
    final senderDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    final senderData = senderDoc.data() ?? {};
    final senderName =
        currentUser.displayName ?? senderData['displayName'] ?? 'Unknown';
    final senderEmail = currentUser.email ?? senderData['email'] ?? '';

    // Check for cross-request (they already sent one to us)
    final crossRequest = await _firestore
        .collection('chat_requests')
        .where('senderId', isEqualTo: receiverUid)
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (crossRequest.docs.isNotEmpty) {
      // ✅ Both users want to connect → auto-accept!
      final theirRequestDoc = crossRequest.docs.first;
      await _acceptRequestById(theirRequestDoc.id, currentUser.uid);
      return {
        'success': true,
        'message': 'They already requested you — connection established!'
      };
    }

    // Create the request
    await _firestore.collection('chat_requests').add({
      'senderId': currentUser.uid,
      'receiverId': receiverUid,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'receiverName': receiverName,
      'receiverEmail': receiverEmail,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7)),
      ),
    });

    return {'success': true, 'message': 'Request sent!'};
  }

  // ────────────────────────────────────────────────────────────
  //  ACCEPT / REJECT / CANCEL
  // ────────────────────────────────────────────────────────────

  /// Accept an incoming request. Creates a connection + mutual contacts.
  Future<Map<String, dynamic>> acceptRequest(String requestId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }
    return _acceptRequestById(requestId, currentUser.uid);
  }

  Future<Map<String, dynamic>> _acceptRequestById(
      String requestId, String acceptorUid) async {
    final requestRef =
        _firestore.collection('chat_requests').doc(requestId);
    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      return {'success': false, 'message': 'Request not found'};
    }

    final request = ChatRequest.fromDoc(requestDoc);

    // Verify the acceptor is the receiver
    if (request.receiverId != acceptorUid) {
      // Log suspicious activity
      debugPrint(
          '⚠️ SUSPICIOUS: User $acceptorUid tried to accept request $requestId addressed to ${request.receiverId}');
      return {'success': false, 'message': 'Unauthorized'};
    }

    if (request.isExpired) {
      await requestRef.update({'status': 'expired'});
      return {'success': false, 'message': 'Request has expired'};
    }

    if (request.status != RequestStatus.pending) {
      return {'success': false, 'message': 'Request is no longer pending'};
    }

    // Use a Firestore batch for atomicity
    final batch = _firestore.batch();

    // 1. Mark request as accepted
    batch.update(requestRef, {'status': 'accepted'});

    // 2. Create connection document
    final connId = _connectionId(request.senderId, request.receiverId);
    final sorted = [request.senderId, request.receiverId]..sort();
    batch.set(_firestore.collection('connections').doc(connId), {
      'user1Id': sorted[0],
      'user2Id': sorted[1],
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });

    // 3. Add each user to the other's contacts subcollection
    batch.set(
      _firestore
          .collection('users')
          .doc(request.senderId)
          .collection('contacts')
          .doc(request.receiverId),
      {
        'uid': request.receiverId,
        'email': request.receiverEmail,
        'displayName': request.receiverName,
        'addedAt': FieldValue.serverTimestamp(),
      },
    );
    batch.set(
      _firestore
          .collection('users')
          .doc(request.receiverId)
          .collection('contacts')
          .doc(request.senderId),
      {
        'uid': request.senderId,
        'email': request.senderEmail,
        'displayName': request.senderName,
        'addedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
    return {'success': true, 'message': 'Connected!'};
  }

  /// Reject an incoming request.
  Future<Map<String, dynamic>> rejectRequest(String requestId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    final requestRef =
        _firestore.collection('chat_requests').doc(requestId);
    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      return {'success': false, 'message': 'Request not found'};
    }

    final data = requestDoc.data() as Map<String, dynamic>;
    if (data['receiverId'] != currentUser.uid) {
      debugPrint(
          '⚠️ SUSPICIOUS: User ${currentUser.uid} tried to reject request $requestId');
      return {'success': false, 'message': 'Unauthorized'};
    }

    await requestRef.update({'status': 'rejected'});
    return {'success': true, 'message': 'Request rejected'};
  }

  /// Cancel an outgoing request (sender only).
  Future<Map<String, dynamic>> cancelRequest(String requestId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    final requestRef =
        _firestore.collection('chat_requests').doc(requestId);
    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      return {'success': false, 'message': 'Request not found'};
    }

    final data = requestDoc.data() as Map<String, dynamic>;
    if (data['senderId'] != currentUser.uid) {
      return {'success': false, 'message': 'Unauthorized'};
    }

    await requestRef.update({'status': 'cancelled'});
    return {'success': true, 'message': 'Request cancelled'};
  }

  // ────────────────────────────────────────────────────────────
  //  CONNECTION CHECK  (used by ChatScreen)
  // ────────────────────────────────────────────────────────────

  /// Returns `true` when a valid, active connection exists with [otherUid].
  Future<bool> isConnected(String otherUid) async {
    final uid = currentUid;
    if (uid == null) return false;

    final connId = _connectionId(uid, otherUid);
    final doc =
        await _firestore.collection('connections').doc(connId).get();
    if (!doc.exists) return false;

    final data = doc.data();
    return data?['active'] == true;
  }

  /// Stream that emits `true`/`false` whenever connection status changes.
  Stream<bool> connectionStream(String otherUid) {
    final uid = currentUid;
    if (uid == null) return Stream.value(false);

    final connId = _connectionId(uid, otherUid);
    return _firestore
        .collection('connections')
        .doc(connId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return false;
      final data = snap.data();
      return data?['active'] == true;
    });
  }

  // ────────────────────────────────────────────────────────────
  //  STREAMS  (for the requests screen)
  // ────────────────────────────────────────────────────────────

  /// Incoming requests (where I am the receiver, status = pending).
  Stream<QuerySnapshot> incomingRequestsStream() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('chat_requests')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Outgoing requests (where I am the sender, status = pending).
  Stream<QuerySnapshot> outgoingRequestsStream() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('chat_requests')
        .where('senderId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Count of pending incoming requests (for badge).
  Stream<int> incomingRequestCountStream() {
    return incomingRequestsStream().map((snap) => snap.docs.length);
  }

  // ────────────────────────────────────────────────────────────
  //  REQUEST STATUS CHECK  (for new_chat_screen button state)
  // ────────────────────────────────────────────────────────────

  /// Check existing request status between current user and [otherUid].
  /// Returns null if no request exists, else the status string.
  Future<String?> getRequestStatus(String otherUid) async {
    final uid = currentUid;
    if (uid == null) return null;

    // Run all 3 checks concurrently to drastically reduce response time
    final results = await Future.wait([
      _firestore
          .collection('chat_requests')
          .where('senderId', isEqualTo: uid)
          .where('receiverId', isEqualTo: otherUid)
          .where('status', isEqualTo: 'pending')
          .get(),
      _firestore
          .collection('chat_requests')
          .where('senderId', isEqualTo: otherUid)
          .where('receiverId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get(),
      isConnected(otherUid),
    ]);

    final sentQuery = results[0] as QuerySnapshot;
    if (sentQuery.docs.isNotEmpty) return 'sent';

    final receivedQuery = results[1] as QuerySnapshot;
    if (receivedQuery.docs.isNotEmpty) return 'received';

    final connected = results[2] as bool;
    if (connected) return 'connected';

    return null;
  }
}
