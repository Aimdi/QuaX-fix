import 'package:flutter_test/flutter_test.dart';
import 'package:xta/plugins/pixiv/pixiv_models.dart';

void main() {
  group('parsePixivIllustList', () {
    final sample = {
      'illusts': [
        {
          'id': 42,
          'title': 'Cat',
          'caption': 'meow',
          'type': 'illust',
          'image_urls': {
            'square_medium': 'https://i.pximg.net/c/360x360_70/img-master/cat.jpg',
            'medium': 'https://i.pximg.net/c/540x540_70/img-master/cat.jpg',
            'large': 'https://i.pximg.net/c/600x1200_90/img-master/cat.jpg',
          },
          'user': {
            'id': 7,
            'name': 'Artist',
            'account': 'artist',
            'profile_image_urls': {'medium': 'https://i.pximg.net/user.jpg'},
          },
          'create_date': '2026-08-01T09:00:00+09:00',
          'page_count': 2,
          'total_bookmarks': 10,
          'total_view': 100,
          'x_restrict': 0,
          'sanity_level': 2,
        },
        {
          'id': 99,
          'title': 'R18',
          'caption': '',
          'type': 'illust',
          'image_urls': {
            'square_medium': 'https://i.pximg.net/r18.jpg',
          },
          'user': {'id': 1, 'name': 'X', 'account': 'x', 'profile_image_urls': {}},
          'page_count': 1,
          'x_restrict': 1,
          'sanity_level': 6,
        },
      ],
      'next_url': 'https://app-api.pixiv.net/v2/illust/follow?offset=30',
    };

    test('reads fields and filters R-18 by default', () {
      final posts = parsePixivIllustList(sample);

      expect(posts, hasLength(1));
      expect(posts.first.id, 42);
      expect(posts.first.title, 'Cat');
      expect(posts.first.userName, 'Artist');
      expect(posts.first.pageCount, 2);
      expect(posts.first.url, 'https://www.pixiv.net/artworks/42');
      expect(posts.first.thumbnailUrl, contains('cat.jpg'));
    });

    test('keeps R-18 when asked', () {
      expect(parsePixivIllustList(sample, includeR18: true), hasLength(2));
    });

    test('a reshaped payload yields nothing rather than throwing', () {
      expect(parsePixivIllustList(null), isEmpty);
      expect(parsePixivIllustList({'illusts': 'nope'}), isEmpty);
    });
  });

  group('PixivUser.fromDetailJson', () {
    test('reads the nested user and profile objects', () {
      final user = PixivUser.fromDetailJson({
        'user': {
          'id': 11,
          'name': 'Name',
          'account': 'acct',
          'comment': 'hi',
          'profile_image_urls': {'medium': 'https://i.pximg.net/a.jpg'},
        },
        'profile': {
          'total_illusts': 5,
          'total_follower': 9,
        },
      });

      expect(user.id, 11);
      expect(user.name, 'Name');
      expect(user.illustsCount, 5);
      expect(user.followersCount, 9);
    });
  });
}
