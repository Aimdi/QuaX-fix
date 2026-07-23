import 'dart:typed_data';

import 'package:dart_twitter_api/twitter_api.dart' show Media, Url;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/saved/folder_picker.dart';
import 'package:quax/saved/liked_tweet_model.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/status.dart';
import 'package:quax/tweet/_like_button.dart';
import 'package:quax/tweet/quotes_screen.dart';
import 'package:quax/utils/urls.dart';
import 'package:share_plus/share_plus.dart';

/// Footer buttons should feel flat: no ripple and no pressed/hover background.
const footerButtonStyle = ButtonStyle(
  overlayColor: WidgetStatePropertyAll(Colors.transparent),
  splashFactory: NoSplash.splashFactory,
);

enum TranslationStatus { original, translating, translationFailed, translated }

// Memoized footer action tint (HSL round-trip is too expensive per button per frame).
Color? _buttonsColorCache;
Color? _buttonsColorBase;

Color? tweetFooterButtonsColor(Color? base) {
  if (base == null) return null;
  if (base != _buttonsColorBase) {
    final hsl = HSLColor.fromColor(base);
    const lightnessFactorDark = 0.5;
    const lightnessFactorLight = 4.0;
    final adjustedLightness =
        (hsl.lightness * (hsl.lightness > 0.5 ? lightnessFactorDark : lightnessFactorLight)).clamp(0.0, 1.0);
    final adjustedSaturation = (hsl.saturation * 0.2).clamp(0.0, 1.0);
    _buttonsColorBase = base;
    _buttonsColorCache = hsl.withLightness(adjustedLightness).withSaturation(adjustedSaturation).toColor();
  }
  return _buttonsColorCache;
}

Color? tweetFooterButtonsColorOf(BuildContext context) =>
    tweetFooterButtonsColor(Theme.of(context).textTheme.bodyMedium?.color);

/// Replace t.co redirectors with cleaned destinations so shares skip X click tracking.
String shareableTweetText(TweetWithCard tweet, String text) {
  var result = text;
  for (Url url in tweet.entities?.urls ?? []) {
    final short = url.url;
    final expanded = url.expandedUrl;
    if (short != null && expanded != null) {
      result = result.replaceAll(short, cleanUrl(expanded));
    }
  }
  for (Media media in tweet.extendedEntities?.media ?? tweet.entities?.media ?? []) {
    final short = media.url;
    final expanded = media.expandedUrl;
    if (short != null && expanded != null) {
      result = result.replaceAll(short, cleanUrl(expanded));
    }
  }
  return result;
}

void maybeShowFolderHint(BuildContext context) {
  var prefs = PrefService.of(context, listen: false);
  if (prefs.get<bool>(optionSavedFolderHintShown) ?? false) {
    return;
  }
  prefs.set(optionSavedFolderHintShown, true);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.of(context).long_press_folder_hint)));
}

void maybeShowLikeToast(BuildContext context) {
  var prefs = PrefService.of(context, listen: false);
  if (prefs.get<bool>(optionLikedFirstToastShown) ?? false) {
    return;
  }
  prefs.set(optionLikedFirstToastShown, true);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(L10n.of(context).likes_stay_on_device_notice),
    duration: const Duration(seconds: 6),
  ));
}

IconButton tweetFooterIconButton(BuildContext context, IconData icon,
    [Color? color, double? fill, VoidCallback? onPressed]) {
  return IconButton(
    icon: Icon(icon, fill: fill),
    color: color ?? Theme.of(context).colorScheme.primary,
    iconSize: 20,
    onPressed: onPressed,
    style: footerButtonStyle,
  );
}

TextButton tweetFooterTextButton(IconData icon, String label, [Color? color, VoidCallback? onPressed]) {
  return TextButton.icon(
    icon: Icon(icon, size: 20, color: color),
    onPressed: onPressed,
    label: Text(label, style: TextStyle(color: color, fontSize: 14)),
    style: footerButtonStyle,
  );
}

/// Engagement / save / share / translate strip under a tweet tile.
class TweetFooterBar extends StatelessWidget {
  final TweetWithCard tweet;
  final String tweetText;
  final String shareBaseUrl;
  final Locale locale;
  final NumberFormat numberFormat;
  final bool isArticle;
  final TranslationStatus translationStatus;
  final VoidCallback onOpenTweet;
  final Future<void> Function() onTranslate;
  final VoidCallback onShowOriginal;
  final VoidCallback? onTranslateLongPress;
  final Future<Uint8List?> Function() onCaptureImage;
  final VoidCallback onChanged;

  const TweetFooterBar({
    super.key,
    required this.tweet,
    required this.tweetText,
    required this.shareBaseUrl,
    required this.locale,
    required this.numberFormat,
    required this.translationStatus,
    required this.onOpenTweet,
    required this.onTranslate,
    required this.onShowOriginal,
    required this.onCaptureImage,
    required this.onChanged,
    this.onTranslateLongPress,
    this.isArticle = false,
  });

