import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/user.dart';

/// The fixtures prove the parsers read *today's* shapes. These prove they
/// survive tomorrow's.
///
/// X does not version this API; it moves fields between containers (the ongoing
/// `legacy` → `core` migration), drops them, and returns partial results for
/// restricted content. Per `.claude/skills/parse-api`, a missing field must
/// produce null or a documented default — never an exception — because one
/// throw in a parser empties a whole timeline.
///
/// Each fixture is therefore replayed with one field removed at a time, which
/// approximates a rename far better than any hand-written stub.
Map<String, dynamic> _fixture(String relativePath) {
  final file = File('test/fixtures/$relativePath');
  if (!file.existsSync()) {
    throw StateError('missing fixture $relativePath');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _without(Map<String, dynamic> source, String key) {
  final copy = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  copy.remove(key);
  return copy;
}

Map<String, dynamic> _nulling(Map<String, dynamic> source, String key) {
  final copy = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  copy[key] = null;
  return copy;
}

void main() {
  // Tombstones are built from translated strings, so the parsers reach for
  // L10n.current the moment a result is unreadable — which is most of what this
  // file exercises.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await L10n.load(const Locale('en'));
  });

  group('UserWithExtra.fromNonLegacyJson', () {
    final profile = _fixture('UserByScreenName/ok.json')['data']['user']['result'] as Map<String, dynamic>;

    test('reads the identity fields X has already moved out of legacy', () {
      final user = UserWithExtra.fromNonLegacyJson(profile);

      expect(user.screenName, 'X');
      expect(user.idStr, '783214');
    });

    // X is actively emptying `legacy` into `core` and `avatar`. This fixture
    // was captured before that migration, so the shape is reconstructed here:
    // identity fields moved across, `legacy` gone. The parser must read the new
    // home rather than throw and take the whole profile screen down.
    test('reads a profile that has finished the legacy migration', () {
      final legacy = profile['legacy'] as Map<String, dynamic>;
      final migrated = _without(profile, 'legacy')
        ..['core'] = {'name': legacy['name'], 'screen_name': legacy['screen_name'], 'created_at': legacy['created_at']}
        ..['avatar'] = {'image_url': legacy['profile_image_url_https']};

      final user = UserWithExtra.fromNonLegacyJson(migrated);

      expect(user.screenName, 'X');
      expect(user.name, 'X');
      expect(user.idStr, '783214');
      expect(user.createdAt, isNotNull);
      expect(user.profileImageUrlHttps, isNotNull);
    });

    test('a response with neither legacy nor core is empty, not an exception', () {
      final user = UserWithExtra.fromNonLegacyJson(_without(profile, 'legacy'));

      expect(user.idStr, '783214');
      expect(user.screenName, isNull);
    });

    test('survives a null legacy', () {
      expect(() => UserWithExtra.fromNonLegacyJson(_nulling(profile, 'legacy')), returnsNormally);
    });

    test('survives losing any single top-level field', () {
      for (final key in profile.keys) {
        expect(
          () => UserWithExtra.fromNonLegacyJson(_without(profile, key)),
          returnsNormally,
          reason: 'dropping "$key" from the profile result throws',
        );
      }
    });
  });

  group('TweetWithCard.fromGraphqlJson', () {
    final tweet = _fixture('TweetDetail/tweet_result.json');

    test('survives losing any single top-level field', () {
      for (final key in tweet.keys) {
        expect(
          () => TweetWithCard.fromGraphqlJson(_without(tweet, key)),
          returnsNormally,
          reason: 'dropping "$key" from the tweet result throws',
        );
      }
    });

    test('survives any single top-level field turning null', () {
      for (final key in tweet.keys) {
        expect(
          () => TweetWithCard.fromGraphqlJson(_nulling(tweet, key)),
          returnsNormally,
          reason: 'a null "$key" on the tweet result throws',
        );
      }
    });

    test('an author whose legacy is gone still yields a tweet', () {
      final copy = jsonDecode(jsonEncode(tweet)) as Map<String, dynamic>;
      (copy['core']?['user_results']?['result'] as Map<String, dynamic>?)?.remove('legacy');

      expect(() => TweetWithCard.fromGraphqlJson(copy), returnsNormally);
    });

    test('an unknown __typename is not a crash', () {
      final copy = jsonDecode(jsonEncode(tweet)) as Map<String, dynamic>;
      copy['__typename'] = 'TweetWithSomethingNewEntirely';

      expect(() => TweetWithCard.fromGraphqlJson(copy), returnsNormally);
    });
  });

  group('Twitter.createTweetChains', () {
    final entries = _fixture('UserTweets/add_entries.json')['entries'] as List<dynamic>;

    test('parses the live entries', () {
      expect(Twitter.createTweetChains(entries), isNotEmpty);
    });

    test('skips entries whose content X has reshaped', () {
      final mangled = jsonDecode(jsonEncode(entries)) as List<dynamic>;
      for (final entry in mangled) {
        (entry as Map<String, dynamic>)['content']?['itemContent']?.remove('tweet_results');
      }

      expect(() => Twitter.createTweetChains(mangled), returnsNormally);
    });

    test('an entry with no content at all is skipped, not fatal', () {
      final mangled = jsonDecode(jsonEncode(entries)) as List<dynamic>;
      (mangled.first as Map<String, dynamic>).remove('content');

      expect(() => Twitter.createTweetChains(mangled), returnsNormally);
    });
  });
}
