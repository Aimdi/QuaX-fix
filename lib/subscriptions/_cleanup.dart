import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/subscriptions/users_model.dart';

typedef BrokenSubscription = ({UserSubscription user, bool suspended});

class BrokenSubscriptionsDialog extends StatefulWidget {
  const BrokenSubscriptionsDialog({super.key});

  @override
  State<BrokenSubscriptionsDialog> createState() => _BrokenSubscriptionsDialogState();
}

class _BrokenSubscriptionsDialogState extends State<BrokenSubscriptionsDialog> {
  late final List<UserSubscription> _toCheck;
  final List<BrokenSubscription> _broken = [];
  int _checked = 0;
  int _unreachable = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();

    _toCheck = context.read<SubscriptionsModel>().state.whereType<UserSubscription>().toList();
    _scan();
  }

  Future<void> _scan() async {
    for (final user in _toCheck) {
      if (!mounted) {
        return;
      }

      final broken = await _checkSubscription(user);
      if (broken != null) {
        _broken.add(broken);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _checked++;
      });

      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted) {
      setState(() {
        _done = true;
      });
    }
  }

  // Only a definitive answer from X (deleted or suspended) marks a
  // subscription as broken; transient failures leave it untouched.
  Future<BrokenSubscription?> _checkSubscription(UserSubscription user) async {
    try {
      await Twitter.getProfileById(user.id);
      return null;
    } on TwitterError catch (e) {
      switch (e.code) {
        case 50:
          return (user: user, suspended: false);
        case 63:
          return (user: user, suspended: true);
        default:
          _unreachable++;
          return null;
      }
    } catch (_) {
      _unreachable++;
      return null;
    }
  }

  Future<void> _deleteBroken() async {
    final model = context.read<SubscriptionsModel>();
    final navigator = Navigator.of(context);

    await model.removeSubscriptions(_broken.map((e) => e.user).toList());

    if (mounted) {
      navigator.pop();
    }
  }

  Widget _buildProgress(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: _toCheck.isEmpty ? null : _checked / _toCheck.length,
        ),
        const SizedBox(height: 16),
        Text('${L10n.of(context).checking_subscriptions} ($_checked / ${_toCheck.length})'),
      ],
    );
  }

  Widget _buildUnreachableNote(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        L10n.of(context).some_subscriptions_could_not_be_checked,
        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_broken.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L10n.of(context).no_broken_subscriptions_found),
          if (_unreachable > 0) _buildUnreachableNote(context),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(L10n.of(context).broken_subscriptions_found),
        const SizedBox(height: 8),
        Flexible(
          child: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _broken.length,
              itemBuilder: (context, index) {
                final broken = _broken[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('@${broken.user.screenName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    broken.suspended ? L10n.of(context).account_suspended : L10n.of(context).user_not_found,
                  ),
                );
              },
            ),
          ),
        ),
        if (_unreachable > 0) _buildUnreachableNote(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = _done && _broken.isNotEmpty
        ? [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(L10n.of(context).cancel),
            ),
            TextButton(
              onPressed: _deleteBroken,
              child: Text('${L10n.of(context).delete} (${_broken.length})'),
            ),
          ]
        : [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_done ? L10n.of(context).close : L10n.of(context).cancel),
            ),
          ];

    return AlertDialog(
      title: Text(L10n.of(context).find_broken_subscriptions),
      content: _done ? _buildResults(context) : _buildProgress(context),
      actions: actions,
    );
  }
}
