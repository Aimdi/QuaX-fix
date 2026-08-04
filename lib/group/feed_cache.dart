import 'dart:convert';

import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/utils/iterables.dart';
import 'package:sqflite/sqflite.dart';

/// Helpers for reading the tweets cached in [tableFeedGroupChunk]. Shared so the
/// feed loader and the "show cached tweets while loading" previews build their
/// chains identically.

List<TweetChain> chainsFromStoredChunks(List<Map<String, Object?>> storedChunks) {
  return storedChunks
      .map((e) => jsonDecode(e['response'] as String))
      .map((e) => List.from(e))
      .expand((e) => e.map((c) => TweetChain.fromJson(c)))
      .toList();
}

/// Keeps only the first occurrence of each chain id. Stored chunk rows and
/// successive search windows overlap at their boundaries, so the same chain
/// routinely appears in several sources.
List<TweetChain> dedupeChainsById(List<TweetChain> chains) {
  var seen = <String>{};
  return chains.where((c) => seen.add(c.id)).toList();
}

List<TweetChain> sortChainsNewestFirst(List<TweetChain> chains) {
  return chains.sorted((a, b) {
    var aCreatedAt = a.tweets[0].createdAt;
    var bCreatedAt = b.tweets[0].createdAt;

    if (aCreatedAt == null || bCreatedAt == null) {
      return 0;
    }

    return bCreatedAt.compareTo(aCreatedAt);
  }).toList();
}

/// Cached chains together with when the newest row behind them was written, so
/// a feed showing them after a failed refresh can say how old they are.
typedef CachedChains = ({List<TweetChain> chains, DateTime? cachedAt});

DateTime? _newer(DateTime? a, DateTime? b) => a == null ? b : (b == null || a.isAfter(b) ? a : b);

/// `created_at` defaults to SQLite's `CURRENT_TIMESTAMP`, which is UTC written
/// without a zone ("2026-08-04 12:00:00"). [DateTime.tryParse] reads that as
/// local time, which would make a cache written a minute ago look hours old (or
/// in the future), so the zoneless form is pinned to UTC first.
DateTime? parseChunkTimestamp(Object? raw) {
  if (raw is! String) {
    return null;
  }
  var text = raw.trim();
  if (text.isEmpty) {
    return null;
  }
  var zoned = text.contains('T') || text.endsWith('Z') ? text : '${text}Z';
  return DateTime.tryParse(zoned)?.toLocal();
}

/// The most recent `created_at` across [rows], ignoring unparseable ones.
DateTime? newestChunkTimestamp(Iterable<Map<String, Object?>> rows) =>
    rows.map((e) => parseChunkTimestamp(e['created_at'])).fold<DateTime?>(null, _newer);

/// Cached tweets for the given chunk [hashes], newest first, capped at
/// [maxCachedChunkRows] rows per hash.
Future<CachedChains> readCachedChainsForHashes(Database repository, Iterable<String> hashes) async {
  var chains = <TweetChain>[];
  DateTime? cachedAt;
  for (var hash in hashes) {
    var storedChunks = await repository.query(tableFeedGroupChunk,
        where: 'hash = ?', whereArgs: [hash], orderBy: 'created_at DESC', limit: maxCachedChunkRows);
    chains.addAll(chainsFromStoredChunks(storedChunks));
    cachedAt = _newer(cachedAt, newestChunkTimestamp(storedChunks));
  }
  return (chains: sortChainsNewestFirst(dedupeChainsById(chains)), cachedAt: cachedAt);
}

/// The newest cached tweets across all chunks, de-duplicated. Used to preview
/// the combined "All"/Following feed while its subscription list loads, before
/// the per-chunk hashes are known. This runs from the home tab's `initState`,
/// so it is capped hard: it only has to fill the screen the reader is waiting
/// for, and every extra row is JSON decoded ahead of the first paint.
Future<CachedChains> readAllCachedChains(Database repository) async {
  var storedChunks =
      await repository.query(tableFeedGroupChunk, orderBy: 'created_at DESC', limit: maxCachedChunkRows);
  return (
    chains: sortChainsNewestFirst(dedupeChainsById(chainsFromStoredChunks(storedChunks))),
    cachedAt: newestChunkTimestamp(storedChunks),
  );
}
