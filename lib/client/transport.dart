/// The HTTP client every X request goes through.
///
/// Owns the health-aware account rotation: it asks [AccountSelector] for an
/// account, records what the response says about that account's health, and
/// retries on another one until either a request succeeds or every account has
/// been tried. See CLAUDE.md for the full account-selection strategy.
library;

import 'dart:convert';

import 'package:dart_twitter_api/twitter_api.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:quax/catcher/exceptions.dart';
import 'package:quax/client/account_selector.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/client/client_regular_account.dart';
import 'package:quax/client/client_unauthenticated.dart';
import 'package:quax/client/rate_limit_tracker.dart';
import 'package:quax/constants.dart';

const Duration _defaultTimeout = Duration(seconds: 30);

class QuackerTwitterClient extends TwitterClient {
  static final log = Logger('QuackerTwitterClient');

  QuackerTwitterClient() : super(consumerKey: '', consumerSecret: '', token: '', secret: '');

  @override
  Future<http.Response> get(Uri uri, {Map<String, String>? headers, Duration? timeout}) {
    return fetch(uri, headers: headers).timeout(timeout ?? _defaultTimeout).then((response) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      } else {
        return Future.error(HttpException(response));
      }
    });
  }

  /// Tries accounts (healthy ones first, then flagged ones as a fallback),
  /// retrying on another account when one returns a 429 (rate-limited for that
  /// endpoint, tracked in memory) or a 404 (retried once, then surfaced). Rate
  /// limits are per-endpoint, so a 429 on one endpoint never blocks another.
  ///
  /// A real request is always attempted before any error: with accounts, each is
  /// tried; with none, an unauthenticated (guest) request is sent. Errors surface
  /// only from actual responses: [RateLimitedException] when every account was
  /// rate-limited on the endpoint, [NoWorkingAccountException] when they all
  /// returned 404, and [NoAccountAvailableException] only when there is no account
  /// and the guest request also failed.
  static Future<http.Response> fetch(Uri uri, {Map<String, String>? headers}) async {
    final endpoint = uri.path;
    final now = DateTime.now();
    final accounts = await getAccounts();
    final selector = AccountSelector(
      accounts,
      now,
      isRateLimited: (a) => RateLimitTracker.isLimited(a.id, endpoint, now),
    );
    final tried = <String>{};
    var notFoundAttempts = 0;
    http.Response? lastError;

    while (true) {
      final account = selector.pick(exclude: tried);
      if (account == null) {
        break;
      }
      tried.add(account.id);

      final response = await XRegularAccount().fetch(
        uri,
        headers: headers,
        log: log,
        authHeader: json.decode(account.authHeader),
      );
      final code = response.statusCode;

      if (code >= 200 && code < 300) {
        RateLimitTracker.clear(account.id, endpoint);
        if (!account.isClean) {
          await recordAccountSuccess(account.id);
        }
        return response;
      }
      lastError = response;
      if (code == 429) {
        RateLimitTracker.flag(account.id, endpoint, _resetFromHeaders(response));
        continue;
      }
      if (code == 404) {
        await recordNotFound(account.id);
        if (++notFoundAttempts >= 2) {
          break; // tried enough accounts; surface the 404 outcome below
        }
        continue;
      }
      return response; // other errors surfaced immediately
    }

    if (tried.isEmpty) {
      // No account at all: still attempt an unauthenticated (guest) request so we
      // never error before sending one. Only invite to add an account if it fails.
      final guest = await fetchUnauthenticated(uri, headers: headers, log: log);
      if (guest.statusCode >= 200 && guest.statusCode < 300) {
        return guest;
      }
      throw NoAccountAvailableException();
    }
    if (lastError?.statusCode == 429) {
      throw RateLimitedException(); // every account was rate-limited on this endpoint
    }
    if (lastError?.statusCode == 404) {
      throw NoWorkingAccountException(); // accounts tried all returned 404 (likely broken auth)
    }
    return lastError!; // surface the real error
  }

  static DateTime _resetFromHeaders(http.Response response) {
    final reset = response.headers['x-rate-limit-reset']; // epoch seconds
    if (reset != null) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(reset) * 1000);
    }
    return DateTime.now().add(rateLimitFallback);
  }
}
