import 'package:flutter/material.dart';
import 'package:xta/generated/l10n.dart';

/// Why a plugin exists, for the store — not how it is installed.
enum PluginCategory {
  /// Feeds and publications to read (Reddit, Substack, Threads).
  reading,

  /// Prices and markets (Stocks).
  markets,

  /// Send or keep bookmarks elsewhere (Karakeep, Deepmarks).
  bookmarks,

  /// Photos and media destinations (Immich).
  media,
}

extension PluginCategoryL10n on PluginCategory {
  String label(BuildContext context) {
    final l10n = L10n.of(context);
    return switch (this) {
      PluginCategory.reading => l10n.plugin_category_reading,
      PluginCategory.markets => l10n.plugin_category_markets,
      PluginCategory.bookmarks => l10n.plugin_category_bookmarks,
      PluginCategory.media => l10n.plugin_category_media,
    };
  }
}

/// Store order: reading first, then markets, then save destinations, then media.
const pluginCategoryOrder = PluginCategory.values;
