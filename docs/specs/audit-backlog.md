# Audit backlog

What six audits of this codebase turned up, what has been done, and what has
not. Anchors are `file.dart:line` at the time of writing — re-grep rather than
trusting them after a refactor.

Everything here was found by reading, not by running: there is no Flutter
toolchain in the cloud VM (see `AGENTS.md`), so nothing below was profiled. The
"measurable win" claims are mechanism arguments, and a real baseline
(`docs/perf-baseline.md`, still TBD on device) would be worth more than any of
them.

## Done

Render and rebuild cost: tile keys at every chain-list site, memoized text
truncation, footer label measurement cache, unified-card decode out of
`build()`, single-image posts no longer building a `PageView`, one skeleton
ticker per tile, `ScopedBuilder` leaves instead of `Consumer` over a plain
`Provider`.

Startup: the stored chunk reads take a `LIMIT`, the migration purge runs once
rather than twice, libmpv and the plugin fleet are no longer constructed before
the first frame, `Logger.root.level` is set, the X transaction key is warmed
alongside startup.

Requests: pull-to-refresh deletes only the refreshed group's rows, the follow
import resolves its user id once, Substack and Reddit are fetched concurrently
and skipped when their plugin is off, search queries the visible tab only, a
reorder no longer drops every cached feed, the media lookahead is capped on the
group fan-out, profiles are cached for five minutes.

Correctness found along the way: the media frame was unbounded and reached
through `sizes!.large!`; every account row shared one `Dismissible` key; a
failing migration returned an `Object` from a `Future<bool>`; saved and liked
membership was empty until the Saved tab was first opened; a group's mute list
only applied when it happened to be sorted by Custom.

Backup covered 8 of 18 tables; it now covers 14, with a format version.

## Not done — worth doing

**Bound the feed fan-out.** `lib/group/_feed.dart` builds one future per chunk
and `Future.wait`s them, so 200 follows opens 13 simultaneous searches on one
mobile link, and up to 65 requests once gap-fill triggers. Cancellation is in;
bounding is not, because it means turning the eagerly-created futures into
thunks and running them through a pool — a real restructuring of a 90-line
method, which is not something to do without a compiler. Passing `limit: 40` to
`Twitter.searchTweets` (the parameter exists, defaulting to 20) would also cut
the number of gap-fill pages needed.

**One Reddit store instead of three fetches.** `reddit_interleaved.dart`, the
For You feed and `RedditFeedStore` each fetch overlapping subreddit sets with no
shared cache, so Following → For You re-downloads the same listings. On the
anonymous path each subreddit is an old.reddit HTML scrape, up to four requests.

**Icon tree-shaking.** Group icons are deserialized at runtime
(`group_model.dart:19-31`), so `--no-tree-shake-icons` is on in all four
workflows and the full `MaterialIcons-Regular.otf` (~1.5-1.7 MB) ships. A
curated `const IconData` set would let it come off; stored icons already fall
back through `deserializeIconData`. Needs a product decision about which icons
a reader may pick.

**`timeline_cache` has no cap and no `created_at` index** (frozen; needs
migration 43, and `test/database_indexes_test.dart` asserts exact index-set
equality so it must change in the same commit). Same for
`feed_group_chunk` — the 7-day purge that bounds it is itself a full scan.

**`FeedSessionCache` retains a whole feed per visited group** with no bound and
no disposal (`feed_session_cache.dart`). `VideoControllerPool(maxSize: 5)` is
the pattern to copy.

**Feed tiles are `SelectableText`**, i.e. an `EditableText` per post: a focus
node, a text controller, a scroll controller and a `RenderEditable` each. Making
selection opt-in on the status screen only is a behaviour change, so it needs a
decision rather than a patch.

**Timeline thumbnails run the gesture/zoom image stack** (`_photo.dart:56-64`)
even in a feed tile, where the tap that opens fullscreen is handled a level up.

## Not done — UX

The account list still has no swipe background, no confirmation and no undo on
the one action that can leave the app unable to fetch anything. The first-run
dialog claims the app "doesn't work without an X account", which `transport.dart`
contradicts — a guest request is attempted first — and the explanation of why
accounts are needed only appears after the reader has committed to logging in;
it also still says accounts are picked "randomly", which stopped being true when
selection became health-based. A rate limit and broken auth are visually
indistinguishable. The drawer in `home_screen.dart:283` is unreachable:
`openDrawer` has zero call sites. `optionWizardCompleted` and
`SettingsScreen.initialPage` are both declared and never read.

## Considered and rejected

Anything that writes to X. Any telemetry, including opt-in aggregated
endpoint-failure reports. Scraper-based plugins (Instagram, TikTok, Threads).
`placeInterleaved`'s bucket allocation, which looks like a wasted `List.generate`
but is required by its contract.
