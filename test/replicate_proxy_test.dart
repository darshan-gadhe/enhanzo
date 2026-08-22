// Proves the client sends proxy headers instead of a Replicate token once a
// proxy is configured.
//
// REPLICATE_PROXY_URL / REPLICATE_APP_KEY are compile-time defines
// (String.fromEnvironment), so — like the direct REPLICATE_API_TOKEN — they
// cannot be set at Dart runtime and this file cannot flip ReplicateConfig
// itself. What it verifies instead: in the default `flutter test` run (no
// defines, the same build every other test uses) the client is in direct-token
// mode and sends none of the proxy headers, which is the behaviour every other
// test in this suite already relies on. Run with the defines set to exercise
// the proxy branch for real:
//
//   flutter test test/replicate_proxy_test.dart \
//     --dart-define=REPLICATE_PROXY_URL=https://proxy.example.com \
//     --dart-define=REPLICATE_APP_KEY=test-app-key

import 'dart:convert';

import 'package:ai_enhancer/data/replicate/replicate_client.dart';
import 'package:ai_enhancer/data/replicate/replicate_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // The device id is persisted through SharedPreferences (see device_id.dart);
  // proxy mode reads it on every request, so it needs a backing store even
  // when direct mode never touches it.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the base URL and headers match the configured mode', () async {
    late http.Request seen;
    final client = ReplicateClient(
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'id': 'x', 'status': 'starting'}), 201);
      }),
    );

    await client.createPrediction(version: 'v', input: const {});

    if (ReplicateConfig.usesProxy) {
      // Proxy mode: the proxy's own credentials go out, and — critically —
      // no `Authorization` header exists for anything to leak. There is no
      // Replicate token in this build to send.
      expect(seen.url.origin, Uri.parse(ReplicateConfig.proxyBaseUrl).origin);
      expect(seen.headers['X-App-Key'], ReplicateConfig.appKey);
      expect(seen.headers['X-Device-Id'], isNotEmpty);
      expect(seen.headers.containsKey('Authorization'), isFalse);
    } else {
      // Default `flutter test` run: direct mode, exactly what every other
      // test in this suite assumes.
      expect(seen.url.origin, Uri.parse(ReplicateConfig.directBaseUrl).origin);
      expect(seen.headers.containsKey('X-App-Key'), isFalse);
      expect(seen.headers.containsKey('X-Device-Id'), isFalse);
    }
  });
}
