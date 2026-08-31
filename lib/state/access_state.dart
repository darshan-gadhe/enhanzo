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

  /// RevenueCat's answer, mirrored here so one object answers "may this run".
  final bool isPremium;

  const AccessState({
    this.freeUsed = 0,
    this.loaded = false,
    this.onboardingSeen = false,
    this.isPremium = false,
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
    bool? isPremium,
  }) {
    return AccessState(
      freeUsed: freeUsed ?? this.freeUsed,
      loaded: loaded ?? this.loaded,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      isPremium: isPremium ?? this.isPremium,
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
    ref.listen(entitlementProvider.select((e) => e.isPro), (_, isPremium) {
      if (_disposed) return;
      state = state.copyWith(isPremium: isPremium);
    });

    // Whatever it is right now; the listener above carries it from here.
    final isPremium = ref.read(entitlementProvider).isPro;
    _restore();
    return AccessState(isPremium: isPremium);
  }

  Future<void> _restore() async {
    final used = await AccessStore.readFreeUsed();
    final seen = await AccessStore.readOnboardingSeen();
    if (_disposed) return;
    state = state.copyWith(
      // A storage failure counts as exhausted rather than fresh.
      freeUsed: used ?? AccessState.freeLimit,
      loaded: true,
      onboardingSeen: seen,
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

  /// Records that the first-launch paywall has been offered, so it is never
  /// offered automatically again.
  Future<void> markOnboardingSeen() async {
    if (state.onboardingSeen) return;
    if (!_disposed) state = state.copyWith(onboardingSeen: true);
    await AccessStore.writeOnboardingSeen();
  }

  /// Whether the first-launch paywall should be presented right now.
  ///
  /// Only on a brand-new install, only once, and never to someone who has
  /// already paid. Waits for [loaded] so a slow storage read cannot make a
  /// returning user look new.
  bool get shouldOfferOnboarding =>
      state.loaded && !state.onboardingSeen && !state.isPremium;

  /// Test seam: restores the in-memory view from storage. The app never needs
  /// it — [build] does this once per launch.
  @visibleForTesting
  Future<void> reloadForTest() => _restore();
}

final accessProvider = NotifierProvider<AccessController, AccessState>(
  AccessController.new,
);
