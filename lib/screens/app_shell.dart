import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/access_state.dart';
import '../state/ads_state.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/paywall.dart';
import 'flow/edit_flow.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Hosts the active top-level screen, the persistent bottom nav, and the
/// full-screen edit-flow and generator overlays.
///
/// Everything here lives in one [Stack] rather than on the [Navigator], so the
/// system back gesture has nothing to pop — this widget translates it into the
/// right in-app retreat instead (see [_handleBack]).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Guards against presenting the first-launch paywall twice while the first
  /// presentation is still resolving — the stored flag is only written once
  /// the native sheet has actually been asked for.
  bool _offeringOnboarding = false;

  /// Offers the subscription once, on a brand-new install.
  ///
  /// Deliberately not a blocking gate. Closing it leaves a fully usable app
  /// with three free enhancements, and if RevenueCat has no offering to show —
  /// no network on first launch, no published paywall — [showPaywall] reports
  /// an error and the user simply lands on Home. Nothing here promises a trial:
  /// the trial badge, the price and the eligibility all come from RevenueCat's
  /// own hosted paywall, which reads them from Google Play.
  ///
  /// Marked seen whatever the outcome, so it is offered once and never nags.
  Future<void> _offerOnboardingPaywall() async {
    if (_offeringOnboarding) return;
    _offeringOnboarding = true;
    final access = ref.read(accessProvider.notifier);
    try {
      final outcome = await showPaywall();

      if (outcome == PaywallResult.error) {
        // It never appeared — no network on first launch, no offering loaded,
        // no paywall published. That is not an offer, so it must not be
        // recorded as one: marking it seen here silently cost a new user the
        // trial on the single launch it was meant for. The next launch tries
        // again, a bounded number of times.
        await access.recordOnboardingFailure();
        return;
      }

      // Presented. Whatever the user did with it — bought, or closed it and
      // carried on free — they have been offered, and are not offered again.
      await access.markOnboardingSeen();

      if (outcome == PaywallResult.purchased ||
          outcome == PaywallResult.restored) {
        // Don't wait on RevenueCat's CustomerInfo stream: re-read now, so
        // premium is in effect by the time the paywall finishes dismissing.
        await ref.read(entitlementProvider.notifier).refresh();
      }
    } finally {
      _offeringOnboarding = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = ref.watch(screenProvider);
    final showNav = ref.watch(showNavProvider);
    final flowActive = ref.watch(flowProvider.select((s) => s.step != null));
    // Bootstraps RevenueCat and starts listening for entitlement changes from
    // the moment the app opens — not only once the user happens to visit
    // Settings or the paywall. AppShell is the one widget mounted for the
    // whole session, so this is what makes a renewal, an expiry or a
    // cancellation detected while those screens are closed still update Pro
    // status without the user having to open either one.
    ref.watch(entitlementProvider);
    // Same idea for ads: initialize Meta Audience Network now, so the first
    // ad a user reaches doesn't pay for that setup itself.
    ref.watch(adsBootstrapProvider);
    // Clears saved edits past their retention window. Nothing on screen
    // depends on the result; it just needs to run once per launch.
    ref.watch(editsMaintenanceProvider);
    // The free allowance and the first-launch state, restored from disk. Both
    // are read here because this is the widget that outlives every screen.
    ref.watch(accessProvider);

    // A brand-new install is offered the subscription once, after the stored
    // state has been read — so a returning user is never mistaken for a new
    // one by a slow disk, and someone who already pays is never sold to.
    if (ref.read(accessProvider.notifier).shouldOfferOnboarding &&
        !_offeringOnboarding) {
      // Out of build: presenting a native modal during layout is not safe.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!ref.read(accessProvider.notifier).shouldOfferOnboarding) return;
        unawaited(_offerOnboardingPaywall());
      });
    }

    // Back should exit the app only from the Home tab with nothing layered on
    // top of it. Anywhere else there's somewhere to retreat to first.
    final canPopToSystem = !flowActive && screen == AppScreen.home;

    return PopScope(
      canPop: canPopToSystem,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(ref, screen: screen, flowActive: flowActive);
      },
      child: Scaffold(
        body: Stack(
          // Scaffold hands its body *loose* constraints, and every child here
          // is positioned. A Stack sizes itself to its largest non-positioned
          // child, so without this it collapses to 0x0 and each Positioned.fill
          // lays out at zero width — which crashes any child that derives a
          // size from its own width.
          fit: StackFit.expand,
          children: [
            // Active top-level screen, inside a SafeArea.
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedSwitcher(
                  duration: context.motion(AppDurations.quick),
                  switchInCurve: AppDurations.easeOutCubic,
                  switchOutCurve: AppDurations.easeOut,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.015),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(screen),
                    child: SafeArea(bottom: false, child: _screenFor(screen)),
                  ),
                ),
              ),
            ),

            // Bottom nav.
            if (showNav)
              const Positioned(left: 0, right: 0, bottom: 0, child: BottomNav()),

            // Edit-flow modal overlay.
            if (flowActive) const _OverlayLayer(child: EditFlowOverlay()),
          ],
        ),
      ),
    );
  }

  /// Resolves one press of the system back gesture into the nearest retreat:
  /// close a full-screen overlay, or return to Home.
  void _handleBack(
    WidgetRef ref, {
    required AppScreen screen,
    required bool flowActive,
  }) {
    // The edit-flow overlay sits on top of everything, so it unwinds first.
    if (flowActive) {
      ref.read(flowProvider.notifier).back();
      return;
    }
    // A non-Home tab returns to Home rather than quitting — the standard
    // Android expectation for a tabbed app. The paywall needs no case of its
    // own: it is a native modal that consumes its own back press.
    ref.read(screenProvider.notifier).go(AppScreen.home);
  }

  Widget _screenFor(AppScreen screen) {
    switch (screen) {
      case AppScreen.home:
        return const HomeScreen();
      case AppScreen.history:
        return const HistoryScreen();
      case AppScreen.profile:
        return const ProfileScreen();
    }
  }
}

/// Fades and lifts a full-screen overlay into place instead of having it appear
/// between one frame and the next.
///
/// The caller mounts this only while the overlay is up, so the transition runs
/// on the way in and the jump from a tab screen to a full-screen step reads as
/// a move rather than a cut. It always returns a positioned child — an
/// unpositioned placeholder would take part in sizing the parent [Stack].
class _OverlayLayer extends StatelessWidget {
  final Widget child;

  const _OverlayLayer({required this.child});

  /// How far the overlay starts scaled down, so it grows into place.
  static const double _enterScale = 0.98;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: context.motion(AppDurations.slow),
        curve: AppDurations.easeOutCubic,
        builder: (context, t, inner) => Opacity(
          opacity: t,
          child: Transform.scale(
            scale: _enterScale + (1 - _enterScale) * t,
            child: inner,
          ),
        ),
        child: child,
      ),
    );
  }
}
