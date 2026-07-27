import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/utils/browsers.dart';

/// Which browser a link leaves the app for.
///
/// The system default is whatever Android was last told, for everything. A
/// reader who keeps a separate browser for links off a feed — a hardened one, a
/// throwaway profile — had no way to say so without changing that default for
/// every app on the phone.
///
/// Only useful when links are not being opened in the app, so it is disabled
/// rather than hidden while they are: hiding it would leave no clue the choice
/// exists.
class BrowserPickerTile extends StatefulWidget {
  const BrowserPickerTile({super.key});

  @override
  State<BrowserPickerTile> createState() => _BrowserPickerTileState();
}

class _BrowserPickerTileState extends State<BrowserPickerTile> {
  List<InstalledBrowser>? _browsers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final browsers = await installedBrowsers();
    if (mounted) {
      setState(() => _browsers = browsers);
    }
  }

  /// The stored choice, or null when it names a browser that is no longer
  /// installed — in which case the tile should say "system default", which is
  /// what would actually happen.
  String? _selected(BasePrefService prefs, List<InstalledBrowser> browsers) {
    final stored = prefs.get<String>(optionExternalBrowser) ?? systemDefaultBrowser;
    if (stored.isEmpty || !browsers.any((b) => b.package == stored)) {
      return null;
    }
    return stored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final prefs = PrefService.of(context);
    final browsers = _browsers;
    final enabled = prefs.get(optionOpenLinksInEmbeddedBrowser) != true;

    if (browsers == null || browsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListTile(
      enabled: enabled,
      title: Text(l10n.option_external_browser_label),
      subtitle: Text(l10n.option_external_browser_description),
      trailing: DropdownButton<String?>(
        value: _selected(prefs, browsers),
        onChanged: enabled
            ? (value) async {
                await prefs.set(optionExternalBrowser, value ?? systemDefaultBrowser);
                if (mounted) setState(() {});
              }
            : null,
        items: [
          DropdownMenuItem(value: null, child: Text(l10n.option_external_browser_system)),
          for (final browser in browsers)
            DropdownMenuItem(
              value: browser.package,
              child: Text(browser.label, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}
