import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:xta/generated/l10n.dart';
import 'package:xta/plugins/substack/substack_add_screen.dart';
import 'package:xta/plugins/substack/substack_archive_screen.dart';
import 'package:xta/plugins/substack/substack_models.dart';
import 'package:xta/plugins/substack/substack_note_card.dart';
import 'package:xta/plugins/substack/substack_post_card.dart';
import 'package:xta/plugins/substack/substack_store.dart';
import 'package:xta/ui/errors.dart';

class SubstackScreen extends StatefulWidget {
  final ScrollController scrollController;

  const SubstackScreen({super.key, required this.scrollController});

  @override
  State<SubstackScreen> createState() => _SubstackScreenState();
}

class _SubstackScreenState extends State<SubstackScreen> {
  var _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pubs = context.read<SubstackPublicationsStore>();
      final feed = context.read<SubstackFeedStore>();
      final read = context.read<SubstackReadStore>();
      final notes = context.read<SubstackNotesStore>();
      await pubs.load();
      await read.load();
      feed.syncReadIds(read.state);
      await feed.refresh();
      await notes.refresh();
    });
  }

  Future<void> _openAdd() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SubstackAddScreen()),
    );
    if (added == true && mounted) {
      await context.read<SubstackFeedStore>().refresh();
    }
  }

  void _setFilter(SubstackFeedFilter filter) {
    final read = context.read<SubstackReadStore>().state;
    context.read<SubstackFeedStore>().setFilter(filter, read);
  }

  @override
  Widget build(BuildContext context) {
    final pubs = context.read<SubstackPublicationsStore>();
    final feed = context.read<SubstackFeedStore>();
    final notes = context.read<SubstackNotesStore>();
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.plugin_substack_title),
        actions: [
          IconButton(
            tooltip: l10n.plugin_substack_add,
            icon: const Icon(Icons.add),
            onPressed: _openAdd,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l10n.plugin_substack_tab_posts), icon: const Icon(Icons.article_outlined)),
                ButtonSegment(value: 1, label: Text(l10n.plugin_substack_tab_notes), icon: const Icon(Icons.notes_outlined)),
              ],
              selected: {_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
          ),
          Expanded(
            child: _tab == 0
                ? _PostsPane(
                    scrollController: widget.scrollController,
                    pubs: pubs,
                    feed: feed,
                    onAdd: _openAdd,
                    onFilter: _setFilter,
                  )
                : _NotesPane(scrollController: widget.scrollController, notes: notes),
          ),
        ],
      ),
    );
  }
}

class _PostsPane extends StatelessWidget {
  final ScrollController scrollController;
  final SubstackPublicationsStore pubs;
  final SubstackFeedStore feed;
  final Future<void> Function() onAdd;
  final void Function(SubstackFeedFilter) onFilter;

  const _PostsPane({
    required this.scrollController,
    required this.pubs,
    required this.feed,
    required this.onAdd,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await pubs.load();
        await feed.refresh();
      },
      child: ScopedBuilder<SubstackPublicationsStore, List<SubstackPublication>>(
        store: pubs,
        onError: (_, error) => FullPageErrorWidget(
          error: error,
          stackTrace: null,
          prefix: L10n.of(context).plugin_substack_load_error,
          onRetry: pubs.load,
        ),
        onLoading: (_) => const Center(child: CircularProgressIndicator()),
        onState: (context, publications) {
          if (publications.isEmpty) {
            return ListView(
              controller: scrollController,
              children: [
                const SizedBox(height: 80),
                Icon(Icons.newspaper_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    L10n.of(context).plugin_substack_empty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    L10n.of(context).plugin_substack_empty_description,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: Text(L10n.of(context).plugin_substack_add),
                  ),
                ),
              ],
            );
          }

          return ScopedBuilder<SubstackFeedStore, SubstackFeedSnapshot>(
            store: feed,
            onError: (_, error) => FullPageErrorWidget(
              error: error,
              stackTrace: null,
              prefix: L10n.of(context).plugin_substack_load_error,
              onRetry: feed.refresh,
            ),
            onLoading: (_) => const Center(child: CircularProgressIndicator()),
            onState: (context, snapshot) {
              final children = <Widget>[
                _FollowedStrip(
                  publications: publications,
                  onOpen: (pub) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SubstackArchiveScreen(publication: pub)),
                    );
                  },
                  onRemove: (id) async {
                    await pubs.remove(id);
                    await feed.refresh();
                  },
                ),
                _FilterBar(selected: feed.filter, onSelected: onFilter),
              ];

              if (snapshot.failedCount > 0) {
                children.add(
                  ListTile(
                    leading: Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error),
                    title: Text(L10n.of(context).plugin_substack_partial_error(snapshot.failedCount)),
                  ),
                );
              }

              if (snapshot.posts.isEmpty) {
                children.addAll([
                  const SizedBox(height: 48),
                  Center(child: Text(L10n.of(context).plugin_substack_feed_empty)),
                ]);
                return ListView(controller: scrollController, children: children);
              }

              return ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: 1 + snapshot.posts.length + (snapshot.canLoadMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox.shrink(),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(mainAxisSize: MainAxisSize.min, children: children);
                  }
                  final postIndex = index - 1;
                  if (postIndex < snapshot.posts.length) {
                    return SubstackPostCard(post: snapshot.posts[postIndex], showSourceBadge: false);
                  }
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: OutlinedButton(
                        onPressed: feed.loadMore,
                        child: Text(L10n.of(context).plugin_substack_load_more),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final SubstackFeedFilter selected;
  final void Function(SubstackFeedFilter) onSelected;

  const _FilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final labels = {
      SubstackFeedFilter.all: l10n.plugin_substack_filter_all,
      SubstackFeedFilter.unread: l10n.plugin_substack_filter_unread,
      SubstackFeedFilter.free: l10n.plugin_substack_filter_free,
      SubstackFeedFilter.podcast: l10n.plugin_substack_filter_podcast,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          for (final filter in SubstackFeedFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labels[filter]!),
                selected: selected == filter,
                onSelected: (_) => onSelected(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotesPane extends StatelessWidget {
  final ScrollController scrollController;
  final SubstackNotesStore notes;

  const _NotesPane({required this.scrollController, required this.notes});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return RefreshIndicator(
      onRefresh: notes.refresh,
      child: ScopedBuilder<SubstackNotesStore, SubstackNotesPage>(
        store: notes,
        onError: (_, error) => FullPageErrorWidget(
          error: error,
          stackTrace: null,
          prefix: l10n.plugin_substack_load_error,
          onRetry: notes.refresh,
        ),
        onLoading: (_) => const Center(child: CircularProgressIndicator()),
        onState: (context, page) {
          if (page.notes.isEmpty) {
            return ListView(
              controller: scrollController,
              children: [
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(l10n.plugin_substack_notes_empty, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(l10n.plugin_substack_notes_intro, textAlign: TextAlign.center),
                ),
              ],
            );
          }

          return ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            itemCount: page.notes.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(l10n.plugin_substack_notes_intro, style: Theme.of(context).textTheme.bodySmall),
                );
              }
              final noteIndex = index - 1;
              if (noteIndex < page.notes.length) {
                return SubstackNoteCard(note: page.notes[noteIndex]);
              }
              if (page.nextCursor == null || page.nextCursor!.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: OutlinedButton(
                    onPressed: notes.loadMore,
                    child: Text(l10n.plugin_substack_load_more),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FollowedStrip extends StatelessWidget {
  final List<SubstackPublication> publications;
  final Future<void> Function(String id) onRemove;
  final void Function(SubstackPublication publication) onOpen;

  const _FollowedStrip({
    required this.publications,
    required this.onRemove,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: publications.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pub = publications[index];
          return InputChip(
            avatar: pub.logoUrl == null
                ? const Icon(Icons.newspaper, size: 18)
                : ClipOval(
                    child: ExtendedImage.network(pub.logoUrl!, width: 24, height: 24, fit: BoxFit.cover),
                  ),
            label: Text(pub.name),
            onPressed: () => onOpen(pub),
            onDeleted: () => onRemove(pub.id),
            deleteIcon: const Icon(Icons.close, size: 16),
            deleteButtonTooltipMessage: L10n.of(context).plugin_substack_unfollow,
          );
        },
      ),
    );
  }
}
