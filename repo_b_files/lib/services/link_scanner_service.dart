import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum Verdict { safe, suspicious, dangerous, unknown }

class ScanResult {
  final String url;
  final Verdict verdict;
  final String reason;
  final String userWarning;

  ScanResult({
    required this.url,
    required this.verdict,
    required this.reason,
    this.userWarning = '',
  });

  bool get isDangerous => verdict == Verdict.dangerous;
  bool get isSuspicious => verdict == Verdict.suspicious;
  bool get isSafe => verdict == Verdict.safe;
}

class LinkScannerService {
  static final RegExp urlRegex = RegExp(
    r'https?://[^\s<>"{}|\\^`\[\]]+',
    caseSensitive: false,
  );

  // Extract all URLs from any message text
  static List<String> extractUrls(String text) {
    return urlRegex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  // Master scan function — runs Layer 1 then Layer 2
  static Future<ScanResult> scanUrl(String url) async {
    // LAYER 1: Instant local heuristic check (no API needed)
    final localResult = _localCheck(url);
    if (localResult.isDangerous || localResult.isSuspicious) return localResult;

    // LAYER 2: Google Safe Browsing API
    try {
      final isThreat = await _callSafeBrowsing(url);
      if (isThreat) {
        return ScanResult(
          url: url,
          verdict: Verdict.dangerous,
          reason: 'Google Safe Browsing flagged this URL as a threat',
          userWarning: '⚠️ Dangerous link — do not open',
        );
      }
    } catch (e) {
      // If API fails, still show local result
      debugPrint('Safe Browsing API error: $e');
    }

    return ScanResult(
      url: url,
      verdict: Verdict.safe,
      reason: 'No threats found',
    );
  }

  // ─── LAYER 1: LOCAL HEURISTIC CHECK ───────────────────────────────────────

  static ScanResult _localCheck(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return ScanResult(
        url: url,
        verdict: Verdict.dangerous,
        reason: 'Invalid URL structure',
        userWarning: '⚠️ Invalid link — do not open',
      );
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    // 1. HTTP (not HTTPS)
    if (uri.scheme == 'http') {
      return ScanResult(
        url: url,
        verdict: Verdict.suspicious,
        reason: 'Link uses HTTP — connection is not encrypted',
        userWarning: '⚠️ Unencrypted link — be careful',
      );
    }

    // 2. IP address used as domain
    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host)) {
      return ScanResult(
        url: url,
        verdict: Verdict.dangerous,
        reason:
            'URL uses an IP address instead of a domain name — common in scams',
        userWarning: '⚠️ Suspicious link — IP address used',
      );
    }

    // 3. Typosquatting — fake brand domains
    final brands = {
      'google': 'google.com',
      'paypal': 'paypal.com',
      'amazon': 'amazon.com',
      'apple': 'apple.com',
      'microsoft': 'microsoft.com',
      'facebook': 'facebook.com',
      'instagram': 'instagram.com',
      'whatsapp': 'whatsapp.com',
      'netflix': 'netflix.com',
      'sbi': 'onlinesbi.sbi',
      'hdfc': 'hdfcbank.com',
      'paytm': 'paytm.com',
      'phonepe': 'phonepe.com',
    };

    for (final entry in brands.entries) {
      final brand = entry.key;
      final realDomain = entry.value;
      // host contains brand name but is NOT the real domain
      if (host.contains(brand) && !host.endsWith(realDomain)) {
        return ScanResult(
          url: url,
          verdict: Verdict.dangerous,
          reason: 'This link is pretending to be $brand but it is fake',
          userWarning: '⚠️ Fake $brand link — possible scam',
        );
      }
    }

    // Catch 'g00gle' specifically by adding leetspeak variants as brands
    final fakeBrands = ['g00gle', 'paypa1', 'faceb00k', 'amaz0n'];
    if (fakeBrands.any((b) => host.contains(b))) {
      return ScanResult(
        url: url,
        verdict: Verdict.dangerous,
        reason:
            'This link is pretending to be a real brand but uses leetspeak characters',
        userWarning: '⚠️ Fake link — possible scam',
      );
    }

    // 4. Phishing keywords in path
    final phishingWords = [
      'verify',
      'kyc',
      'otp',
      'login',
      'signin',
      'account',
      'suspend',
      'confirm',
      'update',
      'secure',
      'wallet',
      'prize',
      'winner',
      'claim',
      'reward',
      'free-money',
      'urgent',
      'blocked',
      'alert',
    ];
    for (final word in phishingWords) {
      if (path.contains(word)) {
        return ScanResult(
          url: url,
          verdict: Verdict.suspicious,
          reason: 'Link contains suspicious keyword: "$word"',
          userWarning: '⚠️ Suspicious link — verify before opening',
        );
      }
    }

    // 5. Suspicious TLDs
    const suspiciousTlds = [
      '.xyz',
      '.tk',
      '.ml',
      '.cf',
      '.ga',
      '.gq',
      '.top',
      '.click',
    ];
    if (suspiciousTlds.any((tld) => host.endsWith(tld))) {
      return ScanResult(
        url: url,
        verdict: Verdict.suspicious,
        reason: 'This link uses a TLD commonly associated with scam websites',
        userWarning: '⚠️ Suspicious domain — be careful',
      );
    }

    // 6. Too many subdomains (e.g. secure.login.verify.bank.scam.xyz)
    if (host.split('.').length > 4) {
      return ScanResult(
        url: url,
        verdict: Verdict.suspicious,
        reason: 'URL has an unusual number of subdomains — common in phishing',
        userWarning: '⚠️ Suspicious link structure',
      );
    }

    return ScanResult(
      url: url,
      verdict: Verdict.unknown,
      reason: 'Needs API check',
    );
  }

  // ─── LAYER 2: GOOGLE SAFE BROWSING ────────────────────────────────────────

  static Future<bool> _callSafeBrowsing(String url) async {
    const apiKey =
        'AIzaSyAClVrgR4Xx82jo9BxAm84j4aUGaso3wcI'; // Replace with your Safe Browsing API key
    const endpoint =
        'https://safebrowsing.googleapis.com/v4/threatMatches:find';

    final response = await http.post(
      Uri.parse('$endpoint?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "client": {"clientId": "bitchat", "clientVersion": "1.0"},
        "threatInfo": {
          "threatTypes": [
            "MALWARE",
            "SOCIAL_ENGINEERING",
            "UNWANTED_SOFTWARE",
            "POTENTIALLY_HARMFUL_APPLICATION",
          ],
          "platformTypes": ["ANY_PLATFORM"],
          "threatEntryTypes": ["URL"],
          "threatEntries": [
            {"url": url}, // ← FULL URL with path, never truncated
          ],
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // If 'matches' key exists and is non-empty → threat found
      return data.containsKey('matches') &&
          (data['matches'] as List).isNotEmpty;
    }
    return false;
  }
}
