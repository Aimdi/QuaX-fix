/// One Threads post, as much of it as a feed carries.
///
/// A feed is not the API: there are no like or reply counts here, and no
/// conversation. What survives the trip is the text, the pictures, who wrote it
/// and when — which is what reading a timeline needs.
class ThreadsPost {
  /// The entry's own id, unique across accounts — the item id the feed gave,
  /// which for this route is the post's permalink.
  final String id;

  /// The handle that produced it, without the `@`.
  final String handle;

  /// The display name, falling back to the handle when the feed has no better.
  final String authorName;

  final String? avatarUrl;
  final String text;
  final List<String> images;
  final DateTime? publishedAt;

  /// Where the post lives on Threads, for opening it there.
  final String? url;

  const ThreadsPost({
    required this.id,
    required this.handle,
    required this.authorName,
    required this.text,
    this.avatarUrl,
    this.images = const [],
    this.publishedAt,
    this.url,
  });

  bool get hasMedia => images.isNotEmpty;
}

/// An account the reader follows, as the plugin thinks of it.
class ThreadsAccount {
  /// The handle, without the `@`.
  final String handle;
  final String name;
  final String? avatarUrl;

  const ThreadsAccount({required this.handle, required this.name, this.avatarUrl});

  ThreadsAccount copyWith({String? name, String? avatarUrl}) => ThreadsAccount(
        handle: handle,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}

/// A handle as the route wants it: no `@`, no URL around it, lower case.
///
/// Readers paste all three — `@zuck`, `zuck`, and the address bar's
/// `https://www.threads.com/@zuck` — and every one of them means the same
/// account. Returns null when nothing usable is left.
String? normaliseThreadsHandle(String input) {
  var value = input.trim();
  if (value.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(value);
  if (uri != null && uri.host.contains('threads.')) {
    final segment = uri.pathSegments.where((e) => e.isNotEmpty).firstOrNull;
    value = segment ?? '';
  }

  value = value.replaceFirst(RegExp(r'^@+'), '').trim().toLowerCase();
  // Handles are letters, digits, underscores and dots — anything else came
  // from a paste that was not a handle at all.
  if (value.isEmpty || !RegExp(r'^[a-z0-9._]+$').hasMatch(value)) {
    return null;
  }
  return value;
}
