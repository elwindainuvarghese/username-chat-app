import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('flutterCrypto')
external JSObject? get _flutterCrypto;

@JS()
@staticInterop
class FlutterCrypto {
  external factory FlutterCrypto();
}

extension FlutterCryptoExtension on FlutterCrypto {
  // Define methods matching the JS object if strictly typed,
  // but using callMethod via js_interop_unsafe is often easier for dynamic objects.
}

class CryptoService {
  bool get isSupported => _flutterCrypto != null;

  /// Generates a session key (returns CryptoKey object as JSObject)
  Future<JSObject> generateSessionKey() async {
    if (!isSupported) throw Exception('Web Crypto not supported');
    final promise = _flutterCrypto!.callMethod('generateSessionKey'.toJS);
    return (await promise.toDart)! as JSObject;
  }

  /// Encrypts text using the session key
  /// Returns Map { ciphertext: Uint8Array, iv: Uint8Array }
  Future<Map<String, dynamic>> encryptText(
    String text,
    JSObject sessionKey,
  ) async {
    if (!isSupported) throw Exception('Web Crypto not supported');

    final promise = _flutterCrypto!.callMethod(
      'encryptText'.toJS,
      text.toJS,
      sessionKey,
    );

    final result = (await promise.toDart)! as JSObject;
    // Extract properties
    // Note: This relies on result being a JS Object with properties we can read.
    // We might need to handle the conversion carefully.

    // For simplicity in this demo, accessing properties:
    // This assumes the JS returns a standard object.
    // We can use dart:js_interop_unsafe to get properties.

    return {
      'ciphertext': result.getProperty('ciphertext'.toJS),
      'iv': result.getProperty('iv'.toJS),
    };
  }

  /// Wraps the session key with the receiver's public key
  Future<JSUint8Array> wrapKey(
    JSObject sessionKey,
    JSObject receiverPublicKey,
  ) async {
    if (!isSupported) throw Exception('Web Crypto not supported');

    final promise = _flutterCrypto!.callMethod(
      'wrapKey'.toJS,
      sessionKey,
      receiverPublicKey,
    );

    return (await promise.toDart)! as JSUint8Array;
  }
}
