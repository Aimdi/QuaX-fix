import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pref/pref.dart';
import 'package:xta/constants.dart';
import 'package:xta/plugins/pixiv/pixiv_auth.dart';
import 'package:xta/plugins/pixiv/pixiv_models.dart';
import 'package:xta/utils/json.dart';

enum PixivErrorKind {
  notConfigured,
  network,
  unauthorized,
  rateLimited,
  notFound,
  badResponse,
}

class PixivException implements Exception {
  final PixivErrorKind kind;
  final String message;

  PixivException(this.kind, this.message);

  @override
  String toString() => 'PixivException{$kind: $message}';
}

class PixivIllustPage {
  final List<PixivIllust> illusts;
  final String? nextUrl;

  const PixivIllustPage({required this.illusts, this.nextUrl});
}

/// Read-only client for Pixiv's unofficial app API.
///
/// Auth is a pasted refresh token — same shape community clients use after
/// password login was removed. No bookmark / follow / like writes.
class PixivClient {
  final http.Client httpClient;
  final BasePrefService prefs;

  PixivClient(this.prefs, {http.Client? httpClient}) : httpClient = httpClient ?? http.Client();

  static const _timeout = Duration(seconds: 25);
  static const _apiBase = 'https://app-api.pixiv.net';
  static const _userAgent = 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)';

  String get _refreshToken => (prefs.get<String>(optionPluginPixivRefreshToken) ?? '').trim();
  bool get showR18 => prefs.get<bool>(optionPluginPixivShowR18) == true;

  Map<String, String> get _baseHeaders => {
        'User-Agent': _userAgent,
        'App-OS': 'android',
        'App-OS-Version': '11',
        'App-Version': '5.0.234',
        'Accept': 'application/json',
      };

  Future<http.Response> _send(Future<http.Response> Function() run) async {
    try {
      return await run().timeout(_timeout);
    } catch (e) {
      throw PixivException(PixivErrorKind.network, '$e');
    }
  }

  void _throwForStatus(http.Response response, Uri uri) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw PixivException(PixivErrorKind.unauthorized, '$uri: ${response.statusCode}');
    }
    if (response.statusCode == 404) {
      throw PixivException(PixivErrorKind.notFound, '$uri: 404');
    }
    if (response.statusCode == 429) {
      throw PixivException(PixivErrorKind.rateLimited, '$uri: 429');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PixivException(PixivErrorKind.badResponse, '$uri: ${response.statusCode}');
    }
  }

  Object? _decode(http.Response response, Uri uri) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      throw PixivException(PixivErrorKind.badResponse, '$uri: $e');
    }
  }

  /// Exchanges the refresh token; stores access token + expiry; returns the user.
  Future<PixivAuthUser> refreshAccessToken() async {
    if (_refreshToken.isEmpty) {
      throw PixivException(PixivErrorKind.notConfigured, 'no refresh token');
    }

    final response = await _send(() => httpClient.post(
          Uri.parse(PixivAuth.authTokenUrl),
          headers: {
            ..._baseHeaders,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'client_id': PixivAuth.clientId,
            'client_secret': PixivAuth.clientSecret,
            'grant_type': 'refresh_token',
            'include_policy': 'true',
            'refresh_token': _refreshToken,
          },
        ));

    _throwForStatus(response, Uri.parse(PixivAuth.authTokenUrl));
    final json = Json(_decode(response, Uri.parse(PixivAuth.authTokenUrl)));
    final access = json['access_token'].string;
    final refresh = json['refresh_token'].string;
    final expiresIn = json['expires_in'].integer ?? 3600;
    final user = json['user'];

    if (access == null || access.isEmpty) {
      throw PixivException(PixivErrorKind.badResponse, 'token response missing access_token');
    }

    await prefs.set(optionPluginPixivAccessToken, access);
    if (refresh != null && refresh.isNotEmpty) {
      await prefs.set(optionPluginPixivRefreshToken, refresh);
    }
    await prefs.set(
      optionPluginPixivAccessExpiresAt,
      DateTime.now().add(Duration(seconds: expiresIn - 60)).toIso8601String(),
    );

    return PixivAuthUser(
      id: user['id'].integer ?? int.tryParse(user['id'].string ?? '') ?? 0,
      name: user['name'].string?.trim() ?? '',
      account: user['account'].string?.trim() ?? '',
    );
  }

  Future<String> _accessToken() async {
    final existing = (prefs.get<String>(optionPluginPixivAccessToken) ?? '').trim();
    final expiresRaw = prefs.get<String>(optionPluginPixivAccessExpiresAt) ?? '';
    final expires = DateTime.tryParse(expiresRaw);
    if (existing.isNotEmpty && expires != null && expires.isAfter(DateTime.now())) {
      return existing;
    }
    await refreshAccessToken();
    return (prefs.get<String>(optionPluginPixivAccessToken) ?? '').trim();
  }

  /// Confirms the refresh token still works.
  Future<PixivAuthUser> verify() => refreshAccessToken();

  /// Persists tokens from browser OAuth and returns the signed-in user.
  Future<PixivAuthUser> applyLoginTokens(PixivLoginTokens tokens) async {
    await prefs.set(optionPluginPixivAccessToken, tokens.accessToken);
    await prefs.set(optionPluginPixivRefreshToken, tokens.refreshToken);
    await prefs.set(
      optionPluginPixivAccessExpiresAt,
      DateTime.now().add(Duration(seconds: tokens.expiresIn - 60)).toIso8601String(),
    );
    return tokens.user;
  }

  Future<void> signOut() async {
    await prefs.set(optionPluginPixivRefreshToken, '');
    await prefs.set(optionPluginPixivAccessToken, '');
    await prefs.set(optionPluginPixivAccessExpiresAt, '');
  }

  Future<Object?> _apiGet(String path, [Map<String, String>? query]) async {
    final token = await _accessToken();
    final uri = Uri.parse('$_apiBase$path').replace(queryParameters: query);
    final response = await _send(() => httpClient.get(uri, headers: {
          ..._baseHeaders,
          'Authorization': 'Bearer $token',
        }));

    if (response.statusCode == 401) {
      await refreshAccessToken();
      final retryToken = (prefs.get<String>(optionPluginPixivAccessToken) ?? '').trim();
      final retry = await _send(() => httpClient.get(uri, headers: {
            ..._baseHeaders,
            'Authorization': 'Bearer $retryToken',
          }));
      _throwForStatus(retry, uri);
      return _decode(retry, uri);
    }

    _throwForStatus(response, uri);
    return _decode(response, uri);
  }

  Future<Object?> _apiGetUrl(String absoluteUrl) async {
    final token = await _accessToken();
    final uri = Uri.parse(absoluteUrl);
    final response = await _send(() => httpClient.get(uri, headers: {
          ..._baseHeaders,
          'Authorization': 'Bearer $token',
        }));
    _throwForStatus(response, uri);
    return _decode(response, uri);
  }

  Future<PixivIllustPage> following({String? nextUrl}) async {
    final json = nextUrl == null
        ? await _apiGet('/v2/illust/follow', {'restrict': 'public'})
        : await _apiGetUrl(nextUrl);
    final root = Json(json);
    return PixivIllustPage(
      illusts: parsePixivIllustList(json, includeR18: showR18),
      nextUrl: root['next_url'].string,
    );
  }

  Future<PixivUser> userDetail(int userId) async {
    final json = await _apiGet('/v1/user/detail', {
      'user_id': '$userId',
      'filter': 'for_android',
    });
    final user = PixivUser.fromDetailJson(json);
    if (user.id == 0) {
      throw PixivException(PixivErrorKind.badResponse, 'empty user $userId');
    }
    return user;
  }

  Future<PixivIllustPage> userIllusts(int userId, {String? nextUrl}) async {
    final json = nextUrl == null
        ? await _apiGet('/v1/user/illusts', {
            'user_id': '$userId',
            'type': 'illust',
            'filter': 'for_android',
          })
        : await _apiGetUrl(nextUrl);
    final root = Json(json);
    return PixivIllustPage(
      illusts: parsePixivIllustList(json, includeR18: showR18),
      nextUrl: root['next_url'].string,
    );
  }
}
