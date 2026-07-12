import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_custom_settings.dart';
import 'package:quax/group/group_model.dart';

// A per-feed override that can defer to the global default: null → "Default"
// (follow the global setting), true → "Show", false → "Hide".
Widget _inheritTile(BuildContext context, String title, bool? value, Future<void> Function(bool?) onChanged) {
  return ListTile(
    title: Text(title),
    trailing: DropdownButton<int>(
      value: value == null ? 0 : (value ? 1 : 2),
      underline: const SizedBox.shrink(),
      onChanged: (choice) async => await onChanged(choice == 0 ? null : choice == 1),
      items: [
        DropdownMenuItem(value: 0, child: Text(L10n.of(context).content_filter_default)),
        DropdownMenuItem(value: 1, child: Text(L10n.of(context).show)),
        DropdownMenuItem(value: 2, child: Text(L10n.of(context).hide)),
      ],
    ),
  );
}

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

void showFeedSettings(BuildContext context, GroupModel model) {
  showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
            child: SingleChildScrollView(
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
                    _inheritTile(
                      context,
                      L10n.of(context).include_replies,
                      model.state.includeReplies,
                      (value) => model.toggleSubscriptionGroupIncludeReplies(value),
                    ),
                    _inheritTile(
                      context,
                      L10n.of(context).include_retweets,
                      model.state.includeRetweets,
                      (value) => model.toggleSubscriptionGroupIncludeRetweets(value),
                    ),
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
                          secondary: IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () async {
                              if (!model.state.custom) {
                                await model.toggleSubscriptionGroupCustom(true);
                              }
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GroupCustomSettingsScreen(model: model),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        )));
      });
}
