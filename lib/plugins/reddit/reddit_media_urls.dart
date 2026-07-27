/// Deciding what a Reddit URL points at.
///
/// A post and a comment ask the same question — is this a picture I can show,
/// or a page I can only link to — so they ask it in one place. Reddit gives no
/// content type in the markup, and following the link to find out would mean a
/// request per post, so the answer comes from the host and the extension.
library;

/// Hosts that serve the picture itself, whatever the path looks like.
const redditImageHosts = {'i.redd.it', 'preview.redd.it', 'i.imgur.com', 'i.redditmedia.com'};

/// Hosts whose links are a video. Reddit's own is a DASH manifest rather than a
/// file, so none of these can be shown inline — but knowing it is a video is
/// what lets a card say so instead of offering a dead thumbnail.
const redditVideoHosts = {
  'v.redd.it',
  'youtube.com',
  'youtu.be',
  'm.youtube.com',
  'streamable.com',
  'gfycat.com',
  'redgifs.com',
};

const _imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

/// [url] if it is a picture that can be shown inline, otherwise null.
///
/// Imgur's `.gifv` is rewritten to `.gif`: the name looks like an image but the
/// page behind it is a video player, and the `.gif` beside it is the animation
/// itself.
String? redditImageUrl(String? url) {
  final uri = url == null ? null : Uri.tryParse(url);
  if (url == null || uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
    return null;
  }

  final path = uri.path.toLowerCase();
  if (path.endsWith('.gifv')) {
    // Only a plain `…/x.gifv`; with a query on the end the rewrite would have
    // to guess where the extension stopped, and a guess here loads nothing.
    return url.toLowerCase().endsWith('.gifv') ? url.substring(0, url.length - 1) : null;
  }

  final host = _bareHost(uri.host);
  return redditImageHosts.contains(host) || _imageExtensions.any(path.endsWith) ? url : null;
}

/// Whether a host serves video rather than anything showable.
bool isRedditVideoHost(String? host) => host != null && redditVideoHosts.contains(_bareHost(host));

String _bareHost(String host) {
  final lower = host.toLowerCase();
  return lower.startsWith('www.') ? lower.substring(4) : lower;
}
