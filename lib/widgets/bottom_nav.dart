import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../theme/theme.dart';
import 'components/components.dart';

/// Full-width bottom navigation — a solid bar pinned to the bottom edge with a
/// hairline divider above it and a sliding underline marking the active tab.
///
/// Deliberately not a floating translucent island any more. That design left a
/// gap beneath the bar and a blurred surface behind it, so whatever happened to
/// be scrolled under the nav — a photo, a transparency checkerboard — stayed
/// visible around it and competed with the tabs. An opaque bar sitting flush on
/// the screen edge has no gap to show through and needs no fade to hide one.
class BottomNav extends ConsumerWidget {
  const BottomNav({super.key});

  static const double _barHeight = AppSizing.navBarHeight;

  /// Thickness of the sliding active-tab underline.
  static const double _indicatorHeight = 3;

  /// Underline width as a share of one tab's slot — narrower than the label so
  /// it reads as a marker rather than a second surface.
  static const double _indicatorWidthFactor = 0.34;

  /// The three destinations in display order — icon, label, and the screen they
  /// navigate to. Kept here so the layout loop and the indicator can share the
  /// same count.
  static const List<_NavDestination> _destinations = [
    _NavDestination(AppIcons.home, 'Home', AppScreen.home),
    _NavDestination(AppIcons.history, 'History', AppScreen.history),
    _NavDestination(AppIcons.settings, 'Settings', AppScreen.profile),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = PaletteScope.of(context);
    final screen = ref.watch(screenProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Which tab index is active — drives the sliding indicator.
    final activeIndex = _destinations.indexWhere((d) => d.screen == screen);

    void go(AppScreen destination) {
      if (screen == destination) return;
      AppHaptics.tick();
      ref.read(screenProvider.notifier).go(destination);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.navBar,
        // The divider is what separates the bar from the page above it. On the
        // light theme a white bar on a white canvas has no tonal step of its
        // own, so this line is doing the whole job and is not decorative.
        border: Border(
          top: BorderSide(
            color: palette.border2,
            width: AppSizing.strokeHairline,
          ),
        ),
      ),
      child: Padding(
        // The system gesture/navigation area. Content sits above it; the bar's
        // colour still runs to the physical bottom edge.
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: _barHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / _destinations.length;
              final indicatorWidth = slotWidth * _indicatorWidthFactor;
              final left = activeIndex >= 0
                  ? slotWidth * activeIndex + (slotWidth - indicatorWidth) / 2
                  : 0.0;

              return Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < _destinations.length; i++)
                        Expanded(
                          child: _NavItem(
                            icon: _destinations[i].icon,
                            label: _destinations[i].label,
                            active: i == activeIndex,
                            onTap: () => go(_destinations[i].screen),
                          ),
                        ),
                    ],
                  ),

                  // ── Sliding active indicator ──
                  if (activeIndex >= 0)
                    AnimatedPositioned(
                      duration: context.motion(AppDurations.base),
                      curve: AppDurations.spring,
                      left: left,
                      bottom: 0,
                      width: indicatorWidth,
                      height: _indicatorHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: AppRadius.brPill,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Internal model for a bottom-nav destination.
class _NavDestination {
  final IconData icon;
  final String label;
  final AppScreen screen;

  const _NavDestination(this.icon, this.label, this.screen);
}

/// One destination in the bar.
///
/// The active tab is marked on three cooperating axes: the icon and label take
/// the palette accent, the label switches to its heaviest weight, and the
/// sliding underline in [BottomNav] sits beneath it.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = PaletteScope.of(context);
    // Inactive tabs need to read clearly on their own — palette.textSecondary
    // (60% opacity) was too faint to be legible at a glance.
    final color = active
        ? palette.accent
        : palette.textPrimary.withValues(alpha: 0.62);
    final duration = context.motion(AppDurations.base);

    return Semantics(
      button: true,
      selected: active,
      label: label,
      // The label is a visible [Text] child, which would otherwise contribute
      // its own competing semantics node — excluded so this button's
      // accessible name stays exactly the explicit [label] above.
      child: ExcludeSemantics(
        child: AppPressable(
          onTap: onTap,
          depth: PressDepth.none,
          haptic: null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<Color?>(
                duration: duration,
                curve: AppDurations.easeOut,
                tween: ColorTween(end: color),
                builder: (context, animated, _) => Icon(
                  icon,
                  size: AppSizing.navIcon,
                  color: animated ?? color,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              // Always shown, so an inactive tab's icon (a clock, a gear) is
              // never left to speak for itself.
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.navLabel(color).copyWith(
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
