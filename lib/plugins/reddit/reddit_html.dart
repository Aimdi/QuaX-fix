/// Reading a listing out of old.reddit.com's HTML.
///
/// Reddit shut unauthenticated `.json` access down, so the JSON a keyless
/// client used to ask for is no longer reliably served. The old site still
/// renders listings as HTML to anyone, which is the route Stealth takes and the
/// reason it keeps working without an account.
///
/// The parsing leans on the `data-*` attributes old.reddit puts on every post
/// rather than on its class names or layout: those attributes carry the id,
/// author, score, timestamp and permalink directly, and they have been stable
/// for the better part of a decade. Anything unreadable is skipped rather than
/// guessed at, so a markup change costs posts, never a crash.
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:xta/plugins/reddit/reddit_client.dart';

/// The `after` cursor and posts of one scraped listing page.
typedef ScrapedListing = ({List<RedditPost> posts, String? after});

int? _int(String? value) => value == null ? null : int.tryParse(value.trim());

bool _bool(String? value) => value?.toLowerCase() == 'true';

/// old.reddit stamps `data-timestamp` in milliseconds.
DateTime? _timestamp(String? value) {
  final millis = _int(value);
  return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
}

RedditPost? _postFrom(Element thing) {
  // Promoted posts are adverts, not content: Reddit marks them and a reader
  // asking for a subreddit did not ask for these.
  if (_bool(thing.attributes['data-promoted'])) {
    return null;
  }

  // `t3_abc123` — the fullname. The bare id is what the rest of the app uses.
  final fullname = thing.attributes['data-fullname'];
  final id = fullname != null && fullname.startsWith('t3_') ? fullname.substring(3) : fullname;

  final permalink = thing.attributes['data-permalink'];
  final title = thing.querySelector('a.title')?.text.trim();

  if (id == null || id.isEmpty || permalink == null || title == null || title.isEmpty) {
    return null;
  }

  // A self post's data-url is its own permalink, and its domain reads
  // `self.<subreddit>`; either tells us there is no article behind it.
  final url = thing.attributes['data-url'];
  final domain = thing.attributes['data-domain'] ?? '';
  final isSelf = domain.startsWith('self.') || url == null || url == permalink;

  final thumbnail = thing.querySelector('a.thumbnail img')?.attributes['src'];

  return RedditPost(
    id: id,
    title: title,
    subreddit: thing.attributes['data-subreddit'] ?? '',
    permalink: permalink,
    author: thing.attributes['data-author'],
    score: _int(thing.attributes['data-score']) ?? 0,
    commentCount: _int(thing.attributes['data-comments-count']) ?? 0,
    createdAt: _timestamp(thing.attributes['data-timestamp']),
    url: isSelf ? null : url,
    isSelf: isSelf,
    selfText: thing.querySelector('.expando .md')?.text.trim(),
    over18: _bool(thing.attributes['data-nsfw']),
    // old.reddit marks a pinned post with a class rather than an attribute.
    stickied: thing.classes.contains('stickied'),
    thumbnail: thumbnail == null ? null : _absolute(thumbnail),
    flair: _flairOf(thing),
    domain: domain.isEmpty ? null : domain,
  );
}

/// The post's flair, which old.reddit renders inside the title line.
///
/// The `title` attribute holds the full label where the visible text is
/// abbreviated, so it wins when both are there.
String? _flairOf(Element thing) {
  final label = thing.querySelector('.linkflairlabel');
  if (label == null) {
    return null;
  }

  final full = label.attributes['title']?.trim();
  final text = label.text.trim();
  final flair = (full != null && full.isNotEmpty) ? full : text;

  return flair.isEmpty ? null : flair;
}

/// Reddit serves protocol-relative thumbnail URLs; the image loader needs a
/// scheme. `self`, `default` and `nsfw` are placeholders, not pictures.
String? _absolute(String src) {
  if (src.startsWith('//')) {
    return 'https:$src';
  }
  return src.startsWith('http') ? src : null;
}

/// Hosts Reddit serves community artwork from. Anything else on a subreddit
/// page — the site logo, a tracking pixel, an advert — is not the icon.
const _iconHosts = {
  'styles.redditmedia.com',
  'a.thumbs.redditmedia.com',
  'b.thumbs.redditmedia.com',
  'f.thumbs.redditmedia.com',
  'preview.redd.it',
  'i.redd.it',
};

/// A subreddit's own picture, from its old.reddit page.
///
/// The old site predates community icons and has no element for one, so this
/// takes what it does have: the header image a subreddit sets, which for most
/// is the same artwork, and failing that the page's `og:image`. Subreddits that
/// set neither have no picture to find — the caller falls back to a generated
/// tile rather than showing nothing.
String? parseSubredditIcon(String body) {
  final document = html.parse(body);

  // Old themes make the header an `<img id="header-img">`; others wrap it in a
  // link, so the id lands on the anchor and the source is a child.
  final header = document.querySelector('#header-img')?.attributes['src'] ??
      document.querySelector('#header-img img')?.attributes['src'] ??
      document.querySelector('.subreddit-icon img')?.attributes['src'];

  final og = document.querySelector('meta[property="og:image"]')?.attributes['content'];

  for (final candidate in [header, og]) {
    final url = candidate == null ? null : _absolute(candidate);
    final host = url == null ? null : Uri.tryParse(url)?.host.toLowerCase();
    if (url != null && host != null && _iconHosts.contains(host)) {
      return url;
    }
  }

  return null;
}

/// Whether the page Reddit returned is the over-18 gate rather than a listing.
///
/// Answering it needs a cookie, not a login, which is why it is worth
/// recognising instead of reporting as an empty subreddit.
bool isOver18Gate(String body) {
  final document = html.parse(body);

  return document.querySelector('form[action*="over18"]') != null ||
      document.querySelector('.content [name="over18"]') != null;
}

/// Posts and the next-page cursor from a listing page.
ScrapedListing parseListing(String body) {
  final document = html.parse(body);

  final posts = <RedditPost>[];
  for (final thing in document.querySelectorAll('div.thing')) {
    final post = _postFrom(thing);
    if (post != null) {
      posts.add(post);
    }
  }

  return (posts: posts, after: _afterFrom(document));
}

/// The `after` value from the "next" link, so scraped listings paginate the
/// same way the JSON ones did.
String? _afterFrom(Document document) {
  final next = document.querySelector('.next-button a') ?? document.querySelector('a[rel~="next"]');
  final href = next?.attributes['href'];
  if (href == null) {
    return null;
  }

  final after = Uri.tryParse(href)?.queryParameters['after'];
  return after == null || after.isEmpty ? null : after;
}
