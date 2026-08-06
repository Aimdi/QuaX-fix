import 'package:html/parser.dart' as html;
import 'package:xta/utils/json.dart';

/// One public Mastodon status, as much as a card needs.
class MastodonPost {
  final String id;
  final String acct;
  final String authorName;
  final String? avatarUrl;
  final String text;
  final List<String> images;
  final DateTime? publishedAt;
  final String url;

  /// True when this card shows a boosted status (reblog unwrapped).
  final bool boosted;

  const MastodonPost({
    required this.id,
    required this.acct,
    required this.authorName,
    required this.text,
    required this.url,
    this.avatarUrl,
    this.images = const [],
    this.publishedAt,
    this.boosted = false,
  });

  bool get hasMedia => images.isNotEmpty;
}

/// A Mastodon / Fediverse profile as the home instance reports it.
class MastodonProfile {
  /// Numeric id on the **home** instance — not portable across instances.
  final String id;
  final String acct;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String note;
  final String url;
  final int followersCount;
  final int followingCount;
  final int statusesCount;
  final bool locked;

  const MastodonProfile({
    required this.id,
    required this.acct,
    required this.username,
    required this.displayName,
    required this.note,
    required this.url,
    this.avatarUrl,
    this.followersCount = 0,
    this.followingCount = 0,
    this.statusesCount = 0,
    this.locked = false,
  });

  factory MastodonProfile.fromJson(Object? json, {String? homeDomain}) {
    final data = Json(json);
    final username = data['username'].string?.trim() ?? '';
    final rawAcct = data['acct'].string?.trim() ?? username;
    final acct = canonicalMastodonAcct(rawAcct, homeDomain: homeDomain);
    final name = data['display_name'].string?.trim();
    final avatar = data['avatar'].string?.trim() ?? data['avatar_static'].string?.trim();
    final noteHtml = data['note'].string;

    return MastodonProfile(
      id: data['id'].string ?? '${data['id'].integer ?? ''}',
      acct: acct,
      username: username.isEmpty ? acct.split('@').first : username,
      displayName: (name == null || name.isEmpty) ? acct : name,
      avatarUrl: avatar == null || avatar.isEmpty ? null : avatar,
      note: mastodonHtmlToText(noteHtml),
      url: data['url'].string?.trim() ?? '',
      followersCount: data['followers_count'].integer ?? 0,
      followingCount: data['following_count'].integer ?? 0,
      statusesCount: data['statuses_count'].integer ?? 0,
      locked: data['locked'].boolean ?? false,
    );
  }

  MastodonAccount toAccount() => MastodonAccount(acct: acct, name: displayName, avatarUrl: avatarUrl);
}

/// An account the reader follows locally — not a Mastodon follow-graph edge.
class MastodonAccount {
  /// Canonical `user@domain` (always includes the domain).
  final String acct;
  final String name;
  final String? avatarUrl;

  const MastodonAccount({required this.acct, required this.name, this.avatarUrl});

  MastodonAccount copyWith({String? name, String? avatarUrl}) =>
      MastodonAccount(acct: acct, name: name ?? this.name, avatarUrl: avatarUrl ?? this.avatarUrl);
}

/// Instances the plugin can read through with nothing configured.
///
/// Chosen for reach rather than character: large, long-lived, open general
/// instances whose public API answers without a login, ordered by the size of
/// the slice of the Fediverse each one federates with. The first two are run
/// by Mastodon gGmbH itself; the rest are the biggest independent generalists
/// that have stayed up and open for years. Broad instances are the point —
/// a big instance's federated view contains what the small ones see.
///
/// This list is the *fallback*, not the strategy. Coverage of the whole
/// Fediverse comes from [mastodonInstanceCandidates] asking an account's own
/// instance first: the origin has every post its accounts ever made, which no
/// amount of federation guarantees anywhere else. The client walks the list,
/// so an instance being down or newly closed costs one failed try, never the
/// feature.
const kMastodonDefaultInstances = [
  'https://mastodon.social',
  'https://mastodon.online',
  'https://mstdn.social',
  'https://mas.to',
  'https://mastodon.world',
];

/// Every instance worth asking about [acct], best answer first.
///
/// Order is the whole design: the account's own instance (complete by
/// definition — though a Misskey-family origin will not answer the Mastodon
/// API, which is why the walk goes on), then the reader's instances in the
/// order they gave them, then the built-in defaults. Duplicates collapse to
/// their first appearance, so a reader whose home is an origin or a default
/// never asks it twice.
List<String> mastodonInstanceCandidates(String acct, {List<String> configured = const []}) {
  final normalisedAcct = normaliseMastodonAcct(acct) ?? acct.trim();
  final at = normalisedAcct.indexOf('@');
  final origin = at > 0 ? normalisedAcct.substring(at + 1).trim().toLowerCase() : '';

  final ordered = [if (origin.isNotEmpty) 'https://$origin', ...configured, ...kMastodonDefaultInstances];

  final seen = <String>{};
  return [
    for (final candidate in ordered)
      if (normaliseMastodonInstance(candidate) case final instance? when seen.add(instance)) instance,
  ];
}

