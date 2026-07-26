import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quax/plugins/reddit/reddit_client.dart';

/// Signing in to Reddit, for readers who want their own account's rate limits
/// rather than the public endpoints'.
///
/// This is Reddit's authorization-code flow for installed apps, the same one
/// RedReader uses. It is deliberately optional: the plugin still reads without
/// any of this, and signing in means Reddit sees the reads as *you* — the app
/// cannot prevent that, so it is the reader's choice to make.
///
/// Only the refresh token is kept. Access tokens live an hour and are fetched
/// again when needed, so nothing long-lived beyond the refresh token is stored.
class RedditAuth {
  /// Where Reddit sends the browser back to. It never resolves: the login
  /// webview intercepts the navigation, which is why any scheme works as long
  /// as the registered app uses this exact string.
  static const redirectUri = 'quax://reddit-auth';

  /// Read listings, and identity so the account name can be shown. Deliberately
  /// no write scopes: QuaX does not post, vote or subscribe on anyone's behalf.
  static const scopes = 'read,identity';

  static const _authorizeEndpoint = 'https://www.reddit.com/api/v1/authorize.compact';
  static const _tokenEndpoint = 'https://www.reddit.com/api/v1/access_token';

  final http.Client httpClient;

  RedditAuth({http.Client? httpClient}) : httpClient = httpClient ?? http.Client();

  /// The page the reader logs in on.
  ///
  /// `duration=permanent` is what makes Reddit return a refresh token; without
  /// it the session would die in an hour and ask again.
  static Uri authorizeUrl({required String clientId, required String state}) =>
      Uri.parse(_authorizeEndpoint).replace(queryParameters: {
        'client_id': clientId.trim(),
        'response_type': 'code',
        'state': state,
        'redirect_uri': redirectUri,
        'duration': 'permanent',
        'scope': scopes,
      });

  /// The authorization code Reddit put on the redirect, or null when this is
  /// not the redirect — or when it carried an error or a mismatched state,
  /// which is the check that stops another page from injecting a code.
  static String? codeFrom(Uri uri, {required String expectedState}) {
    if (!uri.toString().startsWith(redirectUri)) {
      return null;
    }
    if (uri.queryParameters['state'] != expectedState) {
      return null;
    }

    final code = uri.queryParameters['code'];
    return (code == null || code.isEmpty) ? null : code;
  }

  /// Whether the redirect says the reader declined, so the screen can close
  /// quietly instead of reporting a failure.
  static bool deniedIn(Uri uri) =>
      uri.toString().startsWith(redirectUri) && uri.queryParameters['error'] != null;

  /// Trades the one-time code for a refresh token.
  Future<String> exchangeCode({required String clientId, required String code}) async =>
      _tokenRequest(clientId: clientId, body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
      }, want: 'refresh_token');

  /// A fresh access token for an already signed-in reader.
  Future<String> accessToken({required String clientId, required String refreshToken}) async =>
      _tokenRequest(clientId: clientId, body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      }, want: 'access_token');

  Future<String> _tokenRequest({
    required String clientId,
    required Map<String, String> body,
    required String want,
  }) async {
    if (clientId.trim().isEmpty) {
      throw const RedditException(RedditErrorKind.notConfigured, 'Signing in still needs a client id');
    }

    late final http.Response response;
    try {
      response = await httpClient.post(
        Uri.parse(_tokenEndpoint),
        headers: {
          // An installed app has no secret, so the password half is empty.
          'Authorization': 'Basic ${base64Encode(utf8.encode('${clientId.trim()}:'))}',
          'User-Agent': RedditClient.userAgent,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&'),
      );
    } catch (e) {
      throw RedditException(RedditErrorKind.network, '$e');
    }

    if (response.statusCode == 401) {
      throw const RedditException(RedditErrorKind.unauthorized, 'Reddit rejected the client id');
    }
    if (response.statusCode != 200) {
      throw RedditException(RedditErrorKind.badResponse, 'HTTP ${response.statusCode} from the token endpoint');
    }

    final decoded = jsonDecode(response.body);
    final value = decoded is Map ? decoded[want] : null;
    if (value is! String || value.isEmpty) {
      throw RedditException(RedditErrorKind.badResponse, 'No $want in the token response');
    }

    return value;
  }
}
