import 'package:xta/utils/json.dart';

/// One Bluesky post, as much of it as a public feed view carries.
class BlueskyPost {
  final String uri;
  final String cid;
  final String handle;
  final String did;
  final String authorName;
  final String? avatarUrl;
  final String text;
  final List<String> images;
  final DateTime? publishedAt;

  /// Where the post lives on bsky.app, for opening it there.
  final String url;

  const BlueskyPost({
    required this.uri,
    required this.cid,
    required this.handle,
    required this.did,
    required this.authorName,
    required this.text,
    required this.url,
    this.avatarUrl,
    this.images = const [],
    this.publishedAt,
  });

  bool get hasMedia => images.isNotEmpty;
}

/// A Bluesky profile, as the public AppView reports it.
class BlueskyProfile {
  final String did;
  final String handle;
  final String displayName;
  final String? avatarUrl;
  final String description;
  final int followersCount;
  final int followsCount;
  final int postsCount;

  const BlueskyProfile({
    required this.did,
    required this.handle,
    required this.displayName,
    required this.description,
    this.avatarUrl,
    this.followersCount = 0,
    this.followsCount = 0,
    this.postsCount = 0,
  });

  factory BlueskyProfile.fromJson(Object? json) {
    final data = Json(json);
    final handle = data['handle'].string?.trim() ?? '';
    final name = data['displayName'].string?.trim();
    final avatar = data['avatar'].string?.trim();

    return BlueskyProfile(
      did: data['did'].string ?? '',
      handle: handle,
      displayName: (name == null || name.isEmpty) ? handle : name,
      avatarUrl: avatar == null || avatar.isEmpty ? null : avatar,
      description: data['description'].string?.trim() ?? '',
      followersCount: data['followersCount'].integer ?? 0,
      followsCount: data['followsCount'].integer ?? 0,
      postsCount: data['postsCount'].integer ?? 0,
    );
  }

  BlueskyAccount toAccount() => BlueskyAccount(
        handle: handle,
        name: displayName,
        avatarUrl: avatarUrl,
        did: did.isEmpty ? null : did,
      );
}

/// An account the reader follows locally — not a Bluesky follow graph edge.
class BlueskyAccount {
  /// Handle without `@`, or a `did:plc:…` when that is what was stored.
  final String handle;
  final String name;
  final String? avatarUrl;
  final String? did;

  const BlueskyAccount({
    required this.handle,
    required this.name,
    this.avatarUrl,
    this.did,
  });

  /// What the AppView wants as `actor`: prefer the DID when we have one.
  String get actor => (did != null && did!.isNotEmpty) ? did! : handle;

  BlueskyAccount copyWith({String? name, String? avatarUrl, String? did}) => BlueskyAccount(
        handle: handle,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        did: did ?? this.did,
      );
}

/// Official public AppView — read-only xrpc without a Bluesky login.
const kBlueskyDefaultAppView = 'https://public.api.bsky.app';

/// Strip trailing slash; require http(s) and a hostname. Null when unusable.
String? normaliseBlueskyAppView(String input) {
  var value = input.trim();
  if (value.isEmpty) {
    return null;
  }
  if (!value.contains('://')) {
    value = 'https://$value';
  }
  final uri = Uri.tryParse(value);
  final host = uri?.host.trim() ?? '';
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      host.isEmpty ||
      host.contains(' ') ||
      host.contains('%20')) {
    return null;
  }
  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  return Uri(scheme: uri.scheme, host: host, port: uri.hasPort ? uri.port : null, path: path).toString();
}

/// Resolved AppView URL from prefs, always falling back to the working default.
String blueskyAppViewFromPrefs(String? raw) =>
    normaliseBlueskyAppView(raw ?? '') ?? kBlueskyDefaultAppView;

/// A handle, profile URL, or DID as the plugin wants it.
///
/// Accepts `@alice.bsky.social`, bare handles with dots, `bsky.app/profile/…`
/// URLs, and `did:plc:…`. Returns null when nothing usable is left.
String? normaliseBlueskyHandle(String input) {
  var value = input.trim();
  if (value.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(value);
  if (uri != null && (uri.host == 'bsky.app' || uri.host == 'www.bsky.app')) {
    final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    if (segments.length >= 2 && segments.first == 'profile') {
      value = segments[1];
    }
  }

  value = value.replaceFirst(RegExp(r'^@+'), '').trim();
  if (value.isEmpty) {
    return null;
  }

  final lower = value.toLowerCase();
  if (RegExp(r'^did:plc:[a-z2-7]+$').hasMatch(lower)) {
    return lower;
  }

  // Handles are DNS-like: letters, digits, hyphens, dots; at least one dot.
  if (!RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$').hasMatch(lower)) {
    return null;
  }
  return lower;
}

/// Web URL for a post: handle + rkey of an `at://` URI.
String? blueskyWebUrl({required String handle, required String atUri}) {
  if (handle.isEmpty) {
    return null;
  }
  final rkey = blueskyRkeyOf(atUri);
  if (rkey == null) {
    return null;
  }
  return 'https://bsky.app/profile/$handle/post/$rkey';
}

/// The record key of an `at://did/…/collection/rkey` URI.
String? blueskyRkeyOf(String atUri) {
  if (!atUri.startsWith('at://')) {
    return null;
  }
  final parts = atUri.substring('at://'.length).split('/');
  if (parts.length < 3) {
    return null;
  }
  final rkey = parts.last.trim();
  return rkey.isEmpty ? null : rkey;
}

/// Images from a feed post's view embed (thumb preferred, else fullsize).
List<String> blueskyImagesOf(Json post) {
  final urls = <String>[];

  void addFrom(Json images) {
    for (final image in images.list) {
      final url = image['thumb'].string ?? image['fullsize'].string;
      if (url != null && url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
  }

  final embed = post['embed'];
  addFrom(embed['images']);
  addFrom(embed['media']['images']);

  return urls;
}

/// Turns one feed item's `post` object into a [BlueskyPost], or null when empty.
BlueskyPost? blueskyPostFromFeedItem(Object? item) {
  final root = Json(item);
  final post = root['post'].exists ? root['post'] : root;
  final uri = post['uri'].string;
  if (uri == null || uri.isEmpty) {
    return null;
  }

  final author = post['author'];
  final handle = author['handle'].string?.trim() ?? '';
  final did = author['did'].string ?? '';
  final name = author['displayName'].string?.trim();
  final text = post['record']['text'].string?.trim() ?? '';
  final images = blueskyImagesOf(post);
  if (text.isEmpty && images.isEmpty) {
    return null;
  }

  final url = blueskyWebUrl(handle: handle, atUri: uri);
  if (url == null) {
    return null;
  }

  final avatar = author['avatar'].string?.trim();

  return BlueskyPost(
    uri: uri,
    cid: post['cid'].string ?? '',
    handle: handle,
    did: did,
    authorName: (name == null || name.isEmpty) ? handle : name,
    avatarUrl: avatar == null || avatar.isEmpty ? null : avatar,
    text: text,
    images: images,
    publishedAt: DateTime.tryParse(post['record']['createdAt'].string ?? '')?.toLocal(),
    url: url,
  );
}

/// Pure parse of `getAuthorFeed` JSON into posts (cursor ignored).
List<BlueskyPost> parseBlueskyFeed(Object? json) {
  final feed = Json(json)['feed'];
  return [
    for (final item in feed.list) ?blueskyPostFromFeedItem(item),
  ];
}
