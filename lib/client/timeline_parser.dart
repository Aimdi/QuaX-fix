/// Turns X's timeline JSON into the app's tweet model.
///
/// Separated from `client.dart` because this is the half that breaks: the
/// transport rarely changes, while X reshapes its timeline entries constantly.
/// Nothing here performs a request, so every function can be exercised against
/// a recorded response — see `test/parser_resilience_test.dart`.
///
/// Per `.claude/skills/parse-api`, an entry whose shape is no longer recognised
/// is skipped rather than thrown on: one unreadable item must not empty a page.
library;

import 'package:dart_twitter_api/src/utils/date_utils.dart';
import 'package:dart_twitter_api/twitter_api.dart';
import 'package:quax/client/tweet_models.dart';
import 'package:quax/user.dart';
import 'package:quax/utils/iterables.dart';

class TimelineParser {
  static PaginatedUsers parseUsersTimeline(dynamic instructions) {
    var users = PaginatedUsers()..users = [];
    if (instructions == null) {
      return users;
    }
    for (final instruction in instructions) {
      if (instruction["type"] != "TimelineAddEntries" || instruction["entries"] == null) continue;
      var entries = List.from(instruction["entries"]);
      users.nextCursorStr = getCursor(entries, [], 'cursor-bottom', 'Bottom');
      users.previousCursorStr = getCursor(entries, [], 'cursor-top', 'Top');
      for (final entry in entries) {
        final userResult = entry["content"]?["itemContent"]?["user_results"]?["result"];
        if (userResult == null) continue;
        var user = UserWithExtra()
          ..screenName = userResult["core"]?["screen_name"]
          ..name = userResult["core"]?["name"]
          ..profileImageUrlHttps = userResult["avatar"]?["image_url"]
          ..verified = userResult["is_blue_verified"]
          ..createdAt = convertTwitterDateTime(userResult["core"]?["created_at"])
          ..idStr = userResult["rest_id"];
        users.users!.add(user);
      }
    }
    return users;
  }

  // GraphQL "ListByRestId" — metadata of an X list. The name is null when the
  // list is deleted or private (data.list absent from the response).

  static bool isNotPromoted(Map<String, dynamic> item) {
    final bool entryIdContainsPromoted = item['entryId']?.contains("promoted") ?? false;
    final bool hasPromotedMetadata = item['item']?['itemContent']?.containsKey("promotedMetadata") ?? false;
    return !(entryIdContainsPromoted || hasPromotedMetadata);
  }

  /// The tweet node inside a `tweet_results.result`, unwrapping the extra layer
  /// that reply-restricted tweets (`TweetWithVisibilityResults`) add. Null when
  /// the result carries no usable tweet — deleted, restricted, or a shape we no
  /// longer recognise.
  static Map<String, dynamic>? _unwrapTweetResult(dynamic result) {
    if (result is! Map<String, dynamic>) {
      return null;
    }
    final unwrapped = result['rest_id'] != null ? result : result['tweet'];
    if (unwrapped is! Map<String, dynamic> || unwrapped['rest_id'] == null) {
      return null;
    }
    return unwrapped;
  }

  /// Tweets carried by a conversation entry. Items X has reshaped are skipped
  /// rather than throwing, so one unreadable reply cannot empty a thread.
  static List<TweetWithCard> _conversationTweets(dynamic entry, {required bool skipPromoted}) {
    final items = entry?['content']?['items'] as List<dynamic>? ?? const [];

    return items
        .where((item) => !skipPromoted || isNotPromoted(item))
        .where((item) => item?['item']?['itemContent']?['itemType'] == 'TimelineTweet')
        .map((item) => _unwrapTweetResult(item?['item']?['itemContent']?['tweet_results']?['result']))
        .nonNulls
        .map(TweetWithCard.fromGraphqlJson)
        .toList();
  }

