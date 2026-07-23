import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

List<double> _doubleTapScales = <double>[1.0, 4.0];

class TweetPhoto extends StatefulWidget {
  final String uri;
  final BoxFit fit;
  final String? size;
  final bool pullToClose;
  final bool inPageView;

  const TweetPhoto(
      {super.key,
      required this.uri,
      this.fit = BoxFit.fitWidth,
      required this.size,
      required this.pullToClose,
      required this.inPageView});

  @override
  State<TweetPhoto> createState() => _TweetPhotoState();
}

class _TweetPhotoState extends State<TweetPhoto> with SingleTickerProviderStateMixin {
  Animation<double>? _doubleClickAnimation;
  late void Function() _doubleClickAnimationListener;
  late final AnimationController _doubleClickAnimationController =
      AnimationController(duration: const Duration(milliseconds: 150), vsync: this);

  @override
  void dispose() {
    _doubleClickAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.size != null ? '${widget.uri}:${widget.size}' : widget.uri;

    // Timeline tiles: decode at layout width × DPR. Fullscreen viewer keeps
    // full-res so pinch-zoom stays sharp.
    if (widget.inPageView) {
      return _gestureImage(url, cacheWidth: null);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth;
      final cacheWidth = maxW.isFinite && maxW > 0
          ? (maxW * MediaQuery.devicePixelRatioOf(context)).ceil()
          : null;
      return _gestureImage(url, cacheWidth: cacheWidth);
    });
  }

  Widget _gestureImage(String url, {required int? cacheWidth}) {
    return ExtendedImageSlidePage(
      slideAxis: SlideAxis.vertical,
      child: ExtendedImage.network(
        url,
        cache: true,
        fit: widget.fit,
        cacheWidth: cacheWidth,
        mode: ExtendedImageMode.gesture,
        enableSlideOutPage: widget.pullToClose,
        initGestureConfigHandler: (state) {
          return GestureConfig(
            inPageView: widget.inPageView,
            minScale: 0.9,
            animationMinScale: 0.7,
            maxScale: 4.0,
            animationMaxScale: 4.0,
            speed: 1.0,
            inertialSpeed: 100.0,
            initialScale: 1.0,
            initialAlignment: InitialAlignment.center,
          );
        },
        onDoubleTap: (ExtendedImageGestureState state) {
          final Offset? pointerDownPosition = state.pointerDownPosition;
          final double? begin = state.gestureDetails!.totalScale;
          double end;

          _doubleClickAnimation?.removeListener(_doubleClickAnimationListener);
          _doubleClickAnimationController.stop();
          _doubleClickAnimationController.reset();

          if (begin == _doubleTapScales[0]) {
            end = _doubleTapScales[1];
          } else {
            end = _doubleTapScales[0];
          }

          _doubleClickAnimationListener = () {
            state.handleDoubleTap(scale: _doubleClickAnimation!.value, doubleTapPosition: pointerDownPosition);
          };

          _doubleClickAnimation = _doubleClickAnimationController.drive(Tween<double>(begin: begin, end: end));
          _doubleClickAnimation!.addListener(_doubleClickAnimationListener);
          _doubleClickAnimationController.forward();
        },
      ),
    );
  }
}
