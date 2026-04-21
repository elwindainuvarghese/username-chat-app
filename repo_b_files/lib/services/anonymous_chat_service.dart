import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Ephemeral anonymous chatting service.
///
/// Key privacy guarantees:
/// • Chat rooms are stored under `anonChatRooms` in Firestore and are
///   auto-purged when either participant leaves.
/// • Each participant is assigned a random alias ("Shadow Fox", "Ghost Owl" …)
///   so real usernames/emails are never transmitted.
/// • A server-side TTL field (`expiresAt`) is written so even if deletion
///   fails client-side, a scheduled Cloud Function can clean up stale rooms.
class AnonymousChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
  );
  final FirebaseAuth _auth = FirebaseAuth.instanceFor(app: Firebase.app());

  // ── Random display-name generator ──────────────────────────────────────

  static const List<String> _adjectives = [
    'Shadow',   'Ghost',   'Silent',  'Hidden',
    'Phantom',  'Mystic',  'Veiled',  'Stealth',
    'Eclipse',  'Cipher',  'Nebula',  'Raven',
    'Frost',    'Storm',   'Void',    'Obsidian',
  ];
  static const List<String> _nouns = [
    'Fox',     'Owl',     'Wolf',    'Hawk',
    'Panther', 'Viper',   'Lynx',    'Falcon',
    'Spectre', 'Wraith',  'Rogue',   'Drifter',
    'Mirage',  'Comet',   'Blade',   'Ember',
  ];

  static String generateAlias() {
    final rng = Random.secure();
    final adj  = _adjectives[rng.nextInt(_adjectives.length)];
    final noun = _nouns[rng.nextInt(_nouns.length)];
    final tag  = (rng.nextInt(900) + 100).toString(); // 100-999
    return '$adj $noun #$tag';
  }

  // ── Room lifecycle ─────────────────────────────────────────────────────

  /// Create a new anonymous chat room with the given partner.
  /// Returns `{ roomId, myAlias, partnerAlias }`.
  Future<Map<String, String>> createRoom(String partnerUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');

    final myAlias      = generateAlias();
    final partnerAlias = generateAlias();
    final roomId = _generateRoomId();

    await _firestore.collection('anonChatRooms').doc(roomId).set({
      'participants': [currentUser.uid, partnerUid],
      'aliases': {
        currentUser.uid: myAlias,
        partnerUid: partnerAlias,
      },
      'createdAt': FieldValue.serverTimestamp(),
      // auto-expire after 24 h even if no one explicitly leaves
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
      'active': true,
    });

    return {
      'roomId': roomId,
      'myAlias': myAlias,
      'partnerAlias': partnerAlias,
    };
  }

  String _generateRoomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return 'anon_${List.generate(20, (_) => chars[rng.nextInt(chars.length)]).join()}';
  }

  // ── Messaging ──────────────────────────────────────────────────────────

  Future<void> sendMessage(String roomId, String text) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('anonChatRooms')
        .doc(roomId)
        .collection('messages')
        .add({
      'senderId': currentUser.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getMessages(String roomId) {
    return _firestore
        .collection('anonChatRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ── Leaving / destroying ───────────────────────────────────────────────

  /// Delete every message in the room, then delete the room document itself.
  Future<void> destroyRoom(String roomId) async {
    final messagesRef = _firestore
        .collection('anonChatRooms')
        .doc(roomId)
        .collection('messages');

    // batch-delete messages (Firestore max batch size = 500)
    QuerySnapshot snap = await messagesRef.limit(500).get();
    while (snap.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      snap = await messagesRef.limit(500).get();
    }

    // delete room metadata
    await _firestore.collection('anonChatRooms').doc(roomId).delete();
  }

  // ── Contacts stream (reuse for partner picker) ─────────────────────────

  Stream<QuerySnapshot> getContactsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('contacts')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  /// Get the current user uid.
  String? get currentUid => _auth.currentUser?.uid;
}
