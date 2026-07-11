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
  static const _colors = [Colors.green, Colors.orange, Colors.red];

  late int _position;

  @override
  void initState() {
    super.initState();
    _position = _positions.indexOf(widget.model.state.contentFilter).clamp(0, 2);
  }

  void _setPosition(int position) {
    if (position == _position) {
      return;
    }
    setState(() {
      _position = position;
    });
    widget.model.setSubscriptionGroupContentFilter(_positions[position]);
  }

  Widget _positionChip(String text, int position) {
    final selected = _position == position;
    final color = _colors[position];

    return GestureDetector(
      onTap: () => _setPosition(position),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? color.withAlpha(40) : Colors.transparent,
          border: Border.all(color: selected ? color : Theme.of(context).dividerColor),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? color : Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTrack(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: const LinearGradient(
                  colors: [Colors.green, Colors.yellow, Colors.orange, Colors.red],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _colors[_position].withAlpha(90),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 14,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              activeTickMarkColor: Colors.white70,
              inactiveTickMarkColor: Colors.white70,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14, elevation: 4),
              thumbColor: Colors.white,
              overlayColor: _colors[_position].withAlpha(50),
            ),
            child: Slider(
              value: _position.toDouble(),
              max: 2,
              divisions: 2,
              onChanged: (value) => _setPosition(value.round()),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt_outlined, size: 20, color: _colors[_position]),
                const SizedBox(width: 8),
                Text(L10n.of(context).content_filter, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              L10n.of(context).content_filter_description,
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildTrack(context),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _positionChip(L10n.of(context).content_filter_sfw, 0),
                _positionChip(L10n.of(context).content_filter_default, 1),
                _positionChip(L10n.of(context).content_filter_nsfw, 2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
