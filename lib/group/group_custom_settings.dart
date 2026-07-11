import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';

/// Full-screen customization for a group's custom feed mode, opened from the
/// filter sheet — a bottom sheet is too cramped for these controls.
class GroupCustomSettingsScreen extends StatelessWidget {
  final GroupModel model;

  const GroupCustomSettingsScreen({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).custom)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ContentFilterBar(model: model),
        ],
      ),
    );
  }
}

/// Three-position content bar: SFW only / default / NSFW only, on a
/// green-to-red gradient track. Keeps its position locally so dragging
/// responds instantly, and persists the choice through the group model.
class ContentFilterBar extends StatefulWidget {
  final GroupModel model;

  const ContentFilterBar({super.key, required this.model});

  @override
  State<ContentFilterBar> createState() => _ContentFilterBarState();
}

class _ContentFilterBarState extends State<ContentFilterBar> {
  static const _positions = [contentFilterSfw, contentFilterDefault, contentFilterNsfw];
  static const _thumbColors = [Colors.green, Colors.orange, Colors.red];

  late int _position;

  @override
  void initState() {
    super.initState();
    _position = _positions.indexOf(widget.model.state.contentFilter).clamp(0, 2);
  }

  Widget _positionLabel(String text, int position) {
    final selected = _position == position;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? _thumbColors[position] : Theme.of(context).hintColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(L10n.of(context).content_filter, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: const LinearGradient(
                      colors: [Colors.green, Colors.yellow, Colors.orange, Colors.red],
                    ),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 10,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  activeTickMarkColor: Colors.white70,
                  inactiveTickMarkColor: Colors.white70,
                  thumbColor: _thumbColors[_position],
                  overlayColor: _thumbColors[_position].withAlpha(50),
                ),
                child: Slider(
                  value: _position.toDouble(),
                  max: 2,
                  divisions: 2,
                  onChanged: (value) {
                    final position = value.round();
                    if (position == _position) {
                      return;
                    }
                    setState(() {
                      _position = position;
                    });
                    widget.model.setSubscriptionGroupContentFilter(_positions[position]);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _positionLabel(L10n.of(context).content_filter_sfw, 0),
              _positionLabel(L10n.of(context).content_filter_default, 1),
              _positionLabel(L10n.of(context).content_filter_nsfw, 2),
            ],
          ),
        ),
      ],
    );
  }
}
