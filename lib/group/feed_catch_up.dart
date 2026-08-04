import 'package:xta/constants.dart';

/// Catch-up mode is per feed, so its preference key carries the group id.
String feedCatchUpModeKey(String groupId) => '$optionFeedCatchUpModePrefix$groupId';

/// Whether a chunk's gap-fill still has ground to cover: every post on the page
/// just fetched is newer than the newest stored one, and there is a cursor to
/// follow down towards them.
///
/// It is both the loop condition and, evaluated once the loop has stopped, the
/// answer to "did we run out of allowance rather than catch up?" — which is the
/// only reason the app can claim, or must not claim, that a reader has seen
/// everything.
bool feedGapRemains({
  required BigInt? storedNewestId,
  required BigInt? oldestFetchedId,
  required String? cursorBottom,
  required bool pageHasChains,
}) {
  if (storedNewestId == null || cursorBottom == null || !pageHasChains) {
    return false;
  }
  return (oldestFetchedId ?? BigInt.zero) > storedNewestId;
}
