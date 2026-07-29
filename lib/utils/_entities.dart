import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:xta/utils/urls.dart';

abstract class Entity {
  List<int>? indices;
  
  Entity(this.indices);
  
  InlineSpan getContent();
  
  int getEntityStart() {
    return indices![0];
  }
  
  int getEntityEnd() {
    return indices![1];
  }
}

class HashtagEntity extends Entity {
  final Hashtag hashtag;
  final Function onTap;

  HashtagEntity(this.hashtag, this.onTap) : super(hashtag.indices);

  @override
  InlineSpan getContent() {
    return TextSpan(
        text: '#${hashtag.text}',
        style: const TextStyle(color: Colors.blue),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            onTap();
          });
  }
}

/// A cashtag — `$AAPL` — which X sends as a symbol entity.
///
/// These were parsed off the wire and then dropped on the floor: the text still
/// read `$AAPL`, but as plain grey prose with nothing to tap, so a ticker in a
/// post was a dead end.
/// Takes the ticker text rather than the API's own symbol class: that class is
/// named `Symbol`, which `dart:core` already uses.
class SymbolEntity extends Entity {
  final String text;
  final Function onTap;

  SymbolEntity({required this.text, required List<int>? indices, required this.onTap}) : super(indices);

  @override
  InlineSpan getContent() {
    return TextSpan(
        text: '\$$text',
        style: const TextStyle(color: Colors.blue),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            onTap();
          });
  }
}

class UserMentionEntity extends Entity {
  final UserMention mention;
  final Function onTap;

  UserMentionEntity(this.mention, this.onTap) : super(mention.indices);

  @override
  InlineSpan getContent() {
    return TextSpan(
        text: '@${mention.screenName}',
        style: const TextStyle(color: Colors.blue),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            onTap();
          });
  }
}

class UrlEntity extends Entity {
  final Url url;
  final Function onTap;

  UrlEntity(this.url, this.onTap) : super(url.indices);

  @override
  InlineSpan getContent() {
    // An article link is shown as a card under the text, so leaving the URL in
    // the text too would say the same thing twice — once unreadably.
    if (articleIdIn(url.expandedUrl) != null) {
      return const TextSpan(text: '');
    }

    return TextSpan(
        text: url.displayUrl,
        style: const TextStyle(color: Colors.blue),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            onTap();
          });
  }
}

class MediaEntity extends Entity {
  final Media media;

  MediaEntity(this.media) : super(media.indices);

  @override
  InlineSpan getContent() {
    return TextSpan(text: "");
  }
}