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
  final String slug;
  final String? postDate;
  final String? canonicalUrl;
  final String? coverImage;
  final String? bodyHtml;
  final String? audience;
  final String? authorName;
  final String publicationBaseUrl;
  final String publicationName;

  const SubstackPost({
    required this.id,
    required this.title,
    required this.slug,
    required this.publicationBaseUrl,
    required this.publicationName,
    this.subtitle,
    this.postDate,
    this.canonicalUrl,
    this.coverImage,
    this.bodyHtml,
    this.audience,
    this.authorName,
  });

  bool get isPaywalled => audience == 'only_paying' || audience == 'founding';

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
      slug: json['slug'] as String? ?? '',
      postDate: json['post_date'] as String?,
      canonicalUrl: json['canonical_url'] as String?,
      coverImage: json['cover_image'] as String?,
      bodyHtml: includeBody ? json['body_html'] as String? : null,
      audience: json['audience'] as String?,
      authorName: author,
      publicationBaseUrl: publicationBaseUrl,
      publicationName: publicationName,
    );
  }

  SubstackPublication get publication => SubstackPublication(
        subdomain: subdomainOf(Uri.parse(publicationBaseUrl)),
        baseUrl: publicationBaseUrl,
        name: publicationName,
      );
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

String subdomainOf(Uri base) {
  final host = base.host.toLowerCase();
  if (host.endsWith('.substack.com')) {
    return host.substring(0, host.length - '.substack.com'.length);
  }
  return host.split('.').first;
}
