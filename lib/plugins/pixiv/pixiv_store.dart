import 'package:flutter_triple/flutter_triple.dart';
import 'package:xta/plugins/pixiv/pixiv_client.dart';
import 'package:xta/plugins/pixiv/pixiv_models.dart';

/// Following-timeline state for the Pixiv home tab.
class PixivFeedStore extends Store<List<PixivIllust>> {
  final PixivClient client;

  String? _nextUrl;
  bool _loadingMore = false;

  PixivFeedStore(this.client) : super(const []);

  bool get hasMore => _nextUrl != null && _nextUrl!.isNotEmpty;
  bool get loadingMore => _loadingMore;

  Future<void> refresh() async {
    await execute(() async {
      final page = await client.following();
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
      final page = await client.following(nextUrl: _nextUrl);
      _nextUrl = page.nextUrl;
      final merged = [...state, ...page.illusts];
      update(merged);
    } catch (e) {
      setError(e);
    } finally {
      _loadingMore = false;
    }
  }
}
