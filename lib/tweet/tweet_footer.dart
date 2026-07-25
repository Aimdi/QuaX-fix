import 'dart:typed_data';
// intl also exports a TextDirection, so the painting one is qualified.
import 'dart:ui' as ui;

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
import 'package:quax/plugins/karakeep/karakeep_save.dart';
import 'package:quax/plugins/karakeep/karakeep_title.dart';
import 'package:quax/plugins/deepmarks/deepmarks_save.dart';

/// Footer buttons should feel flat: no ripple and no pressed/hover background.
/// Material's default text button reserves a 64dp minimum width and 16dp of
/// horizontal padding. Seven of those never fit a phone's width, which is what
/// pushed the view count off the end of the strip.
const footerButtonStyle = ButtonStyle(
  overlayColor: WidgetStatePropertyAll(Colors.transparent),
  splashFactory: NoSplash.splashFactory,
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
  minimumSize: WidgetStatePropertyAll(Size(0, 36)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  visualDensity: VisualDensity.compact,
);

/// Fixed cost of one count action: padding, the 20dp glyph and the gap Material
/// puts between an icon and its label.
const double kFooterCountItemBase = 4 + 20 + 8 + 4;

/// One icon-only action (bookmark, share, translate).
const double kFooterIconItem = 36;

/// Gap between the counts group and the icon group.
const double kFooterGroupGap = 8;

/// What the footer can afford to show at the width it was given.
@immutable
class FooterFit {
  /// Whether the reply/repost/like counts are shown next to their glyphs.
  final bool showCounts;

  /// Whether the (non-interactive) view count is shown at all.
  final bool showViews;

  /// Set when even a bare row of glyphs does not fit, so the caller scales the
  /// strip down instead of letting it clip.
  final bool mustScaleDown;

  const FooterFit({required this.showCounts, required this.showViews, required this.mustScaleDown});
}

double _stripWidth(List<double> labelWidths, int iconButtons) =>
    labelWidths.fold<double>(0, (sum, width) => sum + kFooterCountItemBase + width) +
    iconButtons * kFooterIconItem +
    kFooterGroupGap;

/// Drops what costs least first: the view count is a read-only number, so it
/// goes before any label, and labels go before any action disappears.
///
/// [countLabelWidths] are the measured widths of the reply/repost/like labels
/// and [viewsLabelWidth] that of the view count, all at the ambient text scale.
FooterFit resolveFooterFit({
  required double available,
  required List<double> countLabelWidths,
  required double? viewsLabelWidth,
  required int iconButtons,
}) {
  final counts = countLabelWidths.length;

  if (viewsLabelWidth != null &&
      _stripWidth([...countLabelWidths, viewsLabelWidth], iconButtons) <= available) {
    return const FooterFit(showCounts: true, showViews: true, mustScaleDown: false);
  }
  if (_stripWidth(countLabelWidths, iconButtons) <= available) {
    return const FooterFit(showCounts: true, showViews: false, mustScaleDown: false);
  }
  final bare = _stripWidth(List.filled(counts, 0), iconButtons);
  return FooterFit(showCounts: false, showViews: false, mustScaleDown: bare > available);
}

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

/// [tooltip] doubles as the button's accessibility label: an icon-only button
/// without one is announced as an unnamed "button", which is what a screen
/// reader used to get for every share, save and translate control in a feed.
IconButton tweetFooterIconButton(BuildContext context, IconData icon,
    [Color? color, double? fill, VoidCallback? onPressed, String? tooltip]) {
  return IconButton(
    icon: Icon(icon, fill: fill),
    color: color ?? Theme.of(context).colorScheme.primary,
    iconSize: 20,
    onPressed: onPressed,
    tooltip: tooltip,
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
///
/// QuaX is a read-oriented frontend: these controls must not post to X.
/// Comment opens the conversation, repeat opens quotes, heart/bookmark are
/// local-only, share uses the OS sheet, translate works on loaded text.
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
        return tweetFooterIconButton(
            context, Icons.translate, tint, null, () async => onTranslate(), L10n.of(context).action_translate_post);
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
            () async => onTranslate(),
            L10n.of(context).action_translate_post);
      case TranslationStatus.translated:
        return tweetFooterIconButton(context, Icons.translate, Theme.of(context).colorScheme.primary, null,
            onShowOriginal, L10n.of(context).action_show_original_post);
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
              if (deepmarksEnabled(PrefService.of(sheetContext, listen: false)))
                createSheetButton(
                  L10n.of(sheetContext).plugin_deepmarks_save_action,
                  Icons.bookmarks_outlined,
                  () async {
                    final url = '$shareBaseUrl/${tweet.user!.screenName}/status/${tweet.idStr}';
                    Navigator.pop(sheetContext);
                    await saveToDeepmarks(context, url: url, title: karakeepTitleFor(tweet, tweetText));
                  },
                ),
              if (karakeepEnabled(PrefService.of(sheetContext, listen: false)))
                createSheetButton(
                  L10n.of(sheetContext).plugin_karakeep_save_action,
                  Icons.bookmark_add_outlined,
                  () async {
                    final url = '$shareBaseUrl/${tweet.user!.screenName}/status/${tweet.idStr}';
                    Navigator.pop(sheetContext);
                    await saveToKarakeep(context, url: url, title: karakeepTitleFor(tweet, tweetText));
                  },
                ),
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
      child: LayoutBuilder(builder: (context, constraints) {
        final replyLabel = zen || tweet.replyCount == null ? '' : numberFormat.format(tweet.replyCount);
        final repostLabel = !zen && tweet.retweetCount != null && tweet.quoteCount != null
            ? numberFormat.format(tweet.retweetCount! + tweet.quoteCount!)
            : null;
        final likeLabel = zen || tweet.favoriteCount == null ? '' : numberFormat.format(tweet.favoriteCount);
        final viewsLabel = !zen && tweet.viewCount != null ? numberFormat.format(tweet.viewCount) : null;

        final measure = _LabelMeasure(context);
        final fit = resolveFooterFit(
          available: constraints.maxWidth,
          countLabelWidths: [
            measure.of(replyLabel),
            if (repostLabel != null) measure.of(repostLabel),
            measure.of(likeLabel),
          ],
          viewsLabelWidth: viewsLabel == null ? null : measure.of(viewsLabel),
          iconButtons: isArticle ? 2 : 3,
        );

        String label(String? value) => fit.showCounts ? (value ?? '') : '';

        final actions = <Widget>[
          GestureDetector(
            onLongPress: () {
              try {
                context.read<ZenRepliesState>().reveal();
              } catch (_) {
                onOpenTweet();
              }
            },
            child: tweetFooterTextButton(Icons.mode_comment_outlined, label(replyLabel), tint, onOpenTweet),
          ),
          if (repostLabel != null)
            tweetFooterTextButton(
                Icons.repeat,
                label(repostLabel),
                tweet.quoteCount! > 0
                    ? Colors.green.harmonizeWith(Theme.of(context).colorScheme.primary)
                    : tint,
                tweet.idStr == null
                    ? null
                    : () => Navigator.pushNamed(context, routeQuotes,
                        arguments: QuotesScreenArguments(id: tweet.idStr!))),
          Consumer<LikedTweetModel>(builder: (context, likedModel, child) {
            final isLiked = likedModel.isLiked(tweet.idStr!);

            return LikeButton(
              isLiked: isLiked,
              label: label(likeLabel),
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
          if (viewsLabel != null && fit.showViews)
            tweetFooterTextButton(Icons.bar_chart, viewsLabel, tint),
          Consumer<SavedTweetModel>(builder: (context, model, child) {
            final isSaved = model.isSaved(tweet.idStr!);
            final button = isSaved
                ? tweetFooterIconButton(context, Icons.bookmark, Theme.of(context).colorScheme.primary, 1, () async {
                    await model.deleteSavedTweet(tweet.idStr!);
                    onChanged();
                  }, L10n.of(context).action_unsave_post)
                : tweetFooterIconButton(context, Icons.bookmark_border, tint, 0, () async {
                    await model.saveTweet(tweet.idStr!, tweet.user?.idStr, tweet.toJson());
                    onChanged();
                    if (context.mounted) {
                      maybeShowFolderHint(context);
                    }
                  }, L10n.of(context).action_save_post);

            return GestureDetector(
              onLongPress: () async {
                await showSaveToFolderSheet(context,
                    tweetId: tweet.idStr!, userId: tweet.user?.idStr, content: tweet.toJson());
                onChanged();
              },
              child: button,
            );
          }),
          tweetFooterIconButton(
              context, Icons.share, tint, null, () => _showShareSheet(context), L10n.of(context).action_share_post),
          if (!isArticle)
            GestureDetector(
              onLongPress: onTranslateLongPress ?? () => onTranslate(),
              child: _translateButton(context),
            ),
        ];

        // Last resort for extreme text scales: shrink the whole strip rather
        // than clip a digit off the end of it.
        if (fit.mustScaleDown) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          );
        }

        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: actions);
      }),
    );
  }
}

/// Measures footer labels at the ambient text scale, so the fit decision uses
/// the width the label will actually occupy.
class _LabelMeasure {
  final TextScaler _scaler;
  final ui.TextDirection _direction;

  _LabelMeasure(BuildContext context)
      : _scaler = MediaQuery.textScalerOf(context),
        _direction = Directionality.of(context);

  double of(String label) {
    if (label.isEmpty) {
      return 0;
    }
    final painter = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(fontSize: 14)),
      textScaler: _scaler,
      textDirection: _direction,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
