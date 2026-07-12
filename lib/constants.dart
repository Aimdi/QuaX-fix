import 'package:flutter/material.dart';

const optionDisableAnimations = 'accessibility.disable_animations';
const optionTextScaleFactor = 'accessibility.text_scale_factor';

const optionWizardCompleted = 'option.wizard_completed';

const optionDisableScreenshots = 'disable_screenshots';
const optionHelloLastBuild = 'hello.last_build';

const optionHomePages = 'home.pages';
const optionHomeInitialTab = 'home.initial_tab';
const optionHomeDefaultFeedTab = 'home.default_feed_tab';

const optionImageQuality = 'media.size';
const optionMediaVideoQuality = 'media.video_quality';
const optionMediaDisableAutoload = 'media.disable_autoload';
const optionMediaQualitySplitMigrated = 'media.quality_split_migrated';
const optionMediaGridColumns = 'media.grid_columns';
const optionMediaDefaultMute = 'media.mute';
const optionMediaDefaultLoop = 'media.loop';
const optionMediaDefaultAutoPlay = 'media.auto_play';
const optionMediaBackgroundPlayback = 'media.allow_background_play';
const optionMediaAllowBackgroundPlayOtherApps = 'media.allow_background_play.other_apps';
const optionMediaVideoPrefetchSeconds = 'media.video_prefetch_seconds';

const optionDownloadType = 'download.type';
const optionDownloadPath = 'download.path';

const optionDownloadTypeDirectory = 'directory';
const optionDownloadTypeAsk = 'ask';

const optionLocale = 'locale';
const optionLocaleDefault = 'system';

const optionShouldCheckForUpdates = 'should_check_for_updates';
const optionConfirmClose = 'confirm_close';
const optionShareBaseUrl = 'share_base_url';

const optionDisableWarningsForUnrelatedPostsInFeed = 'disable_warnings_for_unrelated_posts_in_feed';

const alwaysShowFullTweetContents = 'always_show_full_tweet_contents';

const optionSubscriptionGroupsOrderByAscending = 'subscription_groups.order_by.ascending';
const optionSubscriptionGroupsOrderByField = 'subscription_groups.order_by.field';
const optionSubscriptionOrderByAscending = 'subscription.order_by.ascending';
const optionSubscriptionOrderCustom = 'subscription.order_by.custom';
const optionSubscriptionOrderByField = 'subscription.order_by.field';
const optionDefaultProfileTab = 'subscription.default_tab';

const optionThemeMode = 'theme.mode';
const optionThemeColor = 'theme.color';
const optionThemePreset = 'theme.preset';

const themePresetNone = 'none';
const themePresetFairyForest = 'fairy_forest';
const themePresetPitchBlack = 'pitch_black';
const optionThemeTrueBlack = 'theme.true_black';
const optionThemeTrueBlackTweetCards = 'theme.true_black_tweet_cards';
const optionShowNavigationLabels = 'theme.show_navigation_labels';
const optionUseAbsoluteTimestamp = "option.absolute_timestamp";

const themeColors = {
  'red': Colors.red,
  'orange': Colors.orange,
  'yellow': Colors.yellow,
  'green': Colors.green,
  'blue': Colors.blue,
  'indigo': Colors.indigo,
  'violet': Color.fromARGB(255, 128, 0, 255),
};

const optionTweetsHideSensitive = 'tweets.hide_sensitive';

const optionSavedShowAllTab = 'saved.show_all_tab';
const optionSavedShowUnfiledTab = 'saved.show_unfiled_tab';
const optionSavedShowFavoritesTab = 'saved.show_favorites_tab';
const optionSavedTabOrder = 'saved.tab_order';
const optionSavedFolderHintShown = 'saved.folder_hint_shown';
const optionLikedFirstToastShown = 'saved.liked_first_toast_shown';

const optionUserTrendsLocations = 'trends.locations';

const optionNonConfirmationBiasMode = 'other.improve_non_confirmation_bias';
const optionTweetsShowSubscribeBadge = 'tweets.show_subscribe_badge';
const optionZenMode = 'other.zen_mode';
const optionZenModePageCap = 'other.zen_mode_page_cap';
const optionFeedReadingPosition = 'feed.reading_position';
// Global defaults for feeds; a group can override each per-feed (null override
// = follow these).
const optionGlobalIncludeReplies = 'feed.global_include_replies';
const optionGlobalIncludeRetweets = 'feed.global_include_retweets';
// Show replies under an opened post as a nested, indented tree.
const optionThreadedReplies = 'tweets.threaded_replies';
const optionMediaGridLayout = 'media.grid_layout';

const mediaGridLayoutMasonry = 'masonry';
const mediaGridLayoutFeed = 'feed';
const mediaGridLayoutTwoColumns = 'two_columns';

// Per-group content filter (custom feed mode)
const contentFilterSfw = 'sfw';
const contentFilterDefault = 'default';
const contentFilterNsfw = 'nsfw';

// How many posts per author survive a feed page in zen mode
const zenModeMaxTweetsPerAuthor = 4;

// Selectable values for the zen-mode page cap (pages per feed session)
const zenModePageCapChoices = [3, 5, 10, 20];

// How many extra pages an initial feed load may fetch per chunk to close the
// gap between freshly fetched posts and the previously stored ones
const maxFeedGapFillPages = 4;

// Reading position ("You're caught up"): how close to the top counts as
// having read everything, and how many frames the divider restore may take.
const feedReadPositionTopThresholdPx = 8.0;
const maxCaughtUpRestoreFrames = 30;


final Map<String, String> userAgentHeader = {
  'user-agent':
      "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.3",
  "Pragma": "no-cache",
  "Cache-Control": "no-cache"
  // "If-Modified-Since": "Sat, 1 Jan 2000 00:00:00 GMT",
};

const String bearerToken =
    "Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA";

// Account selection strategy: cooldowns and flagging thresholds.
const Duration rateLimitFallback = Duration(minutes: 15);
const Duration notFoundCooldown = Duration(hours: 6);
const int notFoundThreshold = 3;

const routeHome = '/';
const routeGroup = '/group';
const routeProfile = '/profile';
const routeSearch = '/search';
const routeSavedFolders = '/saved/folders';
const routeSettings = '/settings';
const routeSettingsExport = '/settings/export';
const routeSettingsHome = '/settings/home';
const routeQuotes = '/quotes';
const routeStatus = '/status';
