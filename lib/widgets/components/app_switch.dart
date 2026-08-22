import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// iOS-style toggle used across settings. Wrapped in a [FittedBox] so it keeps
/// a consistent 26pt height regardless of platform switch sizing.
///
/// "On" is the app's ink accent rather than the system green: the identity is
/// monochrome, and a lone green control in an otherwise black-and-white
/// interface reads as a piece of another app. State is still carried by the
/// thumb's position as well as by colour, so it doesn't rely on hue alone —
/// and the off track keeps a hairline outline so it stays visible on the white
/// card of the light theme.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const AppSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return SizedBox(
      height: AppSizing.switchHeight,
      child: FittedBox(
        child: Switch(
          value: value,
          onChanged: (next) {
            AppHaptics.tick();
            onChanged(next);
          },
          activeTrackColor: p.accent,
          inactiveTrackColor: p.textTertiary.withValues(alpha: 0.35),
          thumbColor: WidgetStateProperty.resolveWith(
            // The thumb inverts against the ink track when on, so a white
            // track on the dark theme doesn't swallow a white thumb.
            (states) => states.contains(WidgetState.selected)
                ? p.onAccent
                : AppColors.onColor,
          ),
          trackOutlineColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.transparent
                : p.border2,
          ),
        ),
      ),
    );
  }
}
