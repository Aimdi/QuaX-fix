import 'dart:convert';

/// Locally followed Substack publication.
class SubstackPublication {
  final String subdomain;
  final String baseUrl;
  final String name;
  final String? description;
  final String? logoUrl;

  const SubstackPublication({
    required this.subdomain,
    required this.baseUrl,
    required this.name,
    this.description,
    this.logoUrl,
  });

  String get id => subdomain.toLowerCase();

  Map<String, dynamic> toJson() => {
        'subdomain': subdomain,
        'baseUrl': baseUrl,
        'name': name,
        'description': description,
        'logoUrl': logoUrl,
      };

  factory SubstackPublication.fromJson(Map<String, dynamic> json) {
    return SubstackPublication(
      subdomain: json['subdomain'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      name: json['name'] as String? ?? json['subdomain'] as String? ?? '',
      description: json['description'] as String?,
      logoUrl: json['logoUrl'] as String?,
    );
  }

  static List<SubstackPublication> listFromPrefs(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => SubstackPublication.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.subdomain.isNotEmpty && e.baseUrl.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String listToPrefs(List<SubstackPublication> pubs) =>
      jsonEncode(pubs.map((e) => e.toJson()).toList());
}

class SubstackPost {
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final String slug;
  final String? postDate;
  final String? canonicalUrl;
  final String? coverImage;
  final String? bodyHtml;
  final String? audience;
  final String? authorName;
  final String publicationBaseUrl;
  final String publicationName;

  /// What kind of post this is: `newsletter`, `podcast`, `video`, …
  final String? type;

  /// Set when the post is built around a video Substack hosts itself.
  final bool hasVideoUpload;

  const SubstackPost({
    required this.id,
    required this.title,
    required this.slug,
    required this.publicationBaseUrl,
    required this.publicationName,
    this.type,
    this.hasVideoUpload = false,
    this.subtitle,
    this.description,
    this.postDate,
    this.canonicalUrl,
    this.coverImage,
    this.bodyHtml,
    this.audience,
    this.authorName,
  });

  /// Substack uses `only_paid` (and occasionally founding tiers) for gated posts.
  bool get isPaywalled {
    final value = audience?.toLowerCase();
    return value == 'only_paid' ||
        value == 'only_paying' ||
        value == 'founding' ||
        value == 'only_founding';
  }

  String? get excerpt {
    final subtitleText = subtitle?.trim();
    if (subtitleText != null && subtitleText.isNotEmpty && subtitleText != '...') {
      return subtitleText;
    }
    final descriptionText = description?.trim();
    if (descriptionText != null && descriptionText.isNotEmpty && descriptionText != '...') {
      return descriptionText;
    }
    return null;
  }

  DateTime? get publishedAt {
    final raw = postDate;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  factory SubstackPost.fromJson(
    Map<String, dynamic> json, {
    required String publicationBaseUrl,
    required String publicationName,
    bool includeBody = true,
  }) {
    final bylines = json['publishedBylines'];
    String? author;
    if (bylines is List && bylines.isNotEmpty) {
      final first = bylines.first;
      if (first is Map) author = first['name'] as String?;
    }

    return SubstackPost(
      id: '${json['id'] ?? json['slug'] ?? ''}',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      slug: json['slug'] as String? ?? '',
      postDate: json['post_date'] as String?,
      canonicalUrl: json['canonical_url'] as String?,
      coverImage: json['cover_image'] as String?,
      bodyHtml: includeBody ? json['body_html'] as String? : null,
      audience: json['audience'] as String?,
      authorName: author,
      type: json['type'] as String?,
      // Substack has moved this field around, so presence is what is checked
      // rather than any particular shape of it.
      hasVideoUpload: json['videoUpload'] != null || json['video_upload'] != null,
      publicationBaseUrl: publicationBaseUrl,
      publicationName: publicationName,
    );
  }

  /// Whether the post leads with a video, which the tile marks and the reader
  /// plays. A video post used to be indistinguishable from any other, so the
  /// only clue that there was one was opening it.
  bool get isVideo => hasVideoUpload || type?.toLowerCase() == 'video';

  SubstackPublication get publication => SubstackPublication(
        subdomain: subdomainOf(Uri.parse(publicationBaseUrl)),
        baseUrl: publicationBaseUrl,
        name: publicationName,
      );
}

class SubstackFeedSnapshot {
  final List<SubstackPost> posts;
  final bool canLoadMore;
  final int failedCount;

  const SubstackFeedSnapshot({
    this.posts = const [],
    this.canLoadMore = false,
    this.failedCount = 0,
  });

  SubstackFeedSnapshot copyWith({
    List<SubstackPost>? posts,
    bool? canLoadMore,
    int? failedCount,
  }) {
    return SubstackFeedSnapshot(
      posts: posts ?? this.posts,
      canLoadMore: canLoadMore ?? this.canLoadMore,
      failedCount: failedCount ?? this.failedCount,
    );
  }
}

/// Resolve a user-entered Substack handle or URL into a base publication URL.
Uri? resolveSubstackBase(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  var raw = trimmed;
  if (!raw.contains('://')) {
    if (raw.contains('.')) {
      raw = 'https://$raw';
    } else {
      raw = 'https://$raw.substack.com';
    }
  }

  final uri = Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty) return null;
  return Uri(scheme: 'https', host: uri.host);
}

/// Parse a Substack post URL into publication base + slug.
({Uri base, String slug})? resolveSubstackPostRef(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  var raw = trimmed;
  if (!raw.contains('://')) raw = 'https://$raw';
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty) return null;

  final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();
  if (segments.length < 2 || segments.first != 'p') return null;
  final slug = segments[1];
  if (slug.isEmpty) return null;
  return (base: Uri(scheme: 'https', host: uri.host), slug: slug);
}

String subdomainOf(Uri base) {
  final host = base.host.toLowerCase();
  if (host.endsWith('.substack.com')) {
    return host.substring(0, host.length - '.substack.com'.length);
  }
  return host.split('.').first;
}

List<String> readIdsFromPrefs(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<String>().where((e) => e.isNotEmpty).toList();
  } catch (_) {
    return const [];
  }
}

String readIdsToPrefs(List<String> ids) => jsonEncode(ids);
