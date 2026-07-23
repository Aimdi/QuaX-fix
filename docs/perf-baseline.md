# Performance baseline (Phase 1)

Captured before the Phase 2 tweet/perf + Phase 3 X-look theme work.
Without a baseline you cannot prove "smoother."

## Environment notes

| Item | Value |
|---|---|
| App version | 4.12.0+400001040 |
| Flutter (FVM) | 3.44.4 |
| Date | 2026-07-23 |
| Host | Cursor Cloud Linux VM (no `/dev/kvm`, no physical device) |

**Device scroll / cold-start traces cannot run in this VM** (Android-only app,
no emulator acceleration, no attached phone). Numbers that need a mid-range
phone are marked **TBD — device**. Re-run those locally with:

```bash
fvm flutter run --profile --trace-startup
# DevTools timeline: 10s scroll through ~200 posts (16 ms/frame budget)
fvm flutter build apk --analyze-size
```

## Cold start (`--profile --trace-startup`)

| Metric | Baseline | After Phase 2 |
|---|---|---|
| Time to first frame | TBD — device | |
| Time to first meaningful feed paint | TBD — device | |

## Scroll jank (feed of ~200 posts, 10 s)

| Metric | Baseline | After Phase 2 |
|---|---|---|
| Dropped frames | TBD — device | |
| Frames over 16 ms | TBD — device | |

## APK size

Recorded on this VM after a clean debug build (see Phase 0 gate):

| Artifact | Baseline bytes | Notes |
|---|---|---|
| `app-debug.apk` | _(filled after first clean build on this branch)_ | debug; release size tracked separately on device CI |
| `--analyze-size` summary | TBD — device / local | prefer release / profile for fair comparison |

## Prior hot-path work already on mainline

These landed before this baseline doc and are **not** double-counted as Phase 2 wins:

- Memoized `tweetCardColor` / footer tint (`9dc41c4`)
- Avatar `cacheWidth` decode cap (`9dc41c4`)
- Reverted feed `cacheExtent` bump — GIF tiles spin native players on build (`d66b60b`)

## Phase 2 targets (tweet module)

1. Cap timeline photo decode via `extended_image` `cacheWidth` (not fullscreen).
2. `RepaintBoundary` around media / shimmer / skeleton.
3. Keep `ListView.builder` / `PagedListView`; do **not** raise `cacheExtent` until video creation is visibility-gated.
4. Skeleton first-page indicator (perceived speed).
5. Prefer `const` on eligible tweet chrome widgets.

## Gate

Phase 4 compares the same phone + same flows as the TBD device rows above.
Requirement: fewer dropped frames, cold start not worse, APK not materially bigger.
If a module does not improve → revert that worktree.
