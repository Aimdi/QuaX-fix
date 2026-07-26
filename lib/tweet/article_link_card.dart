import 'package:flutter/material.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/tweet_chrome.dart';
import 'package:quax/utils/urls.dart';

/// A link to a long-form X article, shown as a card rather than a raw URL.
///
/// X sends no title, author or thumbnail for one of these — only the link — so
/// there is nothing to build a real preview from. What the card can do is say
/// what the link is and give it something worth tapping, instead of the
/// truncated `x.com/i/artic…` that used to sit above the footer.
class ArticleLinkCard extends StatelessWidget {
  final String url;
  final VoidCallback onTap;

  const ArticleLinkCard({super.key, required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kTweetMediaRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(kTweetMediaRadius),
          ),
          child: Row(
            children: [
              Icon(Icons.article_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L10n.of(context).article_on_x, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      Uri.tryParse(url)?.host ?? url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// The first article link among a post's URL entities, if it has one.
String? firstArticleLink(Iterable<String?> expandedUrls) {
  for (final url in expandedUrls) {
    if (articleIdIn(url) != null) {
      return url;
    }
  }
  return null;
}
