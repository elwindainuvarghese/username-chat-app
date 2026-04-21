enum LinkSafetyStatus { safe, unsafe, unknown }

class LinkSafetyResult {
  final String url;
  final LinkSafetyStatus status;
  final String message;
  final List<String> threatTypes;
  final DateTime checkedAt;

  const LinkSafetyResult({
    required this.url,
    required this.status,
    required this.message,
    this.threatTypes = const [],
    required this.checkedAt,
  });

  bool get isSafe => status == LinkSafetyStatus.safe;
  bool get isUnsafe => status == LinkSafetyStatus.unsafe;
  bool get isUnknown => status == LinkSafetyStatus.unknown;

  String get threatTypesLabel {
    if (threatTypes.isEmpty) {
      return 'Unknown threat type';
    }

    return threatTypes.map(_friendlyThreatType).join(', ');
  }

  static String _friendlyThreatType(String threatType) {
    switch (threatType) {
      case 'MALWARE':
        return 'Malware';
      case 'SOCIAL_ENGINEERING':
        return 'Social Engineering / Phishing';
      case 'UNWANTED_SOFTWARE':
        return 'Unwanted Software';
      case 'POTENTIALLY_HARMFUL_APPLICATION':
        return 'Potentially Harmful App';
      default:
        return threatType.replaceAll('_', ' ').toLowerCase();
    }
  }

  factory LinkSafetyResult.safe(String url) {
    return LinkSafetyResult(
      url: url,
      status: LinkSafetyStatus.safe,
      message: 'Safe Link',
      checkedAt: DateTime.now(),
    );
  }

  factory LinkSafetyResult.unsafe(String url, {List<String> threatTypes = const []}) {
    return LinkSafetyResult(
      url: url,
      status: LinkSafetyStatus.unsafe,
      message: 'Scam/Unsafe Link',
      threatTypes: threatTypes,
      checkedAt: DateTime.now(),
    );
  }

  factory LinkSafetyResult.unknown(String url, {String message = 'Could not verify link'}) {
    return LinkSafetyResult(
      url: url,
      status: LinkSafetyStatus.unknown,
      message: message,
      checkedAt: DateTime.now(),
    );
  }
}