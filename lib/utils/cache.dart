import 'package:ffcache/ffcache.dart';
import 'package:logging/logging.dart';

extension CacheHelper<T> on FFCache {
  static final log = Logger('CacheHelper');

  /// Returns [key] from the cache, or asks [create] for it and caches that.
  ///
  /// The cache is an optimisation, never a dependency: Android is free to empty
  /// the app's cache directory while the app is running, and FFCache only
  /// creates that directory once per process. Both halves therefore have to
  /// survive it — a read that fails falls through to [create], and a write that
  /// fails still returns the value that was fetched. Letting either throw meant
  /// an emptied cache directory showed up as "the trend regions could not be
  /// found".
  Future<String> getOrCreateAsJSON(String key, Duration expiry, Future<String> Function() create) async {
    final cached = await _cachedJSON(key);
    if (cached != null) {
      log.info('Loading $key from the cache');
      return cached;
    }

    log.info('Loading $key from the source');

    var result = await create();

    try {
      await setJSONWithTimeout(key, result, expiry);
    } catch (e) {
      log.warning('Unable to cache $key: $e');
    }

    return result;
  }

  /// The cached value, or null if there isn't a usable one.
  ///
  /// [has] and [getJSON] are two separate trips to the filesystem, so the file
  /// can go missing between them — the answer has to be re-checked, not assumed
  /// from the first call.
  Future<String?> _cachedJSON(String key) async {
    try {
      if (!await has(key)) {
        return null;
      }
      return await getJSON(key) as String?;
    } catch (e) {
      log.warning('Unable to read $key from the cache: $e');
      return null;
    }
  }
}
