import 'package:cloud_firestore/cloud_firestore.dart';

/// Dart model for a mutual connection between two users.
///
/// The document ID is always `{smallerUid}_{largerUid}` so there can
/// be at most one connection record per pair.
class Connection {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime? createdAt;
  final bool active;

  Connection({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.createdAt,
    this.active = true,
  });

  factory Connection.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Connection(
      id: doc.id,
      user1Id: data['user1Id'] ?? '',
      user2Id: data['user2Id'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      active: data['active'] ?? true,
    );
  }

  /// Generate the canonical connection document ID for any two UIDs.
  static String generateId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Check whether a given UID is part of this connection.
  bool involves(String uid) => user1Id == uid || user2Id == uid;
}
