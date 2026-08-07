import 'package:xta/utils/json.dart';

/// Open Graph–style link preview from Meta's `link_preview_attachment`.
class ThreadsLinkCard {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? providerName;

  const ThreadsLinkCard({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.providerName,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}

/// One Threads post, as much of it as a feed carries.
///
/// Meta guest/cookie payloads can also carry likes, reply/repost counts, and a
/// link preview. RSSHub feeds do not — those fields stay null so the card never
/// invents zeroes.
class ThreadsPost {
  /// The entry's own id, unique across accounts — the item id the feed gave,
  /// which for this route is the post's permalink.
  final String id;

  /// The handle that produced it, without the `@`.
  final String handle;

  /// The display name, falling back to the handle when the feed has no better.
  final String authorName;

  final String? avatarUrl;
  final String text;
  final List<String> images;
  final DateTime? publishedAt;

  /// Where the post lives on Threads, for opening it there.
  final String? url;

  final int? likeCount;
  final int? replyCount;
  final int? repostCount;
  final ThreadsLinkCard? linkCard;

  /// When set, this row is a repost: [repostedByHandle] shared [handle]'s post.
  final String? repostedByHandle;
  final String? repostedByName;

  const ThreadsPost({
    required this.id,
    required this.handle,
    required this.authorName,
    required this.text,
    this.avatarUrl,
    this.images = const [],
    this.publishedAt,
    this.url,
    this.likeCount,
    this.replyCount,
    this.repostCount,
    this.linkCard,
    this.repostedByHandle,
    this.repostedByName,
  });

  bool get hasMedia => images.isNotEmpty;

  bool get hasEngagement => likeCount != null || replyCount != null || repostCount != null;

  bool get isRepost => repostedByHandle != null && repostedByHandle!.isNotEmpty;

  /// Who to show on a "X reposted" line.
  String get reposterDisplayName {
    final name = repostedByName?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    return repostedByHandle ?? '';
  }
}

/// Unwrap Threads' `l.threads.com/?u=` outbound redirect when present.
String unwrapThreadsOutboundUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return url;
  }
  final host = uri.host.toLowerCase();
  if (host != 'l.threads.com' && host != 'l.threads.net') {
    return url;
  }
  final target = uri.queryParameters['u']?.trim();
  if (target == null || target.isEmpty) {
    return url;
  }
  return target;
}

/// Preview attachment on a Meta post JSON, or null when nothing useful is there.
ThreadsLinkCard? threadsLinkCardOf(Json post) {
  final card = post['text_post_app_info']['link_preview_attachment'];
  if (!card.exists) {
    return null;
  }

  final rawUrl = card['url'].string?.trim() ?? '';
  final title = card['title'].string?.trim();
  final description = card['description'].string?.trim();
  final image = card['image_url'].string?.trim();
  final display = card['display_url'].string?.trim();

  if (rawUrl.isEmpty &&
      (title == null || title.isEmpty) &&
      (image == null || image.isEmpty)) {
    return null;
  }

  final url = rawUrl.isEmpty
      ? (display == null || display.isEmpty ? '' : (display.startsWith('http') ? display : 'https://$display'))
      : unwrapThreadsOutboundUrl(rawUrl);
  if (url.isEmpty) {
    return null;
  }

  return ThreadsLinkCard(
    url: url,
    title: title == null || title.isEmpty ? null : title,
    description: description == null || description.isEmpty ? null : description,
    imageUrl: image == null || image.isEmpty ? null : image,
    providerName: display == null || display.isEmpty ? Uri.tryParse(url)?.host : display,
  );
}

/// A Threads profile, as the Xy server reports it.
///
/// Every field is read defensively: the upstream shape is Meta's, relayed, and
/// a field that stops being sent should leave a blank on the card rather than
/// take the screen down. Only [externalUrl] is documented as nullable, but none
/// of them are trusted to be there.
class ThreadsProfile {
  final String pk;
  final String id;
  final String username;
  final String fullName;
  final bool isVerified;
  final bool isPrivate;
  final String profilePicUrl;
  final String biography;
  final int followerCount;
  final int followingCount;
  final int mediaCount;
  final String? externalUrl;

  const ThreadsProfile({
    required this.pk,
    required this.id,
    required this.username,
    required this.fullName,
    required this.isVerified,
    required this.isPrivate,
    required this.profilePicUrl,
    required this.biography,
    required this.followerCount,
    required this.followingCount,
    required this.mediaCount,
    this.externalUrl,
  });

  factory ThreadsProfile.fromJson(Object? json) {
    final data = Json(json);
    final url = data['external_url'].string?.trim();

    return ThreadsProfile(
      pk: data['pk'].string ?? '',
      id: data['id'].string ?? '',
      username: data['username'].string ?? '',
      fullName: data['full_name'].string ?? '',
      isVerified: data['is_verified'].boolean ?? false,
      isPrivate: data['is_private'].boolean ?? false,
      profilePicUrl: data['profile_pic_url'].string ?? '',
      biography: data['biography'].string ?? '',
      followerCount: data['follower_count'].integer ?? 0,
      followingCount: data['following_count'].integer ?? 0,
      mediaCount: data['media_count'].integer ?? 0,
      externalUrl: url == null || url.isEmpty ? null : url,
    );
  }

  /// What to show as the name: the display name, or the handle when the
  /// profile has none.
  String get displayName => fullName.trim().isEmpty ? username : fullName.trim();

  ThreadsAccount toAccount() =>
      ThreadsAccount(handle: username, name: displayName, avatarUrl: profilePicUrl.isEmpty ? null : profilePicUrl);
}

/// An account the reader follows, as the plugin thinks of it.
class ThreadsAccount {
  /// The handle, without the `@`.
  final String handle;
  final String name;
  final String? avatarUrl;

  const ThreadsAccount({required this.handle, required this.name, this.avatarUrl});

  ThreadsAccount copyWith({String? name, String? avatarUrl}) =>
      ThreadsAccount(handle: handle, name: name ?? this.name, avatarUrl: avatarUrl ?? this.avatarUrl);
}

/// A handle as the route wants it: no `@`, no URL around it, lower case.
///
/// Readers paste all three — `@zuck`, `zuck`, and the address bar's
/// `https://www.threads.com/@zuck` — and every one of them means the same
/// account. Returns null when nothing usable is left.
String? normaliseThreadsHandle(String input) {
  var value = input.trim();
  if (value.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(value);
  if (uri != null && uri.host.contains('threads.')) {
    final segment = uri.pathSegments.where((e) => e.isNotEmpty).firstOrNull;
    value = segment ?? '';
  }

  value = value.replaceFirst(RegExp(r'^@+'), '').trim().toLowerCase();
  // Handles are letters, digits, underscores and dots — anything else came
  // from a paste that was not a handle at all.
  if (value.isEmpty || !RegExp(r'^[a-z0-9._]+$').hasMatch(value)) {
    return null;
  }
  return value;
}
