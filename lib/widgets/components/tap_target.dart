import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';

/// Expands a control's hit area to [AppSizing.minTapTarget] without changing
/// how big it looks.
///
/// Several of the app's controls are deliberately smaller than the touch
/// accessibility floor — 36pt circular chrome, 32pt chips. Wrapping the visual
/// widget here keeps the design intact while giving the gesture a target that
/// meets it. Place this *inside* the gesture detector so the padding is
/// tappable, and give that detector `HitTestBehavior.opaque`.
class AppTapTarget extends StatelessWidget {
  final Widget child;

  const AppTapTarget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AppSizing.minTapTarget,
        minHeight: AppSizing.minTapTarget,
      ),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}
