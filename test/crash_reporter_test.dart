import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pref/pref.dart';
import 'package:quax/catcher/exceptions.dart';
import 'package:quax/constants.dart';
import 'package:quax/utils/crash_reporter.dart';

void main() {
  test('shouldReport skips synthetic and http account errors', () {
    expect(shouldReport(Exception('boom')), isTrue);
    expect(shouldReport(NoAccountAvailableException()), isFalse);
    expect(shouldReport(RateLimitedException()), isFalse);
    expect(shouldReport(NoWorkingAccountException()), isFalse);
  });

  test('issueApiUri validates owner/name', () {
    expect(issueApiUri('Aimdi/QuaX-gamma')?.path, '/repos/Aimdi/QuaX-gamma/issues');
    expect(issueApiUri('bad'), isNull);
    expect(issueApiUri('/'), isNull);
  });

  test('prefsMapWithoutSecrets strips the GitHub token', () {
    final cleaned = prefsMapWithoutSecrets({
      optionCrashGithubToken: 'secret',
      optionCrashReportsEnabled: true,
    });
    expect(cleaned.containsKey(optionCrashGithubToken), isFalse);
    expect(cleaned[optionCrashReportsEnabled], isTrue);
  });

  test('buildIssueTitle stays compact', () {
    final title = buildIssueTitle(Exception('x' * 200));
    expect(title.startsWith('[crash]'), isTrue);
    expect(title.length <= 120, isTrue);
  });

  test('report posts to GitHub when enabled with token', () async {
    final prefs = PrefServiceCache(cache: {
      optionCrashReportsEnabled: true,
      optionCrashGithubRepo: 'Aimdi/QuaX-gamma',
      optionCrashGithubToken: 'test-token',
    });

    http.Request? seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response('{"id":1}', 201, headers: {'content-type': 'application/json'});
    });

    final reporter = CrashReporter(
      prefs,
      httpClient: client,
      packageInfoLoader: () async => PackageInfo(
        appName: 'QuaX',
        packageName: 'com.teskann.quax',
        version: '4.12.0',
        buildNumber: '1',
      ),
    );
    final result = await reporter.report(Exception('unit-test-crash'), StackTrace.current, force: true);

    expect(result, CrashReportResult.sent);
    expect(seen, isNotNull);
    expect(seen!.method, 'POST');
    expect(seen!.url.path, '/repos/Aimdi/QuaX-gamma/issues');
    expect(seen!.headers['Authorization'], 'Bearer test-token');
  });

  test('report refuses to send without token', () async {
    final prefs = PrefServiceCache(cache: {
      optionCrashReportsEnabled: true,
      optionCrashGithubRepo: 'Aimdi/QuaX-gamma',
      optionCrashGithubToken: '',
    });
    final reporter = CrashReporter(prefs, httpClient: MockClient((_) async => http.Response('', 500)));
    final result = await reporter.report(Exception('x'), StackTrace.current, force: true);
    expect(result, CrashReportResult.missingToken);
  });
}
