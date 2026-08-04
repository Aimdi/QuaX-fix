import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/client/client.dart';
import 'package:xta/constants.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/reddit/reddit_client.dart';
import 'package:xta/plugins/reddit/reddit_store.dart';
import 'package:xta/subscriptions/users_model.dart';
import 'package:xta/user.dart';

/// Adds something new to a group without leaving the group.
///
/// The member list only ever offered what was already subscribed to, so putting
/// an account or a subreddit into a group meant going and following it first,
/// somewhere else, then coming back. This searches X and accepts a subreddit
/// name, follows whatever is chosen, and hands the ids back to be ticked.
Future<Set<String>> openGroupAddMemberSheet(BuildContext context) async {
  final added = await showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: const FractionallySizedBox(heightFactor: 0.85, child: _GroupAddMemberSheet()),
    ),
  );

  return added ?? const {};
}

class _GroupAddMemberSheet extends StatefulWidget {
  const _GroupAddMemberSheet();

  @override
  State<_GroupAddMemberSheet> createState() => _GroupAddMemberSheetState();
}

class _GroupAddMemberSheetState extends State<_GroupAddMemberSheet> {
  final _controller = TextEditingController();
  final _added = <String>{};

  List<UserWithExtra>? _users;
  Object? _error;
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() {
      _query = query;
      _users = null;
      _error = null;
    });

    try {
      final users = await Twitter.searchUsers(query, limit: 20);
      if (mounted && _query == query) {
        setState(() => _users = users);
      }
    } catch (e) {
      // A failed X search must not take the subreddit row down with it: the two
      // are independent, and one is often exactly what the reader came for.
      if (mounted && _query == query) {
        setState(() => _error = e);
      }
    }
  }

  Future<void> _addUser(UserWithExtra user) async {
    final id = user.idStr;
    if (id == null || _busy) {
      return;
    }

    setState(() => _busy = true);
    await context.read<SubscriptionsModel>().toggleSubscribe(UserSubscription.fromUser(user), false);
    if (mounted) {
      setState(() {
        _added.add(id);
        _busy = false;
      });
    }
  }

  Future<void> _addSubreddit(String name) async {
    if (_busy) {
      return;
    }

    setState(() => _busy = true);
    final subscriptions = context.read<SubscriptionsModel>();
    await context.read<RedditSubredditsStore>().add(name);
    await subscriptions.reloadSubscriptions();

    if (mounted) {
      setState(() {
        // The store keys a subreddit by its lowercased name, which is the id a
        // group member row carries.
        _added.add(name.toLowerCase());
        _busy = false;
      });
    }
  }

  /// The subreddit the query names, when Reddit is on and the name is one.
  String? get _subreddit {
    if (PrefService.of(context, listen: false).get<bool>(optionPluginRedditEnabled) != true) {
      return null;
    }
    return normaliseSubreddit(_query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.search,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: _search,
          ),
          const SizedBox(height: 8),
          Expanded(child: _results(context)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context, _added),
              child: Text(l10n.ok),
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context) {
    final l10n = L10n.of(context);
    if (_query.isEmpty) {
      return const SizedBox.shrink();
    }

    final subreddit = _subreddit;
    final users = _users;

    return ListView(
      children: [
        if (subreddit != null)
          ListTile(
            leading: const Icon(Icons.travel_explore),
            title: Text('r/$subreddit'),
            trailing: _added.contains(subreddit.toLowerCase()) ? const Icon(Icons.check) : const Icon(Icons.add),
            onTap: () => _addSubreddit(subreddit),
          ),
        if (_error != null)
          ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(l10n.unable_to_load_the_search_results),
          )
        else if (users == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (users.isEmpty && subreddit == null)
          Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(l10n.no_results)))
        else
          for (final user in users)
            ListTile(
              leading: UserAvatar(uri: user.profileImageUrlHttps),
              title: Text(user.name ?? ''),
              subtitle: Text('@${user.screenName ?? ''}'),
              trailing:
                  _added.contains(user.idStr) ? const Icon(Icons.check) : const Icon(Icons.add),
              onTap: () => _addUser(user),
            ),
      ],
    );
  }
}
