import 'package:flutter_test/flutter_test.dart';
import 'package:xta/client/client.dart';

/// X ends a conversation it has censored with a "Show additional replies"
/// prompt rather than more replies. The cursor behind that prompt was parsed
/// and discarded, so those replies were unreachable.
///
/// The entry id has been spelled several ways across X's revisions, and the
/// value has lived in three different places inside `content`, so these pin
/// the shapes we accept — and, just as importantly, that an unrecognised shape
/// yields null instead of an exception or a prompt that leads nowhere.
List<dynamic> _entries(String entryId, Map<String, dynamic> content) => [
      {
        'entryId': 'tweet-1',
        'content': {
          'itemContent': {
            'tweet_results': {
              'result': {
                'rest_id': '1',
                'legacy': {'id_str': '1', 'full_text': 'hello'},
              },
            },
          },
        },
      },
      {'entryId': entryId, 'content': content},
    ];

void main() {
  group('TimelineParser.getShowMoreCursor', () {
    test('reads the value X puts directly on content', () {
      final entries = _entries('cursor-showMore-8', {'value': 'SHOWMORE-A'});

      expect(TimelineParser.getShowMoreCursor(entries), 'SHOWMORE-A');
    });

    test('reads the operation shape', () {
      final entries = _entries('cursor-showmorethreads-9', {
        'operation': {
          'cursor': {'value': 'SHOWMORE-B', 'cursorType': 'ShowMoreThreads'},
        },
      });

      expect(TimelineParser.getShowMoreCursor(entries), 'SHOWMORE-B');
    });

    test('reads the itemContent shape', () {
      final entries = _entries('cursor-showmorethreadsprompt-10', {
        'itemContent': {'value': 'SHOWMORE-C', 'cursorType': 'ShowMoreThreadsPrompt'},
      });

      expect(TimelineParser.getShowMoreCursor(entries), 'SHOWMORE-C');
    });

    test('matches the entry id whatever case X spells it in', () {
      final entries = _entries('CURSOR-SHOWMORE-11', {'value': 'SHOWMORE-D'});

      expect(TimelineParser.getShowMoreCursor(entries), 'SHOWMORE-D');
    });

    test('ignores the ordinary bottom cursor, which is automatic paging', () {
      final entries = _entries('cursor-bottom-12', {'value': 'BOTTOM'});

      expect(TimelineParser.getShowMoreCursor(entries), isNull);
    });

    test('a conversation with nothing withheld offers no cursor', () {
      final entries = [
        {
          'entryId': 'tweet-1',
          'content': {
            'itemContent': {
              'tweet_results': {
                'result': {
                  'rest_id': '1',
                  'legacy': {'id_str': '1', 'full_text': 'hello'},
                },
              },
            },
          },
        },
      ];

      expect(TimelineParser.getShowMoreCursor(entries), isNull);
    });

    test('a shape we do not recognise yields null rather than throwing', () {
      // The prompt is only offered when a cursor was found, so anything
      // unreadable degrades to exactly the old behaviour.
      for (final content in <dynamic>[
        null,
        'not a map',
        <String, dynamic>{},
        {'operation': <String, dynamic>{}},
        {'itemContent': null},
        {'value': 12345},
      ]) {
        final entries = [
          {'entryId': 'cursor-showmore-13', 'content': content},
        ];

        expect(TimelineParser.getShowMoreCursor(entries), isNull, reason: 'content: $content');
      }

      expect(TimelineParser.getShowMoreCursor([null]), isNull);
      expect(TimelineParser.getShowMoreCursor([<String, dynamic>{}]), isNull);
      expect(TimelineParser.getShowMoreCursor(const []), isNull);
    });

    test('reads a show-more cursor nested inside a conversationthread module', () {
      final entries = [
        {
          'entryId': 'tweet-1',
          'content': {
            'itemContent': {
              'tweet_results': {
                'result': {
                  'rest_id': '1',
                  'legacy': {'id_str': '1', 'full_text': 'hello', 'reply_count': 2},
                },
              },
            },
          },
        },
        {
          'entryId': 'conversationthread-9',
          'content': {
            'items': [
              {
                'entryId': 'conversationthread-9-cursor-showmore-9',
                'item': {
                  'itemContent': {
                    'itemType': 'TimelineTimelineCursor',
                    'cursorType': 'ShowMoreThreads',
                    'value': 'SHOWMORE-NESTED',
                  },
                },
              },
            ],
          },
        },
      ];

      expect(TimelineParser.getShowMoreCursor(entries), 'SHOWMORE-NESTED');
      expect(
        TimelineParser.createTweetChains(entries),
        hasLength(1),
        reason: 'a module with only a cursor must not become an empty reply chain',
      );
    });

    test('prefers a top-level show-more cursor over a nested one', () {
      final entries = [
        {
          'entryId': 'conversationthread-9',
          'content': {
            'items': [
              {
                'entryId': 'conversationthread-9-cursor-showmore-9',
                'item': {
                  'itemContent': {'value': 'NESTED'},
                },
              },
            ],
          },
        },
        {
          'entryId': 'cursor-showMore-8',
          'content': {'value': 'TOP'},
        },
      ];

      expect(TimelineParser.getShowMoreCursor(entries), 'TOP');
    });
  });

  group('TimelineParser.hasRepliesOrShowMore', () {
    TweetChain chain(String id) => TweetChain(
      id: id,
      tweets: [
        TweetWithCard()
          ..idStr = id
          ..fullText = 't',
      ],
      isPinned: false,
    );

    test('is true when a show-more cursor is present even without reply chains', () {
      final status = TweetStatus(
        chains: [chain('1')],
        cursorBottom: null,
        cursorTop: null,
        cursorShowMore: 'X',
      );
      expect(TimelineParser.hasRepliesOrShowMore(status, '1'), isTrue);
    });

    test('is true when a reply chain follows the focal tweet', () {
      final status = TweetStatus(chains: [chain('1'), chain('2')], cursorBottom: null, cursorTop: null);
      expect(TimelineParser.hasRepliesOrShowMore(status, '1'), isTrue);
    });

    test('is false for a focal-only page with no show-more', () {
      final status = TweetStatus(chains: [chain('1')], cursorBottom: null, cursorTop: null);
      expect(TimelineParser.hasRepliesOrShowMore(status, '1'), isFalse);
    });
  });
}
