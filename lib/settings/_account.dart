import 'package:flutter/material.dart';
import 'package:xta/client/client_regular_account.dart';
import 'package:xta/client/login_webview.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/client/accounts.dart';

class SettingsAccountFragment extends StatefulWidget {
  const SettingsAccountFragment({super.key});

  @override
  State<SettingsAccountFragment> createState() => _SettingsAccountFragment();
}

/// What sits behind a row being swiped away, so the gesture says what it does
/// before it has done it.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: scheme.errorContainer,
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}

/// Asked before the row goes, because losing the last working account leaves
/// the app unable to fetch anything and there is no undoing it: the session
/// only ever existed on this device.
Future<bool> _confirmDelete(BuildContext context, Account account) async {
  final l10n = L10n.of(context);
  final name = account.screenName ?? l10n.unknown_username;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.are_you_sure),
      content: Text(l10n.account_delete_confirm(name)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.delete)),
      ],
    ),
  );

  return confirmed ?? false;
}

class _SettingsAccountFragment extends State<SettingsAccountFragment> {
  @override
  Widget build(BuildContext context) {
    var model = XRegularAccount();
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.current.account),
        actions: [
          IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TwitterLoginWebview())),
              icon: const Icon(Icons.add))
        ],
      ),
      body: FutureBuilder(
          future: getAccounts(),
          builder: (BuildContext listContext, AsyncSnapshot snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            } else {
              List<Account> data = snapshot.data;
              return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (BuildContext itemContext, int index) {
                    final account = data[index];
                    return Dismissible(
                        // Every row shared one key, so dismissing an account
                        // handed its dismissed state to the row beneath it.
                        key: ValueKey(account.id),
                        // One way only, with something behind it: a swipe that
                        // could go either way and showed nothing gave no hint
                        // that it deleted, and no chance to change course.
                        direction: DismissDirection.endToStart,
                        background: const _DeleteBackground(),
                        confirmDismiss: (_) => _confirmDelete(context, account),
                        onDismissed: (DismissDirection direction) async {
                          await model.deleteAccount(account.id.toString());
                          setState(() {});
                        },
                        child: Card(
                            child: ListTile(
                          title: Text(account.screenName ?? L10n.of(context).unknown_username),
                          leading: const Icon(Icons.account_circle),
                        )));
                  });
            }
          }),
    );
  }
}