  Widget _translateButton(BuildContext context) {
    final tint = tweetFooterButtonsColorOf(context);
    switch (translationStatus) {
      case TranslationStatus.original:
        return tweetFooterIconButton(context, Icons.translate, tint, null, () async => onTranslate());
      case TranslationStatus.translating:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator()),
        );
      case TranslationStatus.translationFailed:
        return tweetFooterIconButton(
            context,
            Icons.translate,
            Colors.red.harmonizeWith(Theme.of(context).colorScheme.primary),
            null,
            () async => onTranslate());
      case TranslationStatus.translated:
        return tweetFooterIconButton(
            context, Icons.translate, Theme.of(context).colorScheme.primary, null, onShowOriginal);
    }
  }

  void _showShareSheet(BuildContext context) {
    ListTile createSheetButton(String title, IconData icon, VoidCallback onTap) => ListTile(
          onTap: onTap,
          leading: Icon(icon),
          title: Text(title),
        );

    showModalBottomSheet(
        context: context,
        builder: (sheetContext) {
          return SafeArea(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isArticle)
                createSheetButton(
                  L10n.of(sheetContext).share_tweet_content,
                  Icons.text_snippet,
                  () async {
                    Share.share(shareableTweetText(tweet, tweetText));
                    Navigator.pop(sheetContext);
                  },
                ),
              createSheetButton(
                  isArticle ? L10n.of(sheetContext).share_article_link : L10n.of(sheetContext).share_tweet_link,
                  Icons.link, () async {
                Share.share('$shareBaseUrl/${tweet.user!.screenName}/status/${tweet.idStr}');
                Navigator.pop(sheetContext);
              }),
              if (!isArticle)
                createSheetButton(L10n.of(sheetContext).share_tweet_content_and_link, Icons.add_link, () async {
                  Share.share(
                      '${shareableTweetText(tweet, tweetText)}\n\n$shareBaseUrl/${tweet.user!.screenName}/status/${tweet.idStr}');
                  Navigator.pop(sheetContext);
                }),
              createSheetButton(
                  isArticle ? L10n.of(sheetContext).share_article_as_image : L10n.of(sheetContext).share_tweet_as_image,
                  Icons.screenshot, () async {
                final imgBytes = await onCaptureImage();
                if (imgBytes != null) {
                  Share.shareXFiles([XFile.fromData(imgBytes, mimeType: 'image/png')]);
                }
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                }
              }),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(thickness: 1.0),
              ),
              createSheetButton(
                L10n.of(sheetContext).cancel,
                Icons.close,
                () => Navigator.pop(sheetContext),
              )
            ],
          ));
        });
  }

  @override
  Widget build(BuildContext context) {
    final zen = PrefService.of(context, listen: false).get(optionZenMode) == true;
    final tint = tweetFooterButtonsColorOf(context);

    return Container(
      alignment: Alignment.center,
      margin: isArticle ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onLongPress: () {
                      try {
                        context.read<ZenRepliesState>().reveal();
                      } catch (_) {
                        onOpenTweet();
                      }
                    },
                    child: tweetFooterTextButton(
                        Icons.mode_comment_outlined,
                        zen || tweet.replyCount == null ? '' : numberFormat.format(tweet.replyCount),
                        tint,
                        onOpenTweet),
                  ),
                  if (!zen && tweet.retweetCount != null && tweet.quoteCount != null)
                    tweetFooterTextButton(
                        Icons.repeat,
                        numberFormat.format(tweet.retweetCount! + tweet.quoteCount!),
                        tweet.quoteCount! > 0
                            ? Colors.green.harmonizeWith(Theme.of(context).colorScheme.primary)
                            : tint,
                        tweet.idStr == null
                            ? null
                            : () => Navigator.pushNamed(context, routeQuotes,
                                arguments: QuotesScreenArguments(id: tweet.idStr!))),
                  Consumer<LikedTweetModel>(builder: (context, likedModel, child) {
                    final isLiked = likedModel.isLiked(tweet.idStr!);
                    final label = zen || tweet.favoriteCount == null ? '' : numberFormat.format(tweet.favoriteCount);

                    return LikeButton(
                      isLiked: isLiked,
                      label: label,
                      color: isLiked ? Theme.of(context).colorScheme.primary : tint,
                      onPressed: () async {
                        if (isLiked) {
                          await likedModel.unlikeTweet(tweet.idStr!);
                        } else {
                          await likedModel.likeTweet(tweet.idStr!, tweet.user?.idStr, tweet.toJson());
                        }
                        onChanged();
                        if (!isLiked && context.mounted) {
                          maybeShowLikeToast(context);
                        }
                      },
                    );
                  }),
                  if (!zen && tweet.viewCount != null)
                    tweetFooterTextButton(Icons.bar_chart, numberFormat.format(tweet.viewCount), tint),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          Consumer<SavedTweetModel>(builder: (context, model, child) {
            final isSaved = model.isSaved(tweet.idStr!);
            final button = isSaved
                ? tweetFooterIconButton(context, Icons.bookmark, Theme.of(context).colorScheme.primary, 1, () async {
                    await model.deleteSavedTweet(tweet.idStr!);
                    onChanged();
                  })
                : tweetFooterIconButton(context, Icons.bookmark_border, tint, 0, () async {
                    await model.saveTweet(tweet.idStr!, tweet.user?.idStr, tweet.toJson());
                    onChanged();
                    if (context.mounted) {
                      maybeShowFolderHint(context);
                    }
                  });

            return GestureDetector(
              onLongPress: () async {
                await showSaveToFolderSheet(context,
                    tweetId: tweet.idStr!, userId: tweet.user?.idStr, content: tweet.toJson());
                onChanged();
              },
              child: button,
            );
          }),
          tweetFooterIconButton(context, Icons.share, tint, null, () => _showShareSheet(context)),
          if (!isArticle)
            GestureDetector(
              onLongPress: onTranslateLongPress ?? () => onTranslate(),
              child: _translateButton(context),
            ),
        ],
      ),
    );
  }
}
