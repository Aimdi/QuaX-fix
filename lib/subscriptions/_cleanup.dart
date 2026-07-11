import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quax/catcher/exceptions.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/profile_model.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/user.dart';

typedef BrokenSubscription = ({UserSubscription user, bool suspended});
typedef RenamedSubscription = ({UserSubscription user, UserWithExtra fresh});

// Error codes X uses for accounts that definitively no longer exist:
// 34/50 = not found, 63 = suspended, -1 = unavailable for another reason.
const _goneCodes = {34, 50, 63, -1};

enum _CheckResult { exists, gone, suspended, unreachable, rateLimited }

class BrokenSubscriptionsDialog extends StatefulWidget {
  const BrokenSubscriptionsDialog({super.key});

  @override
  State<BrokenSubscriptionsDialog> createState() => _BrokenSubscriptionsDialogState();
}

class _BrokenSubscriptionsDialogState extends State<BrokenSubscriptionsDialog> {
  late final List<UserSubscription> _toCheck;
  late final SubscriptionsModel _model;
  final List<BrokenSubscription> _broken = [];
  final List<RenamedSubscription> _renamed = [];
  int _checked = 0;
  int _unreachable = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();

    _model = context.read<SubscriptionsModel>();
    _toCheck = _model.state.whereType<UserSubscription>().toList();
    _scan();
  }

  Future<void> _scan() async {
    for (final user in _toCheck) {
      if (!mounted) {
        return;
      }

      final aborted = await _checkSubscription(user);
      if (aborted || !mounted) {
        break;
      }

      setState(() {
        _checked++;
      });

      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted) {
      if (_renamed.isNotEmpty) {
        await _model.reloadSubscriptions();
      }
      if (mounted) {
        setState(() {
          _unreachable += _toCheck.length - _checked;
          _done = true;
        });
      }
    }
  }

  /// Returns true when the scan must stop early (rate limited).
  Future<bool> _checkSubscription(UserSubscription user) async {
    // The app opens profiles by screen name, so that lookup is the reference
    // for whether a subscription still works.
    final byName = await _lookup(() => Twitter.getProfileByScreenName(user.screenName));
    switch (byName) {
      case _CheckResult.exists:
        return false;
      case _CheckResult.suspended:
        _broken.add((user: user, suspended: true));
        return false;
      case _CheckResult.unreachable:
        _unreachable++;
        return false;
      case _CheckResult.rateLimited:
        return true;
      case _CheckResult.gone:
        break;
    }

    // The screen name is gone; the id tells a rename (repairable) apart from a
    // genuinely deleted account.
    try {
      final profile = await Twitter.getProfileById(user.id);
      await _model.repairSubscription(user, profile.user);
      _renamed.add((user: user, fresh: profile.user));
      return false;
    } on TwitterError catch (e) {
      if (_goneCodes.contains(e.code)) {
        _broken.add((user: user, suspended: e.code == 63));
      } else {
        _unreachable++;
      }
      return false;
    } on RateLimitedException {
      return true;
    } catch (_) {
      _broken.add((user: user, suspended: false));
      return false;
    }
  }

  Future<_CheckResult> _lookup(Future<Profile> Function() fetch) async {
    try {
      await fetch();
      return _CheckResult.exists;
    } on TwitterError catch (e) {
      if (e.code == 63) {
        return _CheckResult.suspended;
      }
      return _goneCodes.contains(e.code) ? _CheckResult.gone : _CheckResult.unreachable;
    } on RateLimitedException {
      return _CheckResult.rateLimited;
    } catch (_) {
      return _CheckResult.unreachable;
    }
  }

  Future<void> _deleteBroken() async {
    final navigator = Navigator.of(context);

    await _model.removeSubscriptions(_broken.map((e) => e.user).toList());

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

  Widget _buildHint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
      ),
    );
  }

  Widget _buildBrokenList(BuildContext context) {
    return Flexible(
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
    );
  }

  Widget _buildResults(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_broken.isEmpty) Text(L10n.of(context).no_broken_subscriptions_found),
        if (_broken.isNotEmpty) Text(L10n.of(context).broken_subscriptions_found),
        if (_broken.isNotEmpty) const SizedBox(height: 8),
        if (_broken.isNotEmpty) _buildBrokenList(context),
        if (_renamed.isNotEmpty)
          _buildHint(
            context,
            '${L10n.of(context).renamed_subscriptions_updated}\n${_renamed.map((e) => '@${e.user.screenName} → @${e.fresh.screenName}').join('\n')}',
          ),
        if (_unreachable > 0) _buildHint(context, L10n.of(context).some_subscriptions_could_not_be_checked),
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
