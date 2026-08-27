import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/ads_state.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../widgets/bottom_nav.dart';
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
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
