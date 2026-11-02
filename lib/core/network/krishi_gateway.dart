import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Only a public service URL belongs in an app build. Provider credentials are
/// kept in the Firebase function's secret store.
class KrishiGateway {
  KrishiGateway({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? token,
  }) : _client = client ?? http.Client(),
       _baseUrl =
           baseUrl ?? const String.fromEnvironment('KRISHI_API_BASE_URL'),
       _token = token ?? _firebaseToken;

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _token;

  bool get configured {
    final uri = Uri.tryParse(_baseUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  static Future<String?> _firebaseToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> post(
    String route,
    Map<String, dynamic> body,
  ) async {
    if (!configured) {
      throw const GatewayException(
        'Online help is not connected yet. Saved help still works.',
        kind: GatewayFailure.configuration,
      );
    }
    String? token;
    try {
      token = await _token().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Some injected/providers return Future<String> at runtime. Catching the
      // timeout avoids a nullable onTimeout callback violating that subtype.
      token = null;
    }
    if (token == null) {
      throw const GatewayException(
        'Sign in to use this online service. Offline help is always available.',
        kind: GatewayFailure.signIn,
      );
    }
    try {
      final uri = Uri.parse(
        '${_baseUrl.replaceAll(RegExp(r'/+$'), '')}/$route',
      );
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        throw const GatewayException(
          'Please sign in again to use online help.',
          kind: GatewayFailure.signIn,
        );
      }
      if (response.statusCode == 429) {
        throw const GatewayException(
          'Online help is busy. Please try again later.',
          kind: GatewayFailure.limit,
        );
      }
      if (response.statusCode == 400) {
        throw const GatewayException(
          'Check the text before sending.',
          kind: GatewayFailure.input,
        );
      }
      if (response.statusCode == 403) {
        throw const GatewayException(
          'This service cannot be accessed from this app.',
          kind: GatewayFailure.access,
        );
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.length > 300000) {
        throw const GatewayException(
          'Online information is unavailable. Please try again later.',
        );
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) throw const FormatException();
      return data;
    } on GatewayException {
      rethrow;
    } catch (_) {
      throw const GatewayException(
        'Connection is slow or unavailable. Your saved information is still available.',
        kind: GatewayFailure.connection,
      );
    }
  }

  void dispose() => _client.close();
}

enum GatewayFailure {
  configuration,
  signIn,
  limit,
  input,
  access,
  unavailable,
  connection,
}

class GatewayException implements Exception {
  final String message;
  final GatewayFailure kind;
  const GatewayException(
    this.message, {
    this.kind = GatewayFailure.unavailable,
  });
  String localizedMessage({required bool hindi}) {
    final pair = switch (kind) {
      GatewayFailure.configuration => (
        'Online services are not connected in this build. Saved help is available.',
        'इस संस्करण में ऑनलाइन सेवाएँ जुड़ी नहीं हैं। सहेजी सहायता उपलब्ध है।',
      ),
      GatewayFailure.signIn => (
        'Sign in to get new online information. Saved help remains available.',
        'नई ऑनलाइन जानकारी के लिए साइन इन करें। सहेजी सहायता उपलब्ध है।',
      ),
      GatewayFailure.limit => (
        'The online usage limit has been reached. Try later or use saved help.',
        'ऑनलाइन उपयोग की सीमा पूरी हो गई है। बाद में कोशिश करें या सहेजी सहायता लें।',
      ),
      GatewayFailure.input => (
        'Remove private numbers and email addresses, and keep the question short.',
        'निजी नंबर और ईमेल हटाएँ और सवाल छोटा रखें।',
      ),
      GatewayFailure.access => (
        'This online service needs app setup. Use saved help for now.',
        'इस ऑनलाइन सेवा के लिए ऐप सेटअप चाहिए। अभी सहेजी सहायता लें।',
      ),
      GatewayFailure.unavailable => (
        'The information service is unavailable. Saved reports may be old; try later.',
        'जानकारी की सेवा उपलब्ध नहीं है। सहेजी रिपोर्ट पुरानी हो सकती है; बाद में कोशिश करें।',
      ),
      GatewayFailure.connection => (
        'The connection is slow or unavailable. Your saved information is still here.',
        'कनेक्शन धीमा है या उपलब्ध नहीं है। आपकी सहेजी जानकारी यहीं है।',
      ),
    };
    return hindi ? pair.$2 : pair.$1;
  }

  @override
  String toString() => message;
}