  static List<TweetChain> createTweetChains(List<dynamic> addEntries) {
    List<TweetChain> replies = [];

    for (var entry in addEntries) {
      var entryId = entry?['entryId'] as String?;
      if (entryId == null) {
        continue;
      }
      if (entryId.startsWith('tweet-')) {
        final tweetResults = entry['content']?['itemContent']?['tweet_results'] as Map<String, dynamic>?;

        // This may happen for tweets that x.com cannot open neither
        if (tweetResults == null || !tweetResults.containsKey('result')) continue;

        final result = _unwrapTweetResult(tweetResults['result']);
        if (result != null) {
          replies.add(
            TweetChain(id: result['rest_id'], tweets: [TweetWithCard.fromGraphqlJson(result)], isPinned: false),
          );
        } else {
          replies.add(TweetChain(id: entryId.substring(6), tweets: [TweetWithCard.tombstone({})], isPinned: false));
        }
      }

      if (entryId.startsWith('cursor-bottom') || entryId.startsWith('cursor-showMore')) {
        // TODO: Use as the "next page" cursor
      }

      if (entryId.startsWith('conversationthread')) {
        // TODO: This is missing tombstone support
        replies.add(
          TweetChain(
            id: entryId.replaceFirst('conversationthread-', ''),
            tweets: _conversationTweets(entry, skipPromoted: true),
            isPinned: false,
          ),
        );
      }
    }

    return replies;
  }

  static List<TweetChain> createTweets(List<dynamic> addEntries, [bool isPinned = false]) {
    List<TweetChain> replies = [];

    // Deleted or restricted posts come back without a usable result; they must
    // be skipped so one bad entry cannot break the whole page.
    Map<String, dynamic>? usableResult(dynamic container) =>
        _unwrapTweetResult(container?['itemContent']?['tweet_results']?['result']);

    for (var entry in addEntries) {
      var entryId = entry?['entryId'] as String?;
      if (entryId == null) {
        continue;
      }
      if (entryId.startsWith('tweet-')) {
        var result = usableResult(entry['content']);
        if (result != null) {
          replies.add(
            TweetChain(id: result['rest_id'], tweets: [TweetWithCard.fromGraphqlJson(result)], isPinned: isPinned),
          );
        }
      } else if (entryId.startsWith('profile-grid-')) {
        // We got a tweet queried from the media tab
        for (var mediaTweet in List.from(entry['content']?['items'] ?? [])) {
          var result = usableResult(mediaTweet['item']);
          if (result != null) {
            replies.add(
              TweetChain(id: result['rest_id'], tweets: [TweetWithCard.fromGraphqlJson(result)], isPinned: isPinned),
            );
          }
        }
      }

      if (entryId.startsWith('cursor-bottom') || entryId.startsWith('cursor-showMore')) {
        // TODO: Use as the "next page" cursor
      }

      if (entryId.startsWith('profile-conversation')) {
        // TODO: This is missing tombstone support
        replies.add(
          TweetChain(
            id: entryId.replaceFirst('profile-conversation-', ''),
            tweets: _conversationTweets(entry, skipPromoted: false),
            isPinned: false,
          ),
        );
      }
    }
    return replies;
  }

  static TweetStatus createChainsFromGridModule(Map<String, dynamic> timeline) {
    var instructions = List.from(timeline['timeline']?['instructions'] ?? []);
    var addEntries = List.from(
      instructions.firstWhereOrNull((e) => e['type'] == 'TimelineAddEntries')?['entries'] ?? [],
    );
    var addModItems = List.from(
      instructions.firstWhereOrNull((e) => e['type'] == 'TimelineAddToModule')?['moduleItems'] ?? [],
    );
    var repEntries = List.from(instructions.where((e) => e['type'] == 'TimelineReplaceEntry'));

    String? cursorBottom = getCursor(addEntries, repEntries, 'cursor-bottom', 'Bottom');
    String? cursorTop = getCursor(addEntries, repEntries, 'cursor-top', 'Top');

    var moduleItems = [
      ...addEntries
          .where((e) => e['content']?['entryType'] == 'TimelineTimelineModule')
          .expand((e) => List.from(e['content']?['items'] ?? [])),
      ...addModItems,
    ];

    List<TweetChain> chains = [];
    for (var item in moduleItems) {
      var result =
          item['item']?['itemContent']?['tweet_results']?['result'] ??
          item['item']?['content']?['tweetResult']?['result'] ??
          item['item']?['content']?['tweet_results']?['result'];
      result = result?['rest_id'] != null ? result : result?['tweet'];
      if (result?['rest_id'] == null) continue;
      chains.add(TweetChain(id: result['rest_id'], tweets: [TweetWithCard.fromGraphqlJson(result)], isPinned: false));
    }

    return TweetStatus(chains: chains, cursorBottom: cursorBottom, cursorTop: cursorTop);
  }

