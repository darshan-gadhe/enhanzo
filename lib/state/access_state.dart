import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/access_store.dart';
import 'app_state.dart';

/// What a user is currently allowed to do, and what they have left.
@immutable
class AccessState {
  /// Free enhancements already spent. Meaningless for a premium user.
  final int freeUsed;

  /// True once the stored counter has been read. Until then the app knows
  /// nothing and refuses to spend a generation — see [canGenerate].
  final bool loaded;

  /// Whether the first-launch paywall has already been offered.
  final bool onboardingSeen;

  /// Launches that tried to present it and could not.
  final int onboardingTries;

  /// RevenueCat's answer, mirrored here so one object answers "may this run".
  final bool isPremium;

  /// Whether RevenueCat has actually answered. See [Entitlement.resolved] —
  /// without it a reinstalling subscriber is indistinguishable from a new user
  /// for as long as the store takes to reply.
  final bool premiumKnown;

  const AccessState({
    this.freeUsed = 0,
    this.loaded = false,
    this.onboardingSeen = false,
    this.onboardingTries = 0,
    this.isPremium = false,
    this.premiumKnown = false,
  });

  /// Free enhancements a new install gets before the paywall.
  static const int freeLimit = 3;

  int get freeRemaining =>
      isPremium ? 0 : (freeLimit - freeUsed).clamp(0, freeLimit);

  /// Whether an enhancement may start right now.
  ///
  /// Premium is unlimited. A free user has [freeLimit] and no more. An
  /// unloaded state is treated as *not* allowed rather than allowed: the
  /// counter arrives within milliseconds of launch, and failing the other way
  /// would hand out free enhancements to anyone who could make the read slow.
  bool get canGenerate {
    if (isPremium) return true;
    if (!loaded) return false;
    return freeUsed < freeLimit;
  }

  /// True when a free user has spent everything and the next attempt is a
  /// paywall rather than a run.
  bool get freeLimitReached => !isPremium && loaded && freeUsed >= freeLimit;

  AccessState copyWith({
    int? freeUsed,
    bool? loaded,
    bool? onboardingSeen,
    int? onboardingTries,
    bool? isPremium,
    bool? premiumKnown,
  }) {
    return AccessState(
      freeUsed: freeUsed ?? this.freeUsed,
      loaded: loaded ?? this.loaded,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      onboardingTries: onboardingTries ?? this.onboardingTries,
      isPremium: isPremium ?? this.isPremium,
      premiumKnown: premiumKnown ?? this.premiumKnown,
    );
  }
}

/// The single authority on whether an enhancement may run and whether an ad
/// may be asked for.
///
/// Everything monetization-related that gates a *user action* reads this one
/// object: the enhance button, the processing controller's own guard, the
/// interstitial boundary and the first-launch paywall. There is deliberately
/// no second counter anywhere — a free tier enforced in two places is a free
/// tier enforced in neither.
///
/// It watches [entitlementProvider] rather than caching premium status, so an
/// expiry, a refund or a purchase made on another device changes what is
/// allowed the moment RevenueCat says so.
class AccessController extends Notifier<AccessState> {
  bool _disposed = false;

  /// Guards the read-modify-write in [consumeFreeGeneration] against two
  /// results landing at once.
  bool _consuming = false;

  @override
  AccessState build() {
    // Re-armed on every build. A rebuild reuses this same instance and fires
    // the *previous* build's onDispose, so a latched flag would stay true for
    // the rest of the session and freeze the controller — every later
    // `if (_disposed) return` would fire, the restore would never complete,
    // and `canGenerate` would be false forever.
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    // `listen`, not `watch`. Watching rebuilds this notifier every time
    // premium status changes — which is exactly when it must not start over:
    // the rebuild threw away the counter just read from disk, reset `loaded`
    // to false, and left a user who had subscribed and then expired unable to
    // enhance anything at all. The entitlement is a value to follow, not a
    // reason to rebuild.
    ref.listen(entitlementProvider, (_, entitlement) {
      if (_disposed) return;
      state = state.copyWith(
        isPremium: entitlement.isPro,
        premiumKnown: entitlement.resolved,
      );
    });

    // Whatever it is right now; the listener above carries it from here.
    final entitlement = ref.read(entitlementProvider);
    _restore();
    return AccessState(
      isPremium: entitlement.isPro,
      premiumKnown: entitlement.resolved,
    );
  }

