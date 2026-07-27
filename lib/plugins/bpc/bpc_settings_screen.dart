import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/bpc/bpc_domains.dart';
import 'package:quax/plugins/bpc/bpc_strategy.dart';
import 'package:quax/utils/urls.dart';

/// Lets the user pick how paywalled links are opened.
class BpcSettingsScreen extends StatefulWidget {
  const BpcSettingsScreen({super.key});

  @override
  State<BpcSettingsScreen> createState() => _BpcSettingsScreenState();
}

class _BpcSettingsScreenState extends State<BpcSettingsScreen> {
  Future<void> _setStrategy(BpcStrategy value) async {
    final prefs = PrefService.of(context);
    await prefs.set(optionPluginBpcStrategy, bpcStrategyPrefValue(value));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final prefs = PrefService.of(context);
    final strategy = parseBpcStrategy(prefs.get(optionPluginBpcStrategy));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.plugin_bpc_title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            title: Text(l10n.plugin_bpc_sites_count(bpcSupportedDomains.length)),
            subtitle: Text(l10n.plugin_bpc_sites_count_description),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(l10n.plugin_bpc_strategy, style: Theme.of(context).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.plugin_bpc_strategy_description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          RadioListTile<BpcStrategy>(
            value: BpcStrategy.archive,
            groupValue: strategy,
            onChanged: (v) => _setStrategy(v!),
            title: Text(l10n.plugin_bpc_strategy_archive),
            subtitle: Text(l10n.plugin_bpc_strategy_archive_description),
          ),
          RadioListTile<BpcStrategy>(
            value: BpcStrategy.twelveFt,
            groupValue: strategy,
            onChanged: (v) => _setStrategy(v!),
            title: Text(l10n.plugin_bpc_strategy_twelve_ft),
            subtitle: Text(l10n.plugin_bpc_strategy_twelve_ft_description),
          ),
          RadioListTile<BpcStrategy>(
            value: BpcStrategy.googlebot,
            groupValue: strategy,
            onChanged: (v) => _setStrategy(v!),
            title: Text(l10n.plugin_bpc_strategy_googlebot),
            subtitle: Text(l10n.plugin_bpc_strategy_googlebot_description),
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.plugin_bpc_about),
            subtitle: Text(l10n.plugin_bpc_about_description),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => openUri(context, 'https://gitflic.ru/project/magnolia1234/bypass-paywalls-chrome-clean'),
          ),
        ],
      ),
    );
  }
}