  static String? getCursor(List<dynamic> addEntries, List<dynamic> repEntries, String legacyType, String type) {
    String? cursor;

    Map<String, dynamic>? cursorEntry;

    var isLegacyCursor = addEntries.any((element) => element['entryId'].startsWith('cursor'));
    if (isLegacyCursor) {
      cursorEntry = addEntries.firstWhere((e) => e['entryId'].contains(legacyType), orElse: () => null);
    } else {
      cursorEntry = addEntries
          .where((e) => e['entryId'].startsWith('sq-C'))
          .firstWhere((e) => e['content']['operation']['cursor']['cursorType'] == type, orElse: () => null);
    }

    if (cursorEntry != null) {
      var content = cursorEntry['content'];
      if (content.containsKey('value')) {
        cursor = content['value'];
      } else if (content.containsKey('operation')) {
        cursor = content['operation']['cursor']['value'];
      } else {
        cursor = content['itemContent']['value'];
      }
    } else {
      // Look for a "replaceEntry" with the cursor
      var cursorReplaceEntry = repEntries.firstWhere(
        (e) => e.containsKey('replaceEntry')
            ? e['replaceEntry']['entryIdToReplace'].contains(type)
            : e['entry']['content']['cursorType'].contains(type),
        orElse: () => null,
      );

      if (cursorReplaceEntry != null) {
        cursor = cursorReplaceEntry.containsKey('replaceEntry')
            ? cursorReplaceEntry['replaceEntry']['entry']['content']['operation']['cursor']['value']
            : cursorReplaceEntry['entry']['content']['value'];
      }
    }

    return cursor;
  }

  static TweetStatus createUnconversationedChainsGraphql(
    Map<String, dynamic> result,
    String tweetIndicator,
    List<String> pinnedTweets,
    bool mapToThreads,
    bool includeReplies,
  ) {
    var instructions = List.from(result['timeline']['instructions']);
    if (instructions.isEmpty || !instructions.any((e) => e['type'] == 'TimelineAddEntries')) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    var addEntries = List.from(instructions.firstWhere((e) => e['type'] == 'TimelineAddEntries')['entries']);
    var repEntries = List.from(instructions.where((e) => e['type'] == 'TimelineReplaceEntry'));

    String? cursorBottom = getCursor(addEntries, repEntries, 'cursor-bottom', 'Bottom');
    String? cursorTop = getCursor(addEntries, repEntries, 'cursor-top', 'Top');

    var tweets = _createTweetsGraphql(tweetIndicator, addEntries, includeReplies);

    // First, get all the IDs of the tweets we need to display.
    String? entryRestId(dynamic e) {
      var result = e['content']?['itemContent']?['tweet_results']?['result'];
      return result?['rest_id'] ?? result?['tweet']?['rest_id'];
    }

    var tweetEntries = addEntries
        .where((e) => e['entryId'].contains(tweetIndicator) && entryRestId(e) != null)
        .sorted((a, b) => b['sortIndex'].compareTo(a['sortIndex']))
        .map(entryRestId)
        .cast<String?>()
        .toList();

    Map<String, List<TweetWithCard>> conversations = tweets.values.where((e) => tweetEntries.contains(e.idStr)).groupBy(
      (e) {
        // TODO: I don't think a flag is the right way to handle this
        if (mapToThreads) {
          // Then group the tweets-to-display by their conversation ID
          return e.conversationIdStr;
        }

        return e.idStr;
      },
    ).cast<String, List<TweetWithCard>>();

    List<TweetChain> chains = [];

    // Order all the conversations by newest first (assuming the ID is an incrementing key), and create a chain from them
    for (var conversation in conversations.entries.sorted((a, b) => b.key.compareTo(a.key))) {
      var chainTweets = conversation.value.sorted((a, b) => a.idStr!.compareTo(b.idStr!)).toList();

      chains.add(TweetChain(id: conversation.key, tweets: chainTweets, isPinned: false));
    }

    // If we want to show pinned tweets, add them before the chains that we already have
    if (pinnedTweets.isNotEmpty) {
      for (var id in pinnedTweets) {
        // It's possible for the pinned tweet to either not exist, or not be returned, so handle that
        if (tweets.containsKey(id)) {
          chains.insert(0, TweetChain(id: id, tweets: [tweets[id]!], isPinned: true));
        }
      }
    }

    return TweetStatus(chains: chains, cursorBottom: cursorBottom, cursorTop: cursorTop);
  }

