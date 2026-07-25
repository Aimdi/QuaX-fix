import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Writes the timeline summary next to the other perf artefacts so a run can be
/// compared against `docs/perf-baseline.md` rather than read once and lost.
Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) {
        return;
      }

      final summary = driver.TimelineSummary.summarize(
        driver.Timeline.fromJson(data['scroll_timeline'] as Map<String, dynamic>),
      );
      await summary.writeTimelineToFile('feed_scroll', pretty: true, includeSummary: true);

      final json = summary.summaryJson;
      final report = {
        'average_frame_build_time_millis': json['average_frame_build_time_millis'],
        'worst_frame_build_time_millis': json['worst_frame_build_time_millis'],
        'missed_frame_build_budget_count': json['missed_frame_build_budget_count'],
        'average_frame_rasterizer_time_millis': json['average_frame_rasterizer_time_millis'],
        'worst_frame_rasterizer_time_millis': json['worst_frame_rasterizer_time_millis'],
        'missed_frame_rasterizer_budget_count': json['missed_frame_rasterizer_budget_count'],
        'frame_count': json['frame_count'],
      };

      // ignore: avoid_print
      print('\nfeed scroll summary:\n${const JsonEncoder.withIndent('  ').convert(report)}\n');

      await Directory('build').create(recursive: true);
      await File('build/feed_scroll_summary.json').writeAsString(jsonEncode(report));
    },
  );
}
