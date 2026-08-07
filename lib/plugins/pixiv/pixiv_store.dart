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

  /// First load shows the store loading state; later pulls keep the grid up
  /// (Pixez-style soft refresh — no decode waterfall from a blank spinner).
  Future<void> refresh() async {
    if (state.isNotEmpty) {
      final page = await _loader();
      _nextUrl = page.nextUrl;
      update(_applyFilter(page.illusts));
      return;
    }

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
    update(state);
    try {
      final page = await _loader(nextUrl: _nextUrl);
      _nextUrl = page.nextUrl;
      update(mergePixivIllusts(state, _applyFilter(page.illusts)));
    } catch (e) {
      // Keep a healthy grid — only first-page failures become full errors.
      if (state.isEmpty) {
        setError(e);
      } else {
        update(state);
      }
    } finally {
      _loadingMore = false;
      if (state.isNotEmpty) {
        update(state);
      }
    }
  }

  List<PixivIllust> _applyFilter(List<PixivIllust> illusts) {
    return filter == null ? illusts : filter!(illusts);
  }
}

/// Append [incoming] skipping ids already in [existing].
List<PixivIllust> mergePixivIllusts(
  List<PixivIllust> existing,
  List<PixivIllust> incoming,
) {
  if (incoming.isEmpty) {
    return existing;
  }
  final seen = {for (final illust in existing) illust.id};
  return [
    ...existing,
    for (final illust in incoming)
      if (seen.add(illust.id)) illust,
  ];
}

/// Following-timeline store kept for the plugin home tab and uninstall wipe.
class PixivFeedStore extends PixivIllustListStore {
  PixivFeedStore(PixivClient client, {PixivIllustListFilter? filter})
    : super(({nextUrl}) => client.following(nextUrl: nextUrl), filter: filter);
}