  Future<void> _restore() async {
    final used = await AccessStore.readFreeUsed();
    final seen = await AccessStore.readOnboardingSeen();
    final tries = await AccessStore.readOnboardingTries();
    if (_disposed) return;
    state = state.copyWith(
      // A storage failure counts as exhausted rather than fresh.
      freeUsed: used ?? AccessState.freeLimit,
      loaded: true,
      onboardingSeen: seen,
      onboardingTries: tries,
    );
  }

  /// Spends one free enhancement. Premium users are never charged one.
  ///
  /// Called at exactly one point — a generation that actually produced a
  /// result — so a cancelled run, a failed upload, a model error, a timeout or
  /// a photo the user never enhanced all cost nothing.
  ///
  /// Returns the number now used. The write is awaited before [state] moves,
  /// so the count on screen is the count on disk.
  Future<int> consumeFreeGeneration() async {
    if (state.isPremium) return state.freeUsed;
    // Two results cannot both spend the same allowance.
    if (_consuming) return state.freeUsed;
    _consuming = true;
    try {
      final next = state.freeUsed + 1;
      await AccessStore.writeFreeUsed(next);
      if (!_disposed) state = state.copyWith(freeUsed: next);
      return next;
    } finally {
      _consuming = false;
    }
  }

  /// Records that the first-launch paywall was actually presented, so it is
  /// never offered automatically again.
  ///
  /// Call this only when the paywall really appeared. A presentation that
  /// failed was not an offer, and marking it seen would quietly cost a new
  /// user the trial they were meant to be shown — see [recordOnboardingFailure].
  Future<void> markOnboardingSeen() async {
    if (state.onboardingSeen) return;
    if (!_disposed) state = state.copyWith(onboardingSeen: true);
    await AccessStore.writeOnboardingSeen();
  }

  /// Records that a presentation was attempted and did not appear.
  ///
  /// The next launch tries again, up to [AccessStore.maxOnboardingTries], after
  /// which it is treated as seen: a configuration that never works must not
  /// open a paywall on every launch forever.
  Future<void> recordOnboardingFailure() async {
    final tries = state.onboardingTries + 1;
    if (!_disposed) state = state.copyWith(onboardingTries: tries);
    await AccessStore.writeOnboardingTries(tries);
    if (tries >= AccessStore.maxOnboardingTries) await markOnboardingSeen();
  }

  /// Whether the first-launch paywall should be presented right now.
  ///
  /// Only on a brand-new install, only once, and never to someone who has
  /// already paid.
  ///
  /// Waits on *both* answers, and the second one is the one that was missing.
  /// [loaded] is a local disk read that lands in about a millisecond;
  /// [premiumKnown] is a network round-trip to RevenueCat. A subscriber who
  /// reinstalls has no local flag and looks brand new, so deciding before the
  /// store replies sold a subscription to someone who already had one — the
  /// exact thing this must never do.
  bool get shouldOfferOnboarding =>
      state.loaded &&
      state.premiumKnown &&
      !state.onboardingSeen &&
      state.onboardingTries < AccessStore.maxOnboardingTries &&
      !state.isPremium;

  /// Test seam: restores the in-memory view from storage. The app never needs
  /// it — [build] does this once per launch.
  @visibleForTesting
  Future<void> reloadForTest() => _restore();
}

final accessProvider = NotifierProvider<AccessController, AccessState>(
  AccessController.new,
);
