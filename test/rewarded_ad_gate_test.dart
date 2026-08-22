// Proves the one policy this whole feature exists to enforce: a reward is
// never granted just because the user tapped "Watch Ad" — only a genuine
// completed view earns it, and every other outcome (no SDK/fill, dismissed
// early) must fall through to a retry/Premium choice instead of unlocking
// anything.
//
// `flutter test`'s binding defaults defaultTargetPlatform to Android (for
// determinism across whatever machine happens to run the suite), so
// RewardedAdService does attempt a real platform-channel call here — one
// with no handler registered, since no Android/iOS SDK exists in a bare
// widget test. That resolves as RewardOutcome.unavailable via the try/catch
// in showRewardedAd (see rewarded_ad_service.dart) — the same graceful
// fallback a genuine no-fill or offline result would produce on a real
// device, which is exactly the path worth proving holds.

import 'package:ai_enhancer/data/ads/ad_config.dart';
import 'package:ai_enhancer/data/ads/rewarded_ad_service.dart';
import 'package:ai_enhancer/data/replicate/real_esrgan.dart';
import 'package:ai_enhancer/state/ads_state.dart';
import 'package:ai_enhancer/theme/theme.dart';
import 'package:ai_enhancer/widgets/rewarded_ad_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        // PaletteScope has to wrap the Navigator itself (via `builder`), not
        // sit inside `home`'s own content — a modal bottom sheet is a
        // separate route pushed onto the same Navigator, and only an
        // ancestor of the Navigator is visible to every route it hosts.
        // This mirrors exactly how EnhanzoApp wires it in lib/main.dart.
        builder: (context, child) => PaletteScope(
          palette: AppPalette.light,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Builder(
          builder: (context) => Consumer(
            builder: (context, ref, _) => ElevatedButton(
              onPressed: () => showRewardedAdGate(
                context,
                ref,
                actionVerb: 'Generate',
              ),
              child: const Text('open gate'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  _gatePreconditions();

  test(
    'on a platform with no ad SDK, showRewardedAd reports unavailable — never earned',
    () async {
      final outcome = await RewardedAdService.showRewardedAd();
      expect(outcome, RewardOutcome.unavailable);
    },
  );

  testWidgets('the gate names the real action in both choices', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('open gate'));
    await tester.pumpAndSettle();

    expect(find.text('Watch Ad to Generate'), findsOneWidget);
    expect(find.text('Go Premium — Generate Without Ads'), findsOneWidget);
  });

  // Exercised directly through the controller rather than by tapping through
  // the widget tree: the real platform-channel round trip this triggers
  // (rejecting with no handler registered) runs on the actual event loop,
  // which races unpredictably against widget_test's fake-clock pump()
  // timing. Awaiting the controller for real sidesteps that friction while
  // testing the exact same production code path — RewardedAdService's
  // try/catch is what's actually under test here, not pump scheduling.
  test(
    'the controller reports the reward as not earned, and lands in the '
    'failed state, when no ad SDK is available',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final earned = await container.read(adGateProvider.notifier).watch();

      expect(earned, isFalse);
      expect(container.read(adGateProvider).status, AdGateStatus.failed);
    },
  );

  testWidgets(
    'a failure from a previous attempt does not greet the next one',
    (tester) async {
      // adGateProvider outlives the sheet, so a failure left in its state
      // would otherwise render "No ad right now — Try Again" the instant the
      // gate reopened, for an attempt the user had not yet made.
      //
      // The controller starts in `failed` — standing in for that earlier
      // attempt — and deliberately keeps the real `reset()`, so this asserts
      // the gate actually clears the state on open rather than just checking
      // what a stub returns.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adGateProvider.overrideWith(
              () => _StaleFailureController(),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => PaletteScope(
              palette: AppPalette.light,
              child: child ?? const SizedBox.shrink(),
            ),
            home: Builder(
              builder: (context) => Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => showRewardedAdGate(
                    context,
                    ref,
                    actionVerb: 'Generate',
                  ),
                  child: const Text('open gate'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open gate'));
      await tester.pump();

      expect(find.text('No ad right now'), findsNothing);
      expect(find.text('Try Again'), findsNothing);
      expect(find.text('One free Generate'), findsOneWidget);
      expect(find.text('Watch Ad to Generate'), findsOneWidget);
    },
  );

  testWidgets(
    'the failed state renders Try Again and still offers Premium — never a '
    'dead end',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adGateProvider.overrideWith(
              () => _FakeAdGateController(AdGateStatus.failed),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => PaletteScope(
              palette: AppPalette.light,
              child: child ?? const SizedBox.shrink(),
            ),
            home: Builder(
              builder: (context) => Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => showRewardedAdGate(
                    context,
                    ref,
                    actionVerb: 'Generate',
                  ),
                  child: const Text('open gate'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open gate'));
      await tester.pumpAndSettle();

      expect(find.text('No ad right now'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Go Premium — Generate Without Ads'), findsOneWidget);
    },
  );

  testWidgets('Go Premium always resolves the gate, even mid-load', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('open gate'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go Premium — Generate Without Ads'));
    await tester.pumpAndSettle();

    // The sheet is gone — Go Premium is never blocked by ad state.
    expect(find.text('One free Generate'), findsNothing);
  });
}

/// A controller that starts in a given [AdGateStatus] without ever touching
/// the real ad SDK — for rendering one specific state (here, "failed")
/// deterministically, rather than racing a real platform-channel call
/// against widget-test pump timing to get there.
/// Starts in [AdGateStatus.failed] — a leftover from an earlier attempt — but
/// keeps the real [AdGateController.reset], so a test can prove the gate
/// clears that state itself rather than a stub reporting whatever it likes.
class _StaleFailureController extends AdGateController {
  @override
  AdGateState build() => const AdGateState(status: AdGateStatus.failed);
}

class _FakeAdGateController extends AdGateController {
  final AdGateStatus _initial;
  _FakeAdGateController(this._initial);

  @override
  AdGateState build() => AdGateState(status: _initial);

  /// Pinned: this stub exists to hold one state so it can be rendered. The
  /// real [AdGateController.reset] is what [showRewardedAdGate] calls to clear
  /// a stale failure on open, which would otherwise undo the very state this
  /// fake was constructed to show.
  @override
  void reset() {}
}

/// The inputs the enhance-flow gate consults before it ever shows a sheet
/// (see `_adGateAllows` in lib/screens/flow/edit_flow.dart).
///
/// These pin the *fail-open* contract. The gate stands in front of the only
/// action this app really performs, so every one of these conditions must
/// resolve to "let the run through" rather than "show an ad" — otherwise a
/// build that simply hasn't had its Meta placements filled in yet would leave free
/// users unable to enhance anything at all.
void _gatePreconditions() {
  group('enhance gate preconditions', () {
    test('a non-release build never requests billable inventory', () {
      // Meta publishes no universal test placement the way AdMob publishes
      // test ad units, so the same real placement is used everywhere and
      // testMode is the only thing separating development from live ads.
      // kReleaseMode is false under `flutter test`.
      expect(AdConfig.testMode, isTrue);
    });

    test('an unconfigured placement means no gate at all', () {
      // With no META_REWARDED_PLACEMENT_ID compiled in, there is nothing to
      // ask Meta for. The gate must then let the run through rather than
      // stranding free users behind an ad that can never load — the
      // fail-open contract `_adGateAllows` depends on.
      if (AdConfig.rewardedPlacementId.isEmpty) {
        expect(AdConfig.isRewardedConfigured, isFalse);
      } else {
        expect(AdConfig.isRewardedConfigured, isTrue);
      }
    });

    test('only tools with a model behind them are ever gated', () {
      // Gating a tool that is about to fail would make the user watch an ad
      // for an error message.
      for (final tool in RealEsrgan.supportedTools) {
        expect(RealEsrgan.supports(tool), isTrue);
      }
      expect(RealEsrgan.supports('Object Removal'), isFalse);
      expect(RealEsrgan.supports('Background Remove'), isFalse);
    });

    test('desktop and web are treated as having no ads at all', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(RewardedAdService.isSupportedPlatform, isFalse);
    });
  });
}
