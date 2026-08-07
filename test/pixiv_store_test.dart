import 'package:flutter_test/flutter_test.dart';
import 'package:xta/plugins/pixiv/pixiv_client.dart';
import 'package:xta/plugins/pixiv/pixiv_models.dart';
import 'package:xta/plugins/pixiv/pixiv_store.dart';

PixivIllust _illust(int id) => PixivIllust(
      id: id,
      title: 't$id',
      caption: '',
      type: 'illust',
      thumbnailUrl: 'https://i.pximg.net/$id.jpg',
      pageCount: 1,
      userId: 1,
      userName: 'a',
      userAccount: 'a',
    );

void main() {
  group('mergePixivIllusts', () {
    test('appends only new ids', () {
      final merged = mergePixivIllusts(
        [_illust(1), _illust(2)],
        [_illust(2), _illust(3)],
      );

      expect(merged.map((e) => e.id), [1, 2, 3]);
    });
  });

  group('PixivIllustListStore', () {
    test('soft refresh keeps prior tiles while replacing contents', () async {
      var calls = 0;
      final store = PixivIllustListStore(({nextUrl}) async {
        calls++;
        return PixivIllustPage(illusts: [_illust(calls)]);
      });

      await store.refresh();
      expect(store.state.single.id, 1);

      await store.refresh();
      expect(store.state.single.id, 2);
      expect(calls, 2);
    });

    test('loadMore dedupes and does not wipe the list on append failure', () async {
      var page = 0;
      final store = PixivIllustListStore(({nextUrl}) async {
        page++;
        if (page == 1) {
          return PixivIllustPage(
            illusts: [_illust(1)],
            nextUrl: 'https://example/next',
          );
        }
        if (page == 2) {
          return PixivIllustPage(
            illusts: [_illust(1), _illust(2)],
            nextUrl: 'https://example/next2',
          );
        }
        throw PixivException(PixivErrorKind.network, 'boom');
      });

      await store.refresh();
      await store.loadMore();
      expect(store.state.map((e) => e.id), [1, 2]);
      expect(store.loadingMore, isFalse);

      await store.loadMore();
      expect(store.state.map((e) => e.id), [1, 2]);
      expect(store.error, isNull);
    });
  });
}
