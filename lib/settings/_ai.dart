import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';

/// Where an AI feature should send its requests, if the reader wants one.
///
/// Nothing calls this yet — it is the connection details, kept on the device,
/// so that features built on top of it never have to ship a key of QuaX's own
/// or route a reader's posts through a service they did not choose.
class SettingsAiFragment extends StatefulWidget {
  const SettingsAiFragment({super.key});

  @override
  State<SettingsAiFragment> createState() => _SettingsAiFragmentState();
}

class _SettingsAiFragmentState extends State<SettingsAiFragment> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _keyController;
  late final TextEditingController _modelController;
  var _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final prefs = PrefService.of(context, listen: false);
    _baseUrlController = TextEditingController(text: prefs.get<String>(optionAiBaseUrl) ?? '');
    _keyController = TextEditingController(text: prefs.get<String>(optionAiApiKey) ?? '');
    _modelController = TextEditingController(text: prefs.get<String>(optionAiModel) ?? '');
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = PrefService.of(context, listen: false);
    await prefs.set(optionAiBaseUrl, _baseUrlController.text.trim());
    await prefs.set(optionAiApiKey, _keyController.text.trim());
    await prefs.set(optionAiModel, _modelController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.of(context).ai_saved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ai_provider)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.ai_provider_description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          TextField(
            controller: _baseUrlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.ai_base_url,
              hintText: 'https://api.openai.com/v1',
              helperText: l10n.ai_base_url_description,
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyController,
            obscureText: _obscureKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.ai_api_key,
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _modelController,
            autocorrect: false,
            decoration: InputDecoration(labelText: l10n.ai_model, hintText: 'gpt-4o-mini'),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
    );
  }
}
