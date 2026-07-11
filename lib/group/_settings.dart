import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';

int _sortModeOf(SubscriptionGroupGet group) => group.custom ? 2 : (group.popular ? 1 : 0);

String _sortModeLabel(BuildContext context, SubscriptionGroupGet group) {
  switch (_sortModeOf(group)) {
    case 1:
      return L10n.of(context).popular;
    case 2:
      return L10n.of(context).custom;
    default:
      return L10n.of(context).recent;
  }
}

// Three-position content bar for custom mode: SFW only / default / NSFW only.
// Keeps its position locally so dragging responds instantly, and persists the
// choice through the group model.
class _ContentFilterBar extends StatefulWidget {
  final GroupModel model;

  const _ContentFilterBar({required this.model});

  @override
  State<_ContentFilterBar> createState() => _ContentFilterBarState();
}

class _ContentFilterBarState extends State<_ContentFilterBar> {
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(L10n.of(context).content_filter, style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [Colors.green, Colors.yellow, Colors.orange, Colors.red],
                      ),
                    ),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8,
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
      ),
    );
  }
}

void showFeedSettings(BuildContext context, GroupModel model) {
  showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.of(context).pop();
                  }),
              title: Text(
                L10n.of(context).filters,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Container(
                alignment: Alignment.centerLeft,
                margin: const EdgeInsets.only(bottom: 8, top: 16, left: 16, right: 16),
                child: Text(
                  L10n.of(context).note_due_to_a_twitter_limitation_not_all_tweets_may_be_included,
                  style: TextStyle(
                    color: Theme.of(context).disabledColor,
                  ),
                )),
            ScopedBuilder<GroupModel, SubscriptionGroupGet>(
              store: model,
              onState: (_, state) {
                return Column(
                  children: [
                    SwitchListTile(
                        title: Text(
                          L10n.of(context).include_replies,
                        ),
                        value: model.state.includeReplies,
                        onChanged: (value) async {
                          await model.toggleSubscriptionGroupIncludeReplies(value);
                        }),
                    SwitchListTile(
                        title: Text(
                          L10n.of(context).include_retweets,
                        ),
                        value: model.state.includeRetweets,
                        onChanged: (value) async {
                          await model.toggleSubscriptionGroupIncludeRetweets(value);
                        }),
                    ExpansionTile(
                      leading: const Icon(Icons.sort),
                      title: Text(_sortModeLabel(context, model.state)),
                      subtitle: Text(L10n.of(context).popular_feed_description),
                      children: [
                        RadioListTile<int>(
                          title: Text(L10n.of(context).recent),
                          value: 0,
                          groupValue: _sortModeOf(model.state),
                          onChanged: (_) async => await model.toggleSubscriptionGroupPopular(false),
                        ),
                        RadioListTile<int>(
                          title: Text(L10n.of(context).popular),
                          value: 1,
                          groupValue: _sortModeOf(model.state),
                          onChanged: (_) async => await model.toggleSubscriptionGroupPopular(true),
                        ),
                        RadioListTile<int>(
                          title: Text(L10n.of(context).custom),
                          value: 2,
                          groupValue: _sortModeOf(model.state),
                          onChanged: (_) async => await model.toggleSubscriptionGroupCustom(true),
                        ),
                        if (model.state.custom) _ContentFilterBar(model: model),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ));
      });
}