/// Strip scheme/trailing slash; require http(s). Null when unusable.
String? normaliseMastodonInstance(String input) {
  var value = input.trim();
  if (value.isEmpty) {
    return null;
  }
  if (!value.contains('://')) {
    value = 'https://$value';
  }
  final uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  // Reject spaces / percent-encoded junk; hostnames are DNS-like for our purposes.
  if (uri.host.isEmpty || uri.host.contains('%') || RegExp(r'\s').hasMatch(uri.host)) {
    return null;
  }
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}

/// Host of a normalised instance URL, or null.
String? mastodonInstanceDomain(String instance) {
  final uri = Uri.tryParse(instance);
  final host = uri?.host.trim().toLowerCase();
  return host == null || host.isEmpty ? null : host;
}

/// `user`, `@user`, `user@domain`, or `https://domain/@user` → lookup acct.
///
/// Bare local usernames are kept without a domain (the home instance resolves
/// them). Profile URLs and `user@domain` become a WebFinger-style address.
String? normaliseMastodonAcct(String input) {
  var value = input.trim();
  if (value.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    if (segments.isEmpty) {
      return null;
    }
    var user = segments.first;
    if (user.startsWith('@')) {
      user = user.substring(1);
    }
    // /users/Name or /@Name
    if (user.toLowerCase() == 'users' && segments.length >= 2) {
      user = segments[1];
    }
    user = user.replaceFirst(RegExp(r'^@+'), '').trim();
    if (user.isEmpty) {
      return null;
    }
    return '${user.toLowerCase()}@${uri.host.toLowerCase()}';
  }

  value = value.replaceFirst(RegExp(r'^@+'), '').trim();
  if (value.isEmpty) {
    return null;
  }

  final lower = value.toLowerCase();
  if (lower.contains('@')) {
    final parts = lower.split('@');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty || !parts[1].contains('.')) {
      return null;
    }
    if (!RegExp(r'^[a-z0-9_]+([a-z0-9_.-]*[a-z0-9_])?$').hasMatch(parts[0])) {
      return null;
    }
    return lower;
  }

  if (!RegExp(r'^[a-z0-9_]+([a-z0-9_.-]*[a-z0-9_])?$').hasMatch(lower)) {
    return null;
  }
  return lower;
}

/// Prefer `user@domain` for storage so a home-instance change cannot collide.
String canonicalMastodonAcct(String acct, {String? homeDomain}) {
  final trimmed = acct.trim().toLowerCase();
  if (trimmed.contains('@')) {
    return trimmed;
  }
  final domain = homeDomain?.trim().toLowerCase();
  if (domain == null || domain.isEmpty) {
    return trimmed;
  }
  return '$trimmed@$domain';
}

/// Mastodon status HTML → plain text for a card.
String mastodonHtmlToText(String? contentHtml) {
  if (contentHtml == null || contentHtml.trim().isEmpty) {
    return '';
  }
  final document = html.parse(contentHtml.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n'));
  for (final block in document.querySelectorAll('p, div')) {
    block.append(html.parseFragment('\n').nodes.first);
  }
  return document.body?.text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim() ?? '';
}

List<String> mastodonImagesOf(Json status) {
  final urls = <String>[];
  for (final media in status['media_attachments'].list) {
    final type = media['type'].string ?? '';
    if (type != 'image' && type != 'gifv') {
      continue;
    }
    final url = media['preview_url'].string ?? media['url'].string;
    if (url != null && url.isNotEmpty && !urls.contains(url)) {
      urls.add(url);
    }
  }
  return urls;
}

/// One status JSON object → [MastodonPost], or null when empty.
MastodonPost? mastodonPostFromStatus(Object? json, {String? homeDomain}) {
  final root = Json(json);
  // Unwrap boosts so the card shows the original public post.
  final boosted = root['reblog'].exists;
  final status = boosted ? root['reblog'] : root;

  final id = status['id'].string ?? '${status['id'].integer ?? ''}';
  if (id.isEmpty) {
    return null;
  }

  final author = MastodonProfile.fromJson(status['account'].raw, homeDomain: homeDomain);
  final spoiler = status['spoiler_text'].string?.trim() ?? '';
  final body = mastodonHtmlToText(status['content'].string);
  final text = [if (spoiler.isNotEmpty) spoiler, if (body.isNotEmpty) body].join('\n\n');
  final images = mastodonImagesOf(status);
  if (text.isEmpty && images.isEmpty) {
    return null;
  }

  final url = status['url'].string?.trim() ?? status['uri'].string?.trim() ?? '';
  if (url.isEmpty) {
    return null;
  }

  return MastodonPost(
    id: id,
    acct: author.acct,
    authorName: author.displayName,
    avatarUrl: author.avatarUrl,
    text: text,
    images: images,
    publishedAt: DateTime.tryParse(status['created_at'].string ?? '')?.toLocal(),
    url: url,
    boosted: boosted,
  );
}

/// Pure parse of `GET /accounts/:id/statuses` JSON array.
List<MastodonPost> parseMastodonStatuses(Object? json, {String? homeDomain}) {
  final root = Json(json);
  final items = root.raw is List ? root.list : const <Json>[];
  return [for (final item in items) ?mastodonPostFromStatus(item.raw, homeDomain: homeDomain)];
}
