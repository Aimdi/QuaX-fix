import 'dart:convert';
import 'dart:math';

import 'package:bech32/bech32.dart';
import 'package:bip340/bip340.dart' as bip340;
import 'package:crypto/crypto.dart';

/// NIP-B0 web bookmark.
const int kindWebBookmark = 39701;

/// A signed Nostr event, ready for Deepmarks to fan out to relays.
class NostrEvent {
  final String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String sig;

  const NostrEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
    required this.sig,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'pubkey': pubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': sig,
      };
}

class NostrKeyException implements Exception {
  final String detail;

  const NostrKeyException(this.detail);

  @override
  String toString() => 'NostrKeyException: $detail';
}

final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

/// Accepts a secret key as `nsec1…` (NIP-19 bech32) or bare 64-char hex, and
/// returns it as hex.
///
/// Throws [NostrKeyException] rather than returning null so the caller can tell
/// the user what is wrong with what they pasted.
String normaliseNostrSecretKey(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    throw const NostrKeyException('empty');
  }

  final lower = text.toLowerCase();
  if (_hex64.hasMatch(lower)) {
    return lower;
  }

  if (!lower.startsWith('nsec1')) {
    throw const NostrKeyException('not an nsec or 64-character hex key');
  }

  try {
    // The default codec caps length at 90 chars, which an nsec fits inside.
    final decoded = bech32.decode(lower);
    if (decoded.hrp != 'nsec') {
      throw const NostrKeyException('not an nsec');
    }
    final bytes = _fromWords(decoded.data);
    if (bytes.length != 32) {
      throw const NostrKeyException('nsec does not hold a 32-byte key');
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  } on NostrKeyException {
    rethrow;
  } catch (e) {
    throw NostrKeyException('could not decode the nsec ($e)');
  }
}

/// bech32 5-bit groups back to bytes (NIP-19 stores the key as 5-bit words).
List<int> _fromWords(List<int> words) {
  var accumulator = 0;
  var bits = 0;
  final result = <int>[];

  for (final word in words) {
    if (word < 0 || word >> 5 != 0) {
      throw const NostrKeyException('invalid bech32 payload');
    }
    accumulator = (accumulator << 5) | word;
    bits += 5;
    while (bits >= 8) {
      bits -= 8;
      result.add((accumulator >> bits) & 0xff);
    }
  }

  if (bits >= 5 || ((accumulator << (8 - bits)) & 0xff) != 0) {
    throw const NostrKeyException('invalid bech32 padding');
  }
  return result;
}

/// x-only public key for [secretKeyHex], as Nostr uses it.
String nostrPublicKey(String secretKeyHex) => bip340.getPublicKey(secretKeyHex);

/// NIP-01 event id: sha256 over the canonical `[0, pubkey, created_at, kind,
/// tags, content]` serialisation.
String nostrEventId({
  required String pubkey,
  required int createdAt,
  required int kind,
  required List<List<String>> tags,
  required String content,
}) {
  final serialised = jsonEncode([0, pubkey, createdAt, kind, tags, content]);
  return sha256.convert(utf8.encode(serialised)).toString();
}

/// Builds the tags for a bookmark. `d` carries the URL (Deepmarks requires an
/// http(s) one), `title` and `description` are optional, and each entry in
/// [topics] becomes a `t` tag.
List<List<String>> webBookmarkTags({
  required String url,
  String? title,
  String? description,
  List<String> topics = const [],
}) {
  return [
    ['d', url],
    if (title != null && title.trim().isNotEmpty) ['title', title.trim()],
    if (description != null && description.trim().isNotEmpty) ['description', description.trim()],
    for (final topic in topics)
      if (topic.trim().isNotEmpty) ['t', topic.trim().toLowerCase()],
  ];
}

/// Signs a `kind:39701` bookmark locally. The secret key never leaves the
/// device: Deepmarks only ever receives the finished event.
NostrEvent signWebBookmark({
  required String secretKeyHex,
  required String url,
  String? title,
  String? description,
  List<String> topics = const [],
  DateTime? now,
  String? auxRandomHex,
}) {
  final pubkey = nostrPublicKey(secretKeyHex);
  final createdAt = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
  final tags = webBookmarkTags(url: url, title: title, description: description, topics: topics);
  const kind = kindWebBookmark;

  final id = nostrEventId(
    pubkey: pubkey,
    createdAt: createdAt,
    kind: kind,
    tags: tags,
    content: '',
  );

  // BIP-340 takes 32 bytes of auxiliary randomness; bip340 wants it as hex.
  final aux = auxRandomHex ?? _randomHex32();
  final sig = bip340.sign(secretKeyHex, id, aux);

  return NostrEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    kind: kind,
    tags: tags,
    content: '',
    sig: sig,
  );
}

String _randomHex32() {
  final random = _secureRandom();
  return List.generate(32, (_) => random().toRadixString(16).padLeft(2, '0')).join();
}

int Function() _secureRandom() {
  final random = Random.secure();
  return () => random.nextInt(256);
}