  static TweetStatus createUnconversationedChains(
    Map<String, dynamic> result,
    String tweetIndicator,
    List<String> pinnedTweets,
    bool mapToThreads,
    bool includeReplies,
    bool showPinnedTweet,
    int Function() getTweetsCounter,
    void Function() increaseTweetCounter,
  ) {
    final timeline =
        result["data"]?["user"]?["result"]?["timeline_v2"] ?? result["data"]?["user"]?["result"]?["timeline"];
    var instructions = List.from(timeline?['timeline']?['instructions'] ?? []);
    var addEntriesInstructions = instructions.firstWhereOrNull((e) => e['type'] == 'TimelineAddEntries');
    var addModEntriesInstructions = instructions.firstWhereOrNull((e) => e['type'] == 'TimelineAddToModule');
    List addModEntries = List.from(addModEntriesInstructions?['moduleItems'] ?? []);

    if (addEntriesInstructions == null && addModEntries.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    var addPinnedTweetsInstructions = instructions.firstWhereOrNull((e) => e['type'] == 'TimelinePinEntry');
    var addEntries = List.from(addEntriesInstructions?['entries'] ?? []);
    var repEntries = List.from(instructions.where((e) => e['type'] == 'TimelineReplaceEntry'));
    List addPinnedEntries = List<dynamic>.empty(growable: true);
    if (addPinnedTweetsInstructions != null) {
      addPinnedEntries.add(addPinnedTweetsInstructions['entry']);
    }

    String? cursorBottom = getCursor(addEntries, repEntries, 'cursor-bottom', 'Bottom');
    String? cursorTop = getCursor(addEntries, repEntries, 'cursor-top', 'Top');

    var chains = createTweets(addEntries);
    // var debugTweets = json.encode(chains);
    //var debugTweets2 = json.encode(addEntries);
    var pinnedChains = createTweets(addPinnedEntries, true);

    for (final addModEntry in addModEntries) {
      final entryId = addModEntry['entryId'] as String? ?? addModEntry['entry_id'] as String? ?? '';
      if (entryId.startsWith('profile-grid-')) {
        Map<String, dynamic>? result = addModEntry['item']?['content']?['tweetResult']?['result'];
        result ??= addModEntry['item']?['itemContent']?['tweet_results']?['result'];
        result ??= addModEntry['item']?['content']?['tweet_results']?['result'];
        if (result != null) {
          result = result['rest_id'] != null ? result : result['tweet'];
          if (result != null) {
            chains.add(
              TweetChain(id: result['rest_id'], tweets: [TweetWithCard.fromGraphqlJson(result)], isPinned: false),
            );
          }
        }
      }
    }

    //If we want to show pinned tweets, add them before the others that we already have
    if (pinnedTweets.isNotEmpty & showPinnedTweet) {
      chains.insertAll(0, pinnedChains);
    }
    //To prevent infinte loading of tweets while filtering via regex , we have to count added tweets.
    //(infinite loading originating in paged_silver_builder.dart at line 246)
    //As soon as there is no tweet left that passes regex critera and we also reached maximum attemps
    //to find them, than stop loading more.
    if (chains.length < 5) {
      increaseTweetCounter();
      if (getTweetsCounter() > 5) {
        cursorBottom = null;
      }
    }
    return TweetStatus(chains: chains, cursorBottom: cursorBottom, cursorTop: cursorTop);
  }

  static TweetStatus createTimelineChains(
    Map<String, dynamic> result,
    String tweetIndicator,
    List<String> pinnedTweets,
    bool mapToThreads,
    bool includeReplies,
    bool showPinnedTweet,
    int Function() getTweetsCounter,
    void Function() increaseTweetCounter,
  ) {
    var instructions = List.from(result["data"]["home"]["home_timeline_urt"]['instructions']);
    var addEntriesInstructions = instructions.firstWhereOrNull((e) => e['type'] == 'TimelineAddEntries');
    if (addEntriesInstructions == null) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }
    var addPinnedTweetsInstructions = instructions.firstWhereOrNull((e) => e['type'] == 'TimelinePinEntry');
    var addEntries = List.from(addEntriesInstructions['entries']);
    var repEntries = List.from(instructions.where((e) => e['type'] == 'TimelineReplaceEntry'));
    List addPinnedEntries = List<dynamic>.empty(growable: true);
    if (addPinnedTweetsInstructions != null) {
      addPinnedEntries.add(addPinnedTweetsInstructions['entry']);
    }

    String? cursorBottom = getCursor(addEntries, repEntries, 'cursor-bottom', 'Bottom');
    String? cursorTop = getCursor(addEntries, repEntries, 'cursor-top', 'Top');
    var chains = createTweets(addEntries);
    // var debugTweets = json.encode(chains);
    //var debugTweets2 = json.encode(addEntries);
    var pinnedChains = createTweets(addPinnedEntries, true);

    //If we want to show pinned tweets, add them before the others that we already have
    if (pinnedTweets.isNotEmpty & showPinnedTweet) {
      chains.insertAll(0, pinnedChains);
    }
    //To prevent infinte loading of tweets while filtering via regex , we have to count added tweets.
    //(infinite loading originating in paged_silver_builder.dart at line 246)
    //As soon as there is no tweet left that passes regex critera and we also reached maximum attemps
    //to find them, than stop loading more.
    if (chains.length < 5) {
      increaseTweetCounter();
      if (getTweetsCounter() > 5) {
        cursorBottom = null;
      }
    }

    return TweetStatus(chains: chains, cursorBottom: cursorBottom, cursorTop: cursorTop);
  }

