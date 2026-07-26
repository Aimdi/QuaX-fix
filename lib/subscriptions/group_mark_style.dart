import 'dart:convert';

import 'package:flutter/material.dart';

/// How a group's identity mark is chosen. Stored as INTEGER on
/// `subscription_group.mark_style`.
abstract final class GroupMarkStyle {
  /// Resolver ladder: emoji (if set) → single initial → stored symbol → initial.
  static const int auto = 0;

  /// Prefer [SubscriptionGroup.emoji] (system emoji); fall back to initial.
  static const int emoji = 1;

  /// Prefer the stored Material icon JSON; fall back to initial.
  static const int symbol = 2;

  /// Deterministic generated mark — maps to the initial fallback (no generative package).
  static const int generated = 3;

  static const Set<int> values = {auto, emoji, symbol, generated};

  static int coerce(Object? raw) {
    final v = raw is int ? raw : int.tryParse('$raw');
    if (v != null && values.contains(v)) {
      return v;
    }
    return auto;
  }
}

/// Curated icons for the group edit sheet (not the unrestricted picker).
const List<({String key, IconData data})> curatedGroupIcons = [
  (key: 'star', data: Icons.star),
  (key: 'favorite', data: Icons.favorite),
  (key: 'bookmark', data: Icons.bookmark),
  (key: 'home', data: Icons.home),
  (key: 'work', data: Icons.work),
  (key: 'school', data: Icons.school),
  (key: 'sports_soccer', data: Icons.sports_soccer),
  (key: 'music_note', data: Icons.music_note),
  (key: 'movie', data: Icons.movie),
  (key: 'tv', data: Icons.tv),
  (key: 'sports_esports', data: Icons.sports_esports),
  (key: 'palette', data: Icons.palette),
  (key: 'brush', data: Icons.brush),
  (key: 'camera_alt', data: Icons.camera_alt),
  (key: 'photo', data: Icons.photo),
  (key: 'pets', data: Icons.pets),
  (key: 'eco', data: Icons.eco),
  (key: 'public', data: Icons.public),
  (key: 'flight', data: Icons.flight),
  (key: 'directions_car', data: Icons.directions_car),
  (key: 'train', data: Icons.train),
  (key: 'restaurant', data: Icons.restaurant),
  (key: 'local_cafe', data: Icons.local_cafe),
  (key: 'shopping_bag', data: Icons.shopping_bag),
  (key: 'attach_money', data: Icons.attach_money),
  (key: 'code', data: Icons.code),
  (key: 'science', data: Icons.science),
  (key: 'health_and_safety', data: Icons.health_and_safety),
  (key: 'tag', data: Icons.tag),
  (key: 'bolt', data: Icons.bolt),
  (key: 'nightlight', data: Icons.nightlight),
  (key: 'wb_sunny', data: Icons.wb_sunny),
  (key: 'cloud', data: Icons.cloud),
  (key: 'groups', data: Icons.groups),
  (key: 'person', data: Icons.person),
  (key: 'newspaper', data: Icons.newspaper),
  (key: 'campaign', data: Icons.campaign),
  (key: 'interests', data: Icons.interests),
  (key: 'auto_awesome', data: Icons.auto_awesome),
  (key: 'forest', data: Icons.forest),
  // Subjects people actually keep feeds about, which the first forty missed:
  // news beats, hobbies, and the things worth a folder of their own.
  (key: 'trending_up', data: Icons.trending_up),
  (key: 'show_chart', data: Icons.show_chart),
  (key: 'account_balance', data: Icons.account_balance),
  (key: 'gavel', data: Icons.gavel),
  (key: 'rocket_launch', data: Icons.rocket_launch),
  (key: 'memory', data: Icons.memory),
  (key: 'smart_toy', data: Icons.smart_toy),
  (key: 'terminal', data: Icons.terminal),
  (key: 'security', data: Icons.security),
  (key: 'menu_book', data: Icons.menu_book),
  (key: 'edit_note', data: Icons.edit_note),
  (key: 'mic', data: Icons.mic),
  (key: 'headphones', data: Icons.headphones),
  (key: 'theater_comedy', data: Icons.theater_comedy),
  (key: 'sports_basketball', data: Icons.sports_basketball),
  (key: 'sports_tennis', data: Icons.sports_tennis),
  (key: 'sports_motorsports', data: Icons.sports_motorsports),
  (key: 'directions_bike', data: Icons.directions_bike),
  (key: 'fitness_center', data: Icons.fitness_center),
  (key: 'hiking', data: Icons.hiking),
  (key: 'sailing', data: Icons.sailing),
  (key: 'terrain', data: Icons.terrain),
  (key: 'beach_access', data: Icons.beach_access),
  (key: 'ac_unit', data: Icons.ac_unit),
  (key: 'local_florist', data: Icons.local_florist),
  (key: 'local_bar', data: Icons.local_bar),
  (key: 'local_pizza', data: Icons.local_pizza),
  (key: 'cake', data: Icons.cake),
  (key: 'construction', data: Icons.construction),
  (key: 'handyman', data: Icons.handyman),
  (key: 'architecture', data: Icons.architecture),
  (key: 'psychology', data: Icons.psychology),
  (key: 'church', data: Icons.church),
  (key: 'diversity_3', data: Icons.diversity_3),
  (key: 'volunteer_activism', data: Icons.volunteer_activism),
  (key: 'child_care', data: Icons.child_care),
  (key: 'celebration', data: Icons.celebration),
  (key: 'emoji_events', data: Icons.emoji_events),
  (key: 'casino', data: Icons.casino),
  (key: 'extension', data: Icons.extension),
  (key: 'toys', data: Icons.toys),
  (key: 'watch', data: Icons.watch),
  (key: 'checkroom', data: Icons.checkroom),
  (key: 'diamond', data: Icons.diamond),
  (key: 'key', data: Icons.key),
  (key: 'lightbulb', data: Icons.lightbulb),
  (key: 'travel_explore', data: Icons.travel_explore),
  (key: 'map', data: Icons.map),
  (key: 'apartment', data: Icons.apartment),
  (key: 'anchor', data: Icons.anchor),
  (key: 'whatshot', data: Icons.whatshot),
  (key: 'ac_unit_outlined', data: Icons.severe_cold),
  (key: 'water_drop', data: Icons.water_drop),
  (key: 'recycling', data: Icons.recycling),
];

/// Stable custom-pack JSON so [deserializeIconData] does not depend on the
/// flutter_iconpicker Material catalog key set.
String serializeCuratedGroupIcon(String key, IconData data) {
  return jsonEncode({
    'pack': 'custom',
    'key': key,
    'iconData': {
      'codePoint': data.codePoint,
      'fontFamily': data.fontFamily,
      'fontPackage': data.fontPackage,
      'matchTextDirection': data.matchTextDirection,
    },
  });
}
