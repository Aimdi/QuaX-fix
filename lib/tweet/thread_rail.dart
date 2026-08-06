import 'package:flutter/material.dart';

/// Shared thread-rail geometry (feed thread bodies and status reply nesting).
const double kThreadRailLeft = 16;
const double kThreadRailTopGap = 10;
const double kThreadRailAvatarSize = 48;
const double kThreadRailLineWidth = 2;
const double kThreadLevelWidth = 40;

const int kThreadMaxVisualDepth = 2;

double get threadRailLineX => kThreadRailLeft + kThreadRailAvatarSize / 2 - kThreadRailLineWidth / 2;

double get threadRailAvatarCenterY => kThreadRailTopGap + kThreadRailAvatarSize / 2;

double get threadRailBodyIndent => kThreadRailLeft + kThreadRailAvatarSize;

/// Vertical connector segments aligned through the avatar column.
class ThreadRailLines extends StatelessWidget {
  final bool connectTop;
  final bool connectBottom;
  final Color? lineColor;

  const ThreadRailLines({
    super.key,
    required this.connectTop,
    required this.connectBottom,
    this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!connectTop && !connectBottom) {
      return const SizedBox.shrink();
    }
    final color = lineColor ?? Theme.of(context).colorScheme.outlineVariant;
    Widget lineSeg() => Container(width: kThreadRailLineWidth, color: color);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (connectTop)
          Positioned(left: threadRailLineX, top: 0, height: threadRailAvatarCenterY, child: lineSeg()),
        if (connectBottom)
          Positioned(left: threadRailLineX, top: threadRailAvatarCenterY, bottom: 0, child: lineSeg()),
      ],
    );
  }
}

/// Feed-style thread body: avatar column, optional rail, header and body.
class ThreadRailBody extends StatelessWidget {
  final bool connectTop;
  final bool connectBottom;
  final bool indentBody;
  final Widget avatar;
  final Widget header;
  final List<Widget> bodyChildren;
  final VoidCallback onTapProfile;

  const ThreadRailBody({
    super.key,
    required this.connectTop,
    required this.connectBottom,
    required this.indentBody,
    required this.avatar,
    required this.header,
    required this.bodyChildren,
    required this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ThreadRailLines(connectTop: connectTop, connectBottom: connectBottom),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: kThreadRailLeft),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: kThreadRailTopGap),
                    SizedBox(
                      width: kThreadRailAvatarSize,
                      height: kThreadRailAvatarSize,
                      child: GestureDetector(
                          behavior: HitTestBehavior.opaque, onTap: onTapProfile, child: avatar),
                    ),
                  ],
                ),
                Expanded(child: header),
              ],
            ),
            if (indentBody)
              Padding(
                padding: EdgeInsets.only(left: threadRailBodyIndent),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: bodyChildren),
              ),
            if (!indentBody) ...bodyChildren,
          ],
        ),
      ],
    );
  }
}
