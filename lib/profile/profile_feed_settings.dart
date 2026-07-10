import 'package:flutter/material.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/user.dart';
import 'package:sqflite/sqflite.dart';

/// Per-user feed filters ("turn off reposts"): users listed in
/// [tableRetweetFilter] have their retweets hidden from every feed.

Future<bool> isRetweetsHidden(String userId) async {
  var repository = await Repository.readOnly();
  var rows = await repository.query(tableRetweetFilter, where: 'user_id = ?', whereArgs: [userId]);
  return rows.isNotEmpty;
}

Future<void> setRetweetsHidden(UserWithExtra user, bool hidden) async {
  var repository = await Repository.writable();
  if (hidden) {
    await repository.insert(tableRetweetFilter, {'user_id': user.idStr, 'screen_name': user.screenName},
        conflictAlgorithm: ConflictAlgorithm.replace);
  } else {
    await repository.delete(tableRetweetFilter, where: 'user_id = ?', whereArgs: [user.idStr]);
  }
}

/// Lowercased screen names whose retweets are hidden.
Future<Set<String>> hiddenRetweetScreenNames() async {
  var repository = await Repository.readOnly();
  return (await repository.query(tableRetweetFilter, columns: ['screen_name']))
      .map((row) => (row['screen_name'] as String).toLowerCase())
      .toSet();
}

/// Drops chains that are a retweet made by one of the [hidden] users.
List<TweetChain> filterHiddenRetweets(List<TweetChain> chains, Set<String> hidden) {
  if (hidden.isEmpty) {
    return chains;
  }
  return chains.where((chain) {
    var tweet = chain.tweets.isEmpty ? null : chain.tweets.first;
    return tweet?.retweetedStatusWithCard == null ||
        !hidden.contains(tweet?.user?.screenName?.toLowerCase());
  }).toList();
}

/// The wrench button on a profile: per-user feed filters, like X's
/// "turn off reposts".
class ProfileFeedSettingsButton extends StatelessWidget {
  final UserWithExtra user;
  final Color? color;

  const ProfileFeedSettingsButton({super.key, required this.user, this.color});

  @override
  Widget build(BuildContext context) {
    if (user.idStr == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.build_outlined),
      color: color,
      tooltip: L10n.of(context).filters,
      onPressed: () async {
        var hidden = await isRetweetsHidden(user.idStr!);
        if (!context.mounted) {
          return;
        }

        showModalBottomSheet(
            context: context,
            builder: (sheetContext) {
              return SafeArea(
                child: StatefulBuilder(
                  builder: (sheetContext, setSheetState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: Text(L10n.of(sheetContext).hide_retweets),
                        subtitle: Text(L10n.of(sheetContext).hide_retweets_description),
                        value: hidden,
                        onChanged: (value) async {
                          await setRetweetsHidden(user, value);
                          setSheetState(() => hidden = value);
                        },
                      ),
                    ],
                  ),
                ),
              );
            });
      },
    );
  }
}
