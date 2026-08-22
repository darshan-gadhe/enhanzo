import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// A single-line row of chips that stays centred while it fits and scrolls once
/// it doesn't.
///
/// A bare `SingleChildScrollView` gets this wrong in the common case: its child
/// is laid out at its own intrinsic width and pinned to the leading edge, so a
/// row of four short chips ends up hugging the left instead of sitting under
/// the canvas it belongs to. Giving the child a `minWidth` of the viewport lets
/// [MainAxisAlignment.center] do its job when there's slack, while still
/// allowing the row to exceed the viewport and scroll when the labels grow at
/// large text sizes.
///
/// Used by the crop-ratio and export-size selectors, which are the two places
/// where four chips plus their gaps can outgrow a narrow screen.
class AppChipBar extends StatelessWidget {
  /// The chips, in order. Gaps are inserted between them.
  final List<Widget> chips;

  /// Space between adjacent chips.
  final double spacing;

  const AppChipBar({
    super.key,
    required this.chips,
    this.spacing = AppSpacing.itemGap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            // Fills the viewport when the chips are narrower than it, which is
            // what gives `center` something to centre within.
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < chips.length; i++) ...[
                  if (i > 0) SizedBox(width: spacing),
                  chips[i],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
