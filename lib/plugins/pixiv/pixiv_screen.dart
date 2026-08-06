import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:xta/constants.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/pixiv/pixiv_illust_card.dart';
import 'package:xta/plugins/pixiv/pixiv_models.dart';
import 'package:xta/plugins/pixiv/pixiv_settings.dart';
import 'package:xta/plugins/pixiv/pixiv_store.dart';
import 'package:xta/ui/errors.dart';

/// Pixiv following feed (requires a refresh token in settings).
class PixivScreen extends StatefulWidget {
  final ScrollController scrollController;

  const PixivScreen({super.key, required this.scrollController});

  @override
  State<PixivScreen> createState() => _PixivScreenState();
}

class _PixivScreenState extends State<PixivScreen> {
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PixivFeedStore>().refresh();
      }
    });
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final c = widget.scrollController;
    if (!c.hasClients) return;
    if (c.position.pixels > c.position.maxScrollExtent - 400) {
      context.read<PixivFeedStore>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final prefs = PrefService.of(context);
    final hasToken = (prefs.get<String>(optionPluginPixivRefreshToken) ?? '').trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_pixiv_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () async {
              final feed = context.read<PixivFeedStore>();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PixivSettingsScreen()),
              );
              if (mounted) {
                await feed.refresh();
              }
            },
          ),
        ],
      ),
      body: !hasToken
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.plugin_pixiv_not_configured, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _signingIn
                          ? null
                          : () async {
                              setState(() => _signingIn = true);
                              try {
                                final feed = context.read<PixivFeedStore>();
                                await runPixivSignIn(context);
                                if (mounted) {
                                  setState(() {});
                                  await feed.refresh();
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _signingIn = false);
                                }
                              }
                            },
                      child: _signingIn
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l10n.plugin_pixiv_sign_in),
                    ),
                  ],
                ),
              ),
            )
          : ScopedBuilder<PixivFeedStore, List<PixivIllust>>.transition(
              store: context.read<PixivFeedStore>(),
              onLoading: (_) => const Center(child: CircularProgressIndicator()),
              onError: (context, error) => Padding(
                padding: const EdgeInsets.all(24),
                child: FullPageErrorWidget(
                  error: error,
                  stackTrace: null,
                  prefix: pixivErrorMessage(l10n, error ?? Exception()),
                  onRetry: () => context.read<PixivFeedStore>().refresh(),
                ),
              ),
              onState: (context, illusts) {
                if (illusts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l10n.plugin_pixiv_empty, textAlign: TextAlign.center),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => context.read<PixivFeedStore>().refresh(),
                  child: ListView.builder(
                    controller: widget.scrollController,
                    itemCount: illusts.length,
                    itemBuilder: (context, index) =>
                        PixivIllustCard(key: ValueKey(illusts[index].id), illust: illusts[index]),
                  ),
                );
              },
            ),
    );
  }
}
