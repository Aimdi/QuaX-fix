import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:xta/client/client_regular_account.dart';
import 'package:xta/client/login_webview.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/client/accounts.dart';
import 'package:xta/home/home_account_filter.dart';

class SettingsAccountFragment extends StatefulWidget {
  const SettingsAccountFragment({super.key});

  @override
  State<SettingsAccountFragment> createState() => _SettingsAccountFragment();
}

class _SettingsAccountFragment extends State<SettingsAccountFragment> {
  @override
  Widget build(BuildContext context) {
    var model = XRegularAccount();
    final filter = context.read<HomeAccountFilterStore>();
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
              if (data.isEmpty) {
                return Center(child: Text(L10n.of(context).home_feed_accounts_empty));
              }
              return ScopedBuilder<HomeAccountFilterStore, Set<String>>(
                store: filter,
                onState: (_, disabled) {
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          L10n.of(context).home_feed_accounts_description,
                          style: TextStyle(color: Theme.of(context).disabledColor),
                        ),
                      ),
                      ...data.map((account) {
                        final enabled = isHomeAccountEnabled(account.id, disabled);
                        return Dismissible(
                          key: ValueKey(account.id),
                          onDismissed: (DismissDirection direction) async {
                            await model.deleteAccount(account.id.toString());
                            setState(() {});
                          },
                          child: SwitchListTile(
                            secondary: const Icon(Icons.account_circle),
                            title: Text(account.screenName ?? L10n.of(context).unknown_username),
                            subtitle: Text(L10n.of(context).home_feed_include_in_for_you),
                            value: enabled,
                            onChanged: (value) async {
                              await filter.setEnabled(account.id, value, accounts: data);
                            },
                          ),
                        );
                      }),
                    ],
                  );
                },
              );
            }
          }),
    );
  }
}
