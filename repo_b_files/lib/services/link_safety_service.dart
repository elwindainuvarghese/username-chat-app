import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../models/link_safety_result.dart';

class _CachedLinkSafety {
  final LinkSafetyResult result;
  final DateTime expiresAt;

  const _CachedLinkSafety({required this.result, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class LinkSafetyService {
  LinkSafetyService._();

  static final LinkSafetyService instance = LinkSafetyService._();

  static const Duration _requestTimeout = Duration(seconds: 8);
  static const Duration _cacheTtl = Duration(hours: 6);

  final Map<String, _CachedLinkSafety> _resultCache = <String, _CachedLinkSafety>{};
  final Map<String, Future<LinkSafetyResult>> _inFlightRequests =
      <String, Future<LinkSafetyResult>>{};

  final RegExp _urlRegex = RegExp(
    r"((https?:\/\/)|(www\.))[\w\-._~:\/?#[\]@!$&'()*+,;=%]+",
    caseSensitive: false,
  );

  List<String> extractUrls(String text) {
    if (text.trim().isEmpty) {
      return const <String>[];
    }

    final Set<String> urls = <String>{};
    for (final RegExpMatch match in _urlRegex.allMatches(text)) {
      final String raw = (match.group(0) ?? '').trim();
      final String normalized = _normalizeUrl(raw);
      if (normalized.isNotEmpty) {
        urls.add(normalized);
      }
    }
    return urls.toList(growable: false);
  }

  Future<LinkSafetyResult> checkUrlSafety(String url) async {
    final String normalizedUrl = _normalizeUrl(url);
    if (!_isValidHttpUrl(normalizedUrl)) {
      return LinkSafetyResult.unknown(
        normalizedUrl.isEmpty ? url : normalizedUrl,
        message: 'Invalid URL',
      );
    }

    final _CachedLinkSafety? cached = _resultCache[normalizedUrl];
    if (cached != null && !cached.isExpired) {
      return cached.result;
    }

    final Future<LinkSafetyResult>? existingRequest =
        _inFlightRequests[normalizedUrl];
    if (existingRequest != null) {
      return existingRequest;
    }

    final Future<LinkSafetyResult> request =
        _checkUrlSafetyInternal(normalizedUrl);
    _inFlightRequests[normalizedUrl] = request;

    try {
      final LinkSafetyResult result = await request;
      _resultCache[normalizedUrl] = _CachedLinkSafety(
        result: result,
        expiresAt: DateTime.now().add(_cacheTtl),
      );
      return result;
    } finally {
      _inFlightRequests.remove(normalizedUrl);
    }
  }

  Future<List<LinkSafetyResult>> checkMessageLinks(String messageText) async {
    final List<String> urls = extractUrls(messageText);
    if (urls.isEmpty) {
      return const <LinkSafetyResult>[];
    }

    final List<Future<LinkSafetyResult>> checks = urls
        .map(checkUrlSafety)
        .toList(growable: false);
    return Future.wait(checks);
  }

  void clearCache() {
    _resultCache.clear();
    _inFlightRequests.clear();
  }

  Future<LinkSafetyResult> _checkUrlSafetyInternal(String url) async {
    final String apiKey = ApiKeys.googleSafeBrowsingApiKey;
    if (apiKey.trim().isEmpty) {
      return LinkSafetyResult.unknown(
        url,
        message: 'Safety check not configured',
      );
    }

    final Uri endpoint = Uri.parse(
      'https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$apiKey',
    );

    final Map<String, dynamic> body = <String, dynamic>{
      'client': <String, String>{
        'clientId': 'username_chat_app',
        'clientVersion': '1.0.0',
      },
      'threatInfo': <String, dynamic>{
        'threatTypes': <String>[
          'MALWARE',
          'SOCIAL_ENGINEERING',
          'UNWANTED_SOFTWARE',
          'POTENTIALLY_HARMFUL_APPLICATION',
        ],
        'platformTypes': <String>['ANY_PLATFORM'],
        'threatEntryTypes': <String>['URL'],
        'threatEntries': <Map<String, String>>[
          <String, String>{'url': url},
        ],
      },
    };

    try {
      final http.Response response = await http
          .post(
            endpoint,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return LinkSafetyResult.unknown(
          url,
          message: 'Safety check failed (${response.statusCode})',
        );
      }

      final Map<String, dynamic> parsed =
          (jsonDecode(response.body) as Map<String, dynamic>?) ??
          <String, dynamic>{};

      final List<dynamic> matches =
          (parsed['matches'] as List<dynamic>?) ?? <dynamic>[];
      if (matches.isEmpty) {
        return LinkSafetyResult.safe(url);
      }

      final Set<String> threats = <String>{};
      for (final dynamic item in matches) {
        if (item is Map<String, dynamic>) {
          final dynamic threatType = item['threatType'];
          if (threatType is String && threatType.isNotEmpty) {
            threats.add(threatType);
          }
        }
      }

      return LinkSafetyResult.unsafe(url, threatTypes: threats.toList());
    } on Exception {
      return LinkSafetyResult.unknown(
        url,
        message: 'Safety check timeout or network error',
      );
    }
  }

  String _normalizeUrl(String input) {
    String value = input.trim();
    if (value.isEmpty) return '';

    value = value.replaceAll(RegExp(r'[),.;!?]+$'), '');

    if (value.startsWith('www.')) {
      value = 'https://$value';
    }
    return value;
  }

  bool _isValidHttpUrl(String value) {
    final Uri? uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }
}