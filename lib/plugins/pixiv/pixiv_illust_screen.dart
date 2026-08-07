import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/pixiv/pixiv_client.dart';
import 'package:xta/plugins/pixiv/pixiv_grid.dart';
import 'package:xta/plugins/pixiv/pixiv_models.dart';
import 'package:xta/plugins/pixiv/pixiv_search_screen.dart';
import 'package:xta/plugins/pixiv/pixiv_settings.dart';
import 'package:xta/plugins/pixiv/pixiv_user_screen.dart';
import 'package:xta/subscriptions/widgets/fallback_avatar.dart';
import 'package:xta/ui/dates.dart';
import 'package:xta/ui/errors.dart';
import 'package:xta/utils/urls.dart';

final NumberFormat _pixivDetailCount = NumberFormat.compact(locale: 'en_US');

/// In-app illust viewer — pages, caption, tags, stats, related works (Pixez-like).
class PixivIllustScreen extends StatefulWidget {
  final PixivIllust illust;

  const PixivIllustScreen({super.key, required this.illust});

  @override
  State<PixivIllustScreen> createState() => _PixivIllustScreenState();
}

class _PixivIllustScreenState extends State<PixivIllustScreen> {
  late PixivIllust _illust = widget.illust;
  List<PixivIllust> _related = const [];
  Object? _error;
  var _loadingDetail = true;
  var _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadingDetail = true;
      _error = null;
    });

    final client = context.read<PixivClient>();
    try {
      final detail = await client.illustDetail(_illust.id);
      final related = await client.related(_illust.id);
      if (!mounted) return;
      setState(() {
        _illust = detail;
        _related = related.illusts;
        _loadingDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Seed artwork stays visible; related/detail enrichment is best-effort.
      setState(() {
        _error = e;
        _loadingDetail = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final pages = _illust.viewerUrls;

    return Scaffold(
      appBar: AppBar(
        title: Text(_illust.title.isEmpty ? l10n.plugin_pixiv_title : _illust.title),
        actions: [
          IconButton(
            tooltip: l10n.plugin_pixiv_open_on_pixiv,
            onPressed: () => openUri(context, _illust.url),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _viewer(pages)),
            if (pages.length > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    l10n.plugin_pixiv_page_of(_pageIndex + 1, pages.length),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            SliverToBoxAdapter(child: _meta(context)),
            if (_loadingDetail)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null && _related.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FullPageErrorWidget(
                    error: _error,
                    stackTrace: null,
                    prefix: pixivErrorMessage(l10n, _error!),
                    onRetry: _load,
                  ),
                ),
              ),
            if (_related.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    l10n.plugin_pixiv_related,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => PixivIllustTile(illust: _related[index]),
                    childCount: _related.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _viewer(List<String> pages) {
    final height = MediaQuery.sizeOf(context).height * 0.55;
    return SizedBox(
      height: height,
      child: PageView.builder(
        itemCount: pages.length,
        onPageChanged: (i) => setState(() => _pageIndex = i),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: ExtendedImage.network(
                pages[index],
                fit: BoxFit.contain,
                headers: pixivImageHeaders,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _meta(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final avatar = _illust.userAvatarUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PixivUserScreen(userId: _illust.userId)),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: avatar == null
                      ? FallbackAvatar(
                          seed: '${_illust.userId}',
                          displayName: _illust.userName,
                          size: 40,
                          accent: theme.colorScheme.primary,
                        )
                      : ExtendedImage.network(
                          avatar,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          headers: pixivImageHeaders,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_illust.userName, style: theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
                      Text('@${_illust.userAccount}', style: theme.textTheme.bodySmall!.copyWith(color: muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_illust.title.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(_illust.title, style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _stat(Icons.favorite, _pixivDetailCount.format(_illust.totalBookmarks)),
              _stat(Icons.visibility_outlined, _pixivDetailCount.format(_illust.totalViews)),
              if (_illust.createdAt != null)
                Text(createCompactDate(_illust.createdAt!), style: theme.textTheme.bodySmall!.copyWith(color: muted)),
              if (_illust.isR18)
                Text(l10n.plugin_pixiv_r18, style: theme.textTheme.labelMedium!.copyWith(color: theme.colorScheme.error)),
            ],
          ),
          if (_illust.caption.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_illust.caption, style: theme.textTheme.bodyMedium!.copyWith(height: 1.35)),
          ],
          if (_illust.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in _illust.tags)
                  ActionChip(
                    label: Text('#${tag.displayName}'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PixivSearchScreen(initialQuery: tag.name)),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: muted)),
      ],
    );
  }
}
