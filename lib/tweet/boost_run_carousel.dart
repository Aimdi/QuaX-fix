import 'package:flutter/material.dart';
import 'package:xta/client/client.dart';
import 'package:xta/constants.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/status.dart';
import 'package:xta/tweet/tweet_chrome.dart';
import 'package:xta/user.dart';

/// A horizontal row of compact boost cards for consecutive retweets.
class BoostRunCarousel extends StatelessWidget {
  final List<TweetChain> chains;
  final String? username;

  const BoostRunCarousel({super.key, required this.chains, this.username});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(L10n.of(context).boosts_row_label, style: labelStyle),
        ),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: chains.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _BoostCard(chain: chains[index], username: username),
          ),
        ),
      ],
    );
  }
}

class _BoostCard extends StatelessWidget {
  final TweetChain chain;
  final String? username;

  const _BoostCard({required this.chain, this.username});

  @override
  Widget build(BuildContext context) {
    final boost = chain.tweets.first;
    final boosted = boost.retweetedStatusWithCard;
    final booster = boost.user;
    final theme = Theme.of(context);
    final preview = _textPeek(boosted?.fullText ?? boosted?.text);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(tweetMediaRadiusOf(context)),
      child: InkWell(
        borderRadius: BorderRadius.circular(tweetMediaRadiusOf(context)),
        onTap: boost.idStr == null || booster?.screenName == null
            ? null
            : () => Navigator.pushNamed(
                context,
                routeStatus,
                arguments: StatusScreenArguments(id: boost.idStr!, username: booster!.screenName!),
              ),
        child: SizedBox(
          width: 200,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                if (booster != null) UserAvatar(uri: booster.profileImageUrlHttps, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        booster?.name ?? booster?.screenName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                      if (preview.isNotEmpty)
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _textPeek(String? text) {
    final trimmed = text?.replaceAll('\n', ' ').trim() ?? '';
    if (trimmed.length <= 80) {
      return trimmed;
    }
    return '${trimmed.substring(0, 77)}…';
  }
}
