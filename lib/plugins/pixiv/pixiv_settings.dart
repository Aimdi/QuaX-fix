import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/pixiv/pixiv_client.dart';

String pixivErrorMessage(L10n l10n, Object error) {
  if (error is! PixivException) {
    return l10n.plugin_pixiv_error_network;
  }
  return switch (error.kind) {
    PixivErrorKind.notConfigured => l10n.plugin_pixiv_not_configured,
    PixivErrorKind.network => l10n.plugin_pixiv_error_network,
    PixivErrorKind.unauthorized => l10n.plugin_pixiv_error_unauthorized,
    PixivErrorKind.rateLimited => l10n.plugin_pixiv_error_rate_limited,
    PixivErrorKind.notFound => l10n.plugin_pixiv_error_not_found,
    PixivErrorKind.badResponse => l10n.plugin_pixiv_error_response,
  };
}

/// Refresh token and content filters for the private Pixiv plugin.
class PixivSettingsScreen extends StatefulWidget {
  const PixivSettingsScreen({super.key});

  @override
  State<PixivSettingsScreen> createState() => _PixivSettingsScreenState();
}

class _PixivSettingsScreenState extends State<PixivSettingsScreen> {
  late final TextEditingController _token;
  bool _hidden = true;
  bool _testing = false;
  late bool _showR18;

  @override
  void initState() {
    super.initState();
    final prefs = PrefService.of(context, listen: false);
    _token = TextEditingController(text: prefs.get<String>(optionPluginPixivRefreshToken) ?? '');
    _showR18 = prefs.get<bool>(optionPluginPixivShowR18) == true;
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _saveToken() async {
    final prefs = PrefService.of(context, listen: false);
    await prefs.set(optionPluginPixivRefreshToken, _token.text.trim());
    // Force a fresh access token on the next call.
    await prefs.set(optionPluginPixivAccessToken, '');
    await prefs.set(optionPluginPixivAccessExpiresAt, '');
  }

  Future<void> _test() async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final client = context.read<PixivClient>();

    await _saveToken();
    setState(() => _testing = true);
    String message;
    try {
      final user = await client.verify();
      message = l10n.plugin_pixiv_test_ok(user.name.isEmpty ? user.account : user.name);
    } catch (e) {
      message = pixivErrorMessage(l10n, e);
    }

    if (mounted) {
      setState(() => _testing = false);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final prefs = PrefService.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.plugin_pixiv_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.plugin_pixiv_settings_intro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(l10n.plugin_pixiv_refresh_token, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _token,
            obscureText: _hidden,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: l10n.plugin_pixiv_refresh_token_hint,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            ),
            onChanged: (_) => _saveToken(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: _testing ? null : _test,
              child: _testing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.plugin_pixiv_test),
            ),
          ),
          const SizedBox(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.plugin_pixiv_show_r18),
            subtitle: Text(l10n.plugin_pixiv_show_r18_description),
            value: _showR18,
            onChanged: (value) async {
              await prefs.set(optionPluginPixivShowR18, value);
              setState(() => _showR18 = value);
            },
          ),
        ],
      ),
    );
  }
}
