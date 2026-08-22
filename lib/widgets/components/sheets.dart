import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'pressable.dart';

/// The small drag grabber shown at the top of every bottom sheet.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizing.grabberWidth,
      height: AppSizing.grabberHeight,
      decoration: BoxDecoration(
        color: PaletteScope.of(context).textTertiary,
        borderRadius: AppRadius.brXs,
      ),
    );
  }
}

/// Standard rounded bottom-sheet scaffold: floating card with a grabber and
/// safe-area-aware bottom padding. [children] are laid out in a min-height
/// column below the grabber.
class AppBottomSheet extends StatelessWidget {
  final List<Widget> children;
  final double horizontalPadding;
  final double bottomPadding;
  final CrossAxisAlignment crossAxisAlignment;

  const AppBottomSheet({
    super.key,
    required this.children,
    this.horizontalPadding = AppSpacing.x16,
    this.bottomPadding = AppSpacing.x14,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.x10,
        0,
        AppSpacing.x10,
        AppSpacing.x10,
      ),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.x12,
        horizontalPadding,
        bottomPadding + bottomInset,
      ),
      decoration: BoxDecoration(
        color: p.elevated,
        borderRadius: AppRadius.brXxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          const Center(child: SheetGrabber()),
          const SizedBox(height: AppSpacing.titleToContent),
          ...children,
        ],
      ),
    );
  }
}

/// Present [builder] as a transparent-background modal sheet.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    builder: builder,
  );
}

/// A stacked icon + label action used inside a sheet's action row.
class SheetActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback onTap;

  const SheetActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    final color = destructive ? AppColors.danger : p.textPrimary;
    return Semantics(
      button: true,
      label: label,
      child: AppPressable(
        onTap: onTap,
        // A destructive action announces itself more firmly than a neutral one.
        haptic: destructive ? AppHaptics.warn : AppHaptics.select,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x12),
          constraints: const BoxConstraints(
            minHeight: AppSizing.minTapTarget,
          ),
          decoration: BoxDecoration(
            color: p.fieldBg,
            borderRadius: AppRadius.brLg,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppSizing.iconLg, color: color),
              const SizedBox(height: AppSpacing.x6),
              Text(label, style: AppText.badge(color)),
            ],
          ),
        ),
      ),
    );
  }
}
