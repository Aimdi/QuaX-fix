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
