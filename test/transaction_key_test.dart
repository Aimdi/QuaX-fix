import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/headers.dart';
import 'package:quax/client/x_client_transaction_id/client_transaction.dart';
import 'package:quax/constants.dart';

/// `_initFuture ??= ClientTransaction.initialize()` cached a *rejected* future
/// as happily as a successful one. Deriving the key does two network requests
/// and parses X's HTML, so a single blip left that failure in the static for
/// the life of the process: every later request threw the same error and only a
/// force-stop cleared it. Since X answers an unsigned request with 404, the app
/// looked completely broken.
void main() {
  setUp(TwitterHeaders.resetForTesting);
  tearDown(TwitterHeaders.resetForTesting);

  final uri = Uri.https('x.com', '/i/api/graphql/abc/UserTweets');

  ClientTransaction fakeTransaction() =>
      ClientTransaction.forTesting(keyBytes: const [1, 2, 3, 4], animationKey: 'test-animation-key');

  group('transactionKeyUsable', () {
    final now = DateTime.utc(2026, 7, 25, 12);

    test('a key that has never been derived is not usable', () {
      expect(transactionKeyUsable(derivedAt: null, now: now, lifetime: const Duration(hours: 6)), isFalse);
    });

    test('a fresh key is usable', () {
      expect(
        transactionKeyUsable(
          derivedAt: now.subtract(const Duration(minutes: 5)),
          now: now,
          lifetime: const Duration(hours: 6),
        ),
        isTrue,
      );
    });

    // X rotates the home page and on-demand bundle the key is built from.
    test('a key older than its lifetime is re-derived', () {
      expect(
        transactionKeyUsable(
          derivedAt: now.subtract(const Duration(hours: 7)),
          now: now,
          lifetime: const Duration(hours: 6),
        ),
        isFalse,
      );
    });

    test('the shipped lifetime is well short of a day', () {
      expect(transactionKeyLifetime, lessThan(const Duration(days: 1)));
    });
  });

  group('key caching', () {
    test('a successful derivation is reused rather than repeated per request', () async {
      var derivations = 0;
      TwitterHeaders.initializer = () async {
        derivations++;
        return fakeTransaction();
      };

      await TwitterHeaders.getXClientTransactionIdHeader(uri);
      await TwitterHeaders.getXClientTransactionIdHeader(uri);
      await TwitterHeaders.getXClientTransactionIdHeader(uri);

      expect(derivations, 1);
    });

    // The regression this file exists for.
    test('a failed derivation is not cached, so the next request retries', () async {
      var attempts = 0;
      TwitterHeaders.initializer = () async {
        attempts++;
        if (attempts == 1) {
          throw Exception('transient network blip');
        }
        return fakeTransaction();
      };

      await expectLater(TwitterHeaders.getXClientTransactionIdHeader(uri), throwsA(isA<Exception>()));

      final header = await TwitterHeaders.getXClientTransactionIdHeader(uri);

      expect(attempts, 2);
      expect(header?['x-client-transaction-id'], isNotNull);
    });

    test('repeated failures keep retrying rather than latching', () async {
      var attempts = 0;
      TwitterHeaders.initializer = () async {
        attempts++;
        throw Exception('still down');
      };

      for (var i = 0; i < 3; i++) {
        await expectLater(TwitterHeaders.getXClientTransactionIdHeader(uri), throwsA(isA<Exception>()));
      }

      expect(attempts, 3);
    });

    test('the key is re-derived once its lifetime has passed', () async {
      var derivations = 0;
      var now = DateTime.utc(2026, 7, 25, 12);
      TwitterHeaders.clock = () => now;
      TwitterHeaders.initializer = () async {
        derivations++;
        return fakeTransaction();
      };

      await TwitterHeaders.getXClientTransactionIdHeader(uri);
      now = now.add(transactionKeyLifetime + const Duration(minutes: 1));
      await TwitterHeaders.getXClientTransactionIdHeader(uri);

      expect(derivations, 2);
    });

    test('concurrent first requests share one derivation', () async {
      var derivations = 0;
      TwitterHeaders.initializer = () async {
        derivations++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return fakeTransaction();
      };

      await Future.wait([
        TwitterHeaders.getXClientTransactionIdHeader(uri),
        TwitterHeaders.getXClientTransactionIdHeader(uri),
        TwitterHeaders.getXClientTransactionIdHeader(uri),
      ]);

      expect(derivations, 1);
    });

    test('no header is asked for when there is no uri', () async {
      TwitterHeaders.initializer = () async => fail('should not derive a key');

      expect(await TwitterHeaders.getXClientTransactionIdHeader(null), isNull);
    });
  });
}
