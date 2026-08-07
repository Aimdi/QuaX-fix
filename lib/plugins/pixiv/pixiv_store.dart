import 'package:flutter_triple/flutter_triple.dart';
import 'package:xta/plugins/pixiv/pixiv_client.dart';
import 'package:xta/plugins/pixiv/pixiv_models.dart';

typedef PixivIllustPageLoader =
    Future<PixivIllustPage> Function({String? nextUrl});
typedef PixivIllustListFilter =
    List<PixivIllust> Function(List<PixivIllust> illusts);

/// Paginated illust list — following, ranking, bookmarks, search, related.
class PixivIllustListStore extends Store<List<PixivIllust>> {
  PixivIllustPageLoader _loader;
  PixivIllustListFilter? filter;

  String? _nextUrl;
  bool _loadingMore = false;

  PixivIllustListStore(this._loader, {this.filter}) : super(const []);

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
      return _applyFilter(page.illusts);
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
      update([...state, ..._applyFilter(page.illusts)]);
    } catch (e) {
      setError(e);
    } finally {
      _loadingMore = false;
    }
  }

  List<PixivIllust> _applyFilter(List<PixivIllust> illusts) {
    return filter == null ? illusts : filter!(illusts);
  }
}

/// Following-timeline store kept for the plugin home tab and uninstall wipe.
class PixivFeedStore extends PixivIllustListStore {
  PixivFeedStore(PixivClient client, {PixivIllustListFilter? filter})
    : super(({nextUrl}) => client.following(nextUrl: nextUrl), filter: filter);
}
