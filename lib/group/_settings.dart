import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_custom_settings.dart';
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
