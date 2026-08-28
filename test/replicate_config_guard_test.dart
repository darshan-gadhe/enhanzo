// A release build compiled without --dart-define-from-file=.env produces a
// signed, uploadable bundle whose app cannot enhance a single photo. One was
// installed that way, showing users an error where the product should be.
//
// `assertConfigured` turns that silent failure loud at startup. Under
// `flutter test` kReleaseMode is false, so the guard must stay a no-op here —
// pinning that is what stops someone "fixing" it into throwing during tests
// or in debug runs, which is exactly the behaviour that would make it get
// removed again.

import 'package:ai_enhancer/data/replicate/replicate_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the guard is inert outside release builds', () {
    expect(kReleaseMode, isFalse, reason: 'flutter test runs in debug');
    expect(ReplicateConfig.assertConfigured, returnsNormally);
  });

  test('isConfigured is what the guard keys off', () {
    // Either mode counts as configured; the guard only fires when neither is.
    expect(
      ReplicateConfig.isConfigured,
      ReplicateConfig.apiToken.isNotEmpty || ReplicateConfig.usesProxy,
    );
  });

  test('proxy mode never sends our own Authorization header', () {
    // The proxy holds the real token; sending one from the app would leak a
    // credential the app is designed not to have.
    if (ReplicateConfig.usesProxy) {
      expect(ReplicateConfig.sendsToken, isFalse);
    }
  });
}