  static Map<String, TweetWithCard> _createTweetsGraphql(
    String entryPrefix,
    List<dynamic> allTweets,
    bool includeReplies,
  ) {
    bool includeTweet(dynamic t) {
      // Exclude any items that aren't tweets
      if (!t['entryId'].startsWith(entryPrefix)) {
        return false;
      }

      if (t['content']['itemContent']['promotedMetadata'] != null) {
        return false;
      }

      if (t['content']?['itemContent']?['tweet_results']?['result'] == null) {
        return false;
      }

      return true;
    }

    var filteredTweets = allTweets.where(includeTweet);

    var globalTweets = List.from(
      filteredTweets.map((e) {
        var elm = e['content']['itemContent']['tweet_results']['result'];
        if (elm['rest_id'] == null && elm['tweet'] != null) {
          elm = elm['tweet'];
        }

        return elm;
      }),
    );

    var tweets = [];
    try {
      tweets = globalTweets.map((e) => TweetWithCard.fromGraphqlJson(e)).toList();
    } catch (exc) {
      rethrow;
    }

    // include replies only if we should
    tweets = tweets.where((tweet) {
      if (!includeReplies && (tweet.inReplyToStatusIdStr != null || tweet.inReplyToUserIdStr != null)) {
        return false;
      }
      return true;
    }).toList();

    return {for (var e in tweets) e.idStr: e};
  }
}
