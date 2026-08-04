import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/utils/bounded.dart';

void main() {
  group('mapBounded', () {
    test('keeps the order of the input, not of completion', () async {
      final completers = List.generate(4, (_) => Completer<int>());

      final pending = mapBounded(List.generate(4, (i) => i), (i) => completers[i].future, concurrency: 4);

      // Finish them backwards.
      for (final i in [3, 2, 1, 0]) {
        completers[i].complete(i * 10);
      }

      expect(await pending, [0, 10, 20, 30]);
    });

    test('never has more than `concurrency` in flight', () async {
      var inFlight = 0;
      var peak = 0;

      final result = await mapBounded(List.generate(13, (i) => i), (i) async {
        inFlight++;
        peak = inFlight > peak ? inFlight : peak;
        await Future<void>.delayed(Duration.zero);
        inFlight--;

        return i;
      }, concurrency: 4);

      expect(peak, lessThanOrEqualTo(4), reason: 'thirteen chunks must not open thirteen connections');
      expect(result, hasLength(13));
    });

    test('runs everything even when there are more items than workers', () async {
      final seen = <int>[];

      await mapBounded(List.generate(10, (i) => i), (i) async {
        await Future<void>.delayed(Duration.zero);
        seen.add(i);

        return i;
      }, concurrency: 3);

      expect(seen..sort(), List.generate(10, (i) => i));
    });

    test('an empty list does no work', () async {
      var called = false;

      expect(
        await mapBounded<int, int>(const [], (i) async {
          called = true;

          return i;
        }),
        isEmpty,
      );
      expect(called, isFalse);
    });

    test('a throwing task propagates', () async {
      expect(
        mapBounded(List.generate(3, (i) => i), (i) async => i == 1 ? throw StateError('boom') : i),
        throwsStateError,
      );
    });
  });
}
