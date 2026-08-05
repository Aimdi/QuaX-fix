import 'package:xta/utils/json.dart';

/// Headers Pixiv CDN requires before it will serve an image.
const pixivImageHeaders = <String, String>{
  'Referer': 'https://www.pixiv.net/',
  'User-Agent': 'Mozilla/5.0',
};

/// One illustration card worth of fields from `app-api.pixiv.net`.
class PixivIllust {
  final int id;
  final String title;
  final String caption;
  final String type;
  final String thumbnailUrl;
  final String? largeUrl;
  final int pageCount;
  final int userId;
  final String userName;
  final String userAccount;
  final String? userAvatarUrl;
  final DateTime? createdAt;
  final int totalBookmarks;
  final int totalViews;
  final bool isR18;

  const PixivIllust({
    required this.id,
    required this.title,
    required this.caption,
    required this.type,
    required this.thumbnailUrl,
    required this.pageCount,
    required this.userId,
    required this.userName,
    required this.userAccount,
    this.largeUrl,
    this.userAvatarUrl,
    this.createdAt,
    this.totalBookmarks = 0,
    this.totalViews = 0,
    this.isR18 = false,
  });

  String get url => 'https://www.pixiv.net/artworks/$id';
  String get userUrl => 'https://www.pixiv.net/users/$userId';
}

/// Who the refresh token belongs to, as the token response reports it.
class PixivAuthUser {
  final int id;
  final String name;
  final String account;

  const PixivAuthUser({required this.id, required this.name, required this.account});
}

/// A Pixiv user profile from `/v1/user/detail`.
class PixivUser {
  final int id;
  final String name;
  final String account;
  final String? avatarUrl;
  final String comment;
  final int illustsCount;
  final int followersCount;

  const PixivUser({
    required this.id,
    required this.name,
    required this.account,
    required this.comment,
    this.avatarUrl,
    this.illustsCount = 0,
    this.followersCount = 0,
  });

  factory PixivUser.fromDetailJson(Object? json) {
    final root = Json(json);
    final user = root['user'];
    final profile = root['profile'];
    final avatar = user['profile_image_urls']['medium'].string;

    return PixivUser(
      id: user['id'].integer ?? 0,
      name: user['name'].string?.trim() ?? '',
      account: user['account'].string?.trim() ?? '',
      avatarUrl: avatar == null || avatar.isEmpty ? null : avatar,
      comment: user['comment'].string?.trim() ?? '',
      illustsCount: profile['total_illusts'].integer ?? profile['total_illust_series'].integer ?? 0,
      followersCount: profile['total_follower'].integer ?? 0,
    );
  }
}

bool pixivIsR18(Json illust) {
  final xRestrict = illust['x_restrict'].integer ?? 0;
  final sanity = illust['sanity_level'].integer ?? 0;
  return xRestrict > 0 || sanity >= 6;
}

String? _firstImageUrl(Json illust) {
  final urls = illust['image_urls'];
  return urls['square_medium'].string ??
      urls['medium'].string ??
      urls['large'].string ??
      illust['meta_single_page']['original_image_url'].string;
}

String? _largeImageUrl(Json illust) {
  return illust['image_urls']['large'].string ??
      illust['meta_single_page']['original_image_url'].string ??
      _firstImageUrl(illust);
}

/// One illust object → [PixivIllust], or null when unusable.
PixivIllust? pixivIllustFromJson(Object? json) {
  final data = Json(json);
  final id = data['id'].integer;
  final thumb = _firstImageUrl(data);
  if (id == null || thumb == null || thumb.isEmpty) {
    return null;
  }

  final user = data['user'];
  final avatar = user['profile_image_urls']['medium'].string;

  return PixivIllust(
    id: id,
    title: data['title'].string?.trim() ?? '',
    caption: data['caption'].string?.trim() ?? '',
    type: data['type'].string ?? 'illust',
    thumbnailUrl: thumb,
    largeUrl: _largeImageUrl(data),
    pageCount: data['page_count'].integer ?? 1,
    userId: user['id'].integer ?? 0,
    userName: user['name'].string?.trim() ?? '',
    userAccount: user['account'].string?.trim() ?? '',
    userAvatarUrl: avatar == null || avatar.isEmpty ? null : avatar,
    createdAt: DateTime.tryParse(data['create_date'].string ?? '')?.toLocal(),
    totalBookmarks: data['total_bookmarks'].integer ?? 0,
    totalViews: data['total_view'].integer ?? 0,
    isR18: pixivIsR18(data),
  );
}

/// Pure parse of a following / user-illusts list payload.
List<PixivIllust> parsePixivIllustList(Object? json, {bool includeR18 = false}) {
  final root = Json(json);
  final list = root['illusts'].list;
  return [
    for (final item in list)
      if (pixivIllustFromJson(item.raw) case final illust?)
        if (includeR18 || !illust.isR18) illust,
  ];
}
