import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/user.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';

const String _checkTask = 'com.teskann.quax.checkNewPosts';
const String _channelId = 'new_posts';

final _log = Logger('PostNotifications');
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

Future<void> _initPlugin() async {
  await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
}

/// Called once at app start: sets up the notification plugin and the periodic
/// background check (kept only while at least one user has the bell enabled).
Future<void> initPostNotifications() async {
  await _initPlugin();
  await Workmanager().initialize(postNotificationsDispatcher);
  await _syncBackgroundTask();
}

Future<void> _syncBackgroundTask() async {
  var repository = await Repository.readOnly();
  var count =
      Sqflite.firstIntValue(await repository.rawQuery('SELECT COUNT(*) FROM $tablePostNotification')) ?? 0;

  if (count > 0) {
    await Workmanager().registerPeriodicTask(
      _checkTask,
      _checkTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } else {
    await Workmanager().cancelByUniqueName(_checkTask);
  }
}

Future<bool> isPostNotifyEnabled(String userId) async {
  var repository = await Repository.readOnly();
  var rows = await repository.query(tablePostNotification, where: 'user_id = ?', whereArgs: [userId]);
  return rows.isNotEmpty;
}

Future<void> setPostNotifyEnabled(UserWithExtra user, bool enabled) async {
  var repository = await Repository.writable();

  if (enabled) {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await repository.insert(
        tablePostNotification,
        {'user_id': user.idStr, 'screen_name': user.screenName, 'name': user.name},
        conflictAlgorithm: ConflictAlgorithm.replace);
  } else {
    await repository.delete(tablePostNotification, where: 'user_id = ?', whereArgs: [user.idStr]);
  }

  await _syncBackgroundTask();
}

@pragma('vm:entry-point')
void postNotificationsDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await checkForNewPosts();
    } catch (e, stackTrace) {
      // Never fail the task: WorkManager would back off and delay future runs.
      _log.warning('New-post check failed: $e', e, stackTrace);
    }
    return true;
  });
}

BigInt? _newestIdOf(Iterable<TweetWithCard> tweets) => tweets
    .map((t) => BigInt.parse(t.idStr!))
    .fold<BigInt?>(null, (max, id) => max == null || id > max ? id : max);

Future<void> checkForNewPosts() async {
  var repository = await Repository.writable();
  var watched = await repository.query(tablePostNotification);
  if (watched.isEmpty) {
    return;
  }

  await _initPlugin();

  for (var row in watched) {
    var screenName = row['screen_name'] as String;

    List<TweetWithCard> tweets;
    try {
      var result = await Twitter.searchTweets('from:$screenName include:nativeretweets', false);
      tweets = result.chains
          .expand((chain) => chain.tweets)
          .where((t) => t.idStr != null && (t.user?.screenName?.toLowerCase() == screenName.toLowerCase()))
          .toList();
    } catch (e) {
      _log.warning('Could not check @$screenName for new posts: $e');
      continue;
    }

    var newestId = _newestIdOf(tweets);
    if (newestId == null) {
      continue;
    }

    var lastId = row['last_tweet_id'] as String?;
    if (lastId == null) {
      // First check after enabling the bell: only record the baseline, so the
      // existing backlog doesn't turn into a burst of notifications.
      await repository.update(tablePostNotification, {'last_tweet_id': newestId.toString()},
          where: 'user_id = ?', whereArgs: [row['user_id']]);
      continue;
    }

    var threshold = BigInt.parse(lastId);
    var fresh = tweets.where((t) => BigInt.parse(t.idStr!) > threshold).toList()
      ..sort((a, b) => BigInt.parse(a.idStr!).compareTo(BigInt.parse(b.idStr!)));
    if (fresh.isEmpty) {
      continue;
    }

    for (var tweet in fresh.take(5)) {
      await _plugin.show(
        tweet.idStr.hashCode,
        row['name'] as String? ?? '@$screenName',
        tweet.fullText ?? tweet.text ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'New posts',
            channelDescription: 'Notifications about new posts from users you enabled the bell for',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
    }

    await repository.update(tablePostNotification, {'last_tweet_id': newestId.toString()},
        where: 'user_id = ?', whereArgs: [row['user_id']]);
  }
}

/// The bell button shown on a profile: toggles new-post notifications for
/// that user.
class PostNotificationBell extends StatefulWidget {
  final UserWithExtra user;
  final Color? color;

  const PostNotificationBell({super.key, required this.user, this.color});

  @override
  State<PostNotificationBell> createState() => _PostNotificationBellState();
}

class _PostNotificationBellState extends State<PostNotificationBell> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    var userId = widget.user.idStr;
    if (userId != null) {
      isPostNotifyEnabled(userId).then((value) {
        if (mounted) {
          setState(() => _enabled = value);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.idStr == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: Icon(_enabled == true ? Icons.notifications_active : Icons.notifications_none),
      color: widget.color,
      tooltip: L10n.of(context).notify_on_new_posts,
      onPressed: _enabled == null
          ? null
          : () async {
              var newValue = !_enabled!;
              await setPostNotifyEnabled(widget.user, newValue);
              if (mounted) {
                setState(() => _enabled = newValue);
              }
            },
    );
  }
}
