import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';

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
  });
}
