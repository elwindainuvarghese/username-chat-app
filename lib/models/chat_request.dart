import 'package:cloud_firestore/cloud_firestore.dart';

/// Status values for a chat request.
enum RequestStatus { pending, accepted, rejected, cancelled }

/// Dart model for a chat request document in `chat_requests`.
class ChatRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String senderEmail;
  final String receiverName;
  final String receiverEmail;
  final RequestStatus status;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  ChatRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.senderEmail,
    required this.receiverName,
    required this.receiverEmail,
    required this.status,
    this.createdAt,
    this.expiresAt,
  });

  /// Create from a Firestore document snapshot.
  factory ChatRequest.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRequest(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderEmail: data['senderEmail'] ?? '',
      receiverName: data['receiverName'] ?? 'Unknown',
      receiverEmail: data['receiverEmail'] ?? '',
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Whether this request has expired.
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Whether this request is still actionable (pending + not expired).
  bool get isPending => status == RequestStatus.pending && !isExpired;

  static RequestStatus _parseStatus(String? value) {
    switch (value) {
      case 'accepted':
        return RequestStatus.accepted;
      case 'rejected':
        return RequestStatus.rejected;
      case 'cancelled':
        return RequestStatus.cancelled;
      default:
        return RequestStatus.pending;
    }
  }

  static String statusToString(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return 'pending';
      case RequestStatus.accepted:
        return 'accepted';
      case RequestStatus.rejected:
        return 'rejected';
      case RequestStatus.cancelled:
        return 'cancelled';
    }
  }
}
