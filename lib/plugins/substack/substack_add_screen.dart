import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/plugins/substack/substack_models.dart';
import 'package:quax/plugins/substack/substack_store.dart';
import 'package:quax/ui/errors.dart';

class SubstackAddScreen extends StatefulWidget {
  const SubstackAddScreen({super.key});

  @override
  State<SubstackAddScreen> createState() => _SubstackAddScreenState();
}

class _SubstackAddScreenState extends State<SubstackAddScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final addStore = context.read<SubstackAddPublicationStore>();
    final pubs = context.read<SubstackPublicationsStore>();
    try {
      final publication = await addStore.lookup(_controller.text);
      await pubs.add(publication);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      // ScopedBuilder shows the error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final addStore = context.read<SubstackAddPublicationStore>();

    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).plugin_substack_add)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(L10n.of(context).plugin_substack_add_hint),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: L10n.of(context).plugin_substack_add_placeholder,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(L10n.of(context).plugin_substack_follow),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ScopedBuilder<SubstackAddPublicationStore, SubstackPublication?>(
                store: addStore,
                onError: (_, error) => FullPageErrorWidget(
                  error: error,
                  stackTrace: null,
                  prefix: L10n.of(context).plugin_substack_add_error,
                  onRetry: _submit,
                ),
                onLoading: (_) => const Center(child: CircularProgressIndicator()),
                onState: (_, pub) {
                  if (pub == null) return const SizedBox.shrink();
                  return ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(pub.name),
                    subtitle: Text(pub.baseUrl),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
