import 'package:flutter/widgets.dart';

/// How far past its edge an inner tab view must be dragged before the gesture
/// counts as a request to leave it. Small enough to feel responsive, large
/// enough that the elastic wobble at the end of an ordinary swipe is ignored.
const double kEdgeSwipeOverscroll = 32;

/// Lets a horizontally scrollable child hand a swipe *out* to the home page
/// view once it has nothing left to scroll.
///
/// Flutter's gesture arena gives a drag to the innermost scrollable on that
/// axis and never takes it back, so a `TabBarView` filling a tab keeps every
/// horizontal swipe — including the ones made at its last tab, where it has
/// nowhere to go and simply does nothing. That is why swiping the Subscriptions
/// and Search tabs could not change tab at all.
///
/// There is no way to re-enter the arena mid-gesture, so this reads the
/// overscroll the child reports instead: once the child is dragged past its
/// edge by [kEdgeSwipeOverscroll], [onLeave] is called with +1 to move to the
/// next page or -1 for the previous one.
///
/// Fires at most once per gesture — a single drag must not skip two tabs.
class EdgeSwipe extends StatefulWidget {
  final Widget child;

  /// Called with +1 (past the end) or -1 (past the start).
  final void Function(int direction) onLeave;

  const EdgeSwipe({super.key, required this.child, required this.onLeave});

  @override
  State<EdgeSwipe> createState() => _EdgeSwipeState();
}

class _EdgeSwipeState extends State<EdgeSwipe> {
  double _overscroll = 0;
  bool _left = false;

  bool _onNotification(ScrollNotification notification) {
    // depth 0 keeps this to the child's own scrollable: a list *inside* a tab
    // scrolls on the other axis, but its notifications still bubble through.
    if (notification.depth != 0 || notification.metrics.axis != Axis.horizontal) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      _overscroll = 0;
      _left = false;
    } else if (notification is OverscrollNotification && !_left) {
      _overscroll += notification.overscroll;

      if (_overscroll.abs() >= kEdgeSwipeOverscroll) {
        _left = true;
        widget.onLeave(_overscroll > 0 ? 1 : -1);
      }
    }

    // Never absorbed: the child still needs its own notifications.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: widget.child,
    );
  }
}

/// Exposes the home page view's paging to the tabs inside it, so a tab whose
/// own content swallowed a swipe can still ask to move to the next one.
class HomePageSwiper extends InheritedWidget {
  /// Moves [direction] pages from the current one, clamped at both ends.
  final void Function(int direction) movePage;

  const HomePageSwiper({super.key, required this.movePage, required super.child});

  static HomePageSwiper? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomePageSwiper>();

  @override
  bool updateShouldNotify(HomePageSwiper oldWidget) => movePage != oldWidget.movePage;
}

/// Wraps [child] so that dragging it past its edge moves the home page view,
/// when there is one. Outside the home screen it is just [child].
Widget edgeSwipeToChangeHomePage(BuildContext context, Widget child) {
  final swiper = HomePageSwiper.maybeOf(context);
  if (swiper == null) {
    return child;
  }

  return EdgeSwipe(onLeave: swiper.movePage, child: child);
}
