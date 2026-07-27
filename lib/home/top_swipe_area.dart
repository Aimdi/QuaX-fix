import 'package:flutter/material.dart';

/// Lets a swipe across the top of the screen change tab.
///
/// The pager under a tab turns a horizontal drag into a page change, but not up
/// here: every home tab draws its own `SliverAppBar` inside a `NestedScrollView`,
/// and a drag starting in that header is claimed by the outer scrollable rather
/// than reaching the pager behind it. So swiping worked in the feed and did
/// nothing on the bar above it — the one place a reader is most likely to try,
/// because their thumb is already there.
///
/// A strip of the screen rather than the bar itself: the bar floats away as the
/// feed scrolls, and "swipe along the top" should not stop meaning anything
/// when it does.
///
/// The strip is translucent, so everything under it — the title, the icons —
/// still takes taps. Only a drag is taken, and only when it goes far or fast
/// enough to be meant.
class TopSwipeArea extends StatefulWidget {
  final Widget child;

  /// Moves this many pages along, clamped by the caller.
  final void Function(int direction) movePage;

  /// Decides whether a finished drag counts, and which way it went. Shared with
  /// the navigation bar so both ends of the screen agree.
  final int Function(double velocity, double distance) directionOf;

  const TopSwipeArea({
    super.key,
    required this.child,
    required this.movePage,
    required this.directionOf,
  });

  @override
  State<TopSwipeArea> createState() => _TopSwipeAreaState();
}

class _TopSwipeAreaState extends State<TopSwipeArea> {
  /// `DragEndDetails` carries velocity but not how far the finger went, so the
  /// distance has to be accumulated as the drag happens.
  double _distance = 0;

  void _end(double velocity) {
    final direction = widget.directionOf(velocity, _distance);
    if (direction != 0) {
      widget.movePage(direction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _distance = 0,
            onHorizontalDragUpdate: (details) => _distance += details.primaryDelta ?? 0,
            onHorizontalDragEnd: (details) => _end(details.primaryVelocity ?? 0),
          ),
        ),
      ],
    );
  }
}
