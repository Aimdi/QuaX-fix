import 'package:flutter_triple/flutter_triple.dart';
import 'package:xta/plugins/pixiv/pixiv_client.dart';
import 'package:xta/plugins/pixiv/pixiv_models.dart';

typedef PixivIllustPageLoader = Future<PixivIllustPage> Function({String? nextUrl});

/// Paginated illust list — following, ranking, bookmarks, search, related.
class PixivIllustListStore extends Store<List<PixivIllust>> {
  PixivIllustPageLoader _loader;

  String? _nextUrl;
  bool _loadingMore = false;

  PixivIllustListStore(this._loader) : super(const []);

  bool get hasMore => _nextUrl != null && _nextUrl!.isNotEmpty;
  bool get loadingMore => _loadingMore;

  /// Swap the source (e.g. ranking mode) and clear the list.
  void useLoader(PixivIllustPageLoader loader) {
    _loader = loader;
    _nextUrl = null;
  }

  Future<void> refresh() async {
    await execute(() async {
      final page = await _loader();
      _nextUrl = page.nextUrl;
      return page.illusts;
    });
  }

  Future<void> loadMore() async {
    if (_loadingMore || !hasMore) {
      return;
    }
    _loadingMore = true;
    try {
      final page = await _loader(nextUrl: _nextUrl);
      _nextUrl = page.nextUrl;
      update([...state, ...page.illusts]);
    } catch (e) {
      setError(e);
    } finally {
      _loadingMore = false;
    }
  }
}

/// Following-timeline store kept for the plugin home tab and uninstall wipe.
class PixivFeedStore extends PixivIllustListStore {
  PixivFeedStore(PixivClient client) : super(({nextUrl}) => client.following(nextUrl: nextUrl));
}
