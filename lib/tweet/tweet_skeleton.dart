import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/ui/x_look_theme.dart';

/// Placeholder tiles shown while the first feed page loads.
class TweetFeedSkeleton extends StatelessWidget {
  final int count;

  const TweetFeedSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4),
      itemCount: count,
      itemBuilder: (context, index) => const TweetSkeletonTile(),
    );
  }
}

/// One placeholder post.
///
/// Also used as the footer while the next page loads: the list grows into
/// something post-shaped instead of a centred spinner that appears, animates
/// and is then swapped out, which is what made the timeline stall visibly.
class TweetSkeletonTile extends StatefulWidget {
  const TweetSkeletonTile({super.key});

  @override
  State<TweetSkeletonTile> createState() => _TweetSkeletonTileState();
}

class _TweetSkeletonTileState extends State<TweetSkeletonTile> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  late final CurvedAnimation _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  late final Animation<double> _pulse = _curve.drive(Tween<double>(begin: 0.45, end: 1.0));

  /// The accessibility preference and the platform's own "remove animations"
  /// setting both leave the bones at a flat colour.
  bool get _wantsPulse =>
      !MediaQuery.disableAnimationsOf(context) &&
      PrefService.of(context, listen: false).get<bool>(optionDisableAnimations) != true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_wantsPulse) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = _controller.upperBound;
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = XLookTokens.maybeOf(context);
    final color = tokens?.border ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    final avatarSize = tokens?.avatarSize ?? 40;

    // The bones are laid out once and the whole lot is faded together, so the
    // pulse costs one ticker per tile and no rebuild at all — the inner
    // boundary keeps their painting cached, the outer one keeps the pulse from
    // reaching the list around it.
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _pulse,
        child: RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bone(width: avatarSize, height: avatarSize, radius: avatarSize / 2, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bone(width: 140, height: 12, color: color),
                      const SizedBox(height: 8),
                      _Bone(width: double.infinity, height: 12, color: color),
                      const SizedBox(height: 6),
                      _Bone(width: 220, height: 12, color: color),
                      const SizedBox(height: 12),
                      _Bone(width: double.infinity, height: 120, radius: tokens?.mediaRadius ?? 16, color: color),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Color color;

  const _Bone({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
