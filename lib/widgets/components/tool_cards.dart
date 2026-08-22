import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/theme.dart';
import '../demo_image.dart';
import 'app_card.dart';
import 'before_after.dart';

/// A full-width tool card: an interactive before/after comparison fills the
/// whole tile at the artwork's own 3:2 ratio (so nothing is cropped), with the
/// tool's identity overlaid on it. The divider is grabbable from either side —
/// a horizontal drag anywhere scrubs the reveal — while a plain tap jumps
/// straight into picking a photo for this tool. Only horizontal drags move the
/// seam, so the card's tap-to-launch and the page's vertical scroll are intact.
///
/// Shared by the Tools hub and the Home "all tools" list so both screens render
/// a tool the same way; the previous per-screen copy is gone.
class ToolCard extends StatelessWidget {
  final Tool tool;
  final VoidCallback onTap;

  const ToolCard({super.key, required this.tool, required this.onTap});

  /// Diameter of the launch affordance. The whole card is the tap target, so
  /// this is a signifier rather than a control of its own.
  static const double _arrowSize = AppSizing.controlSm;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${tool.name}. ${tool.desc}',
      child: AppCard(
        color: Colors.transparent,
        clip: true,
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: kToolArtAspect,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Grabbable from either side; tapToSeek is off so a plain tap
              // launches the tool while only a horizontal drag scrubs the seam
              // (never fighting the list's vertical scroll).
              BeforeAfterSlider.scene(
                tool.scene,
                seed: tool.seed,
                art: tool.art,
                drag: BeforeAfterDrag.surface,
                tapToSeek: false,
              ),
              // Readability scrim so the overlaid identity holds up over any
              // scene, bright or dark.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppOverlay.bottomScrimStrong,
                ),
              ),
              Positioned(
                left: AppSpacing.x14,
                right: AppSpacing.x14,
                bottom: AppSpacing.x12,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tool.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.cardTitleOnImage(AppColors.onColor),
                          ),
                          const SizedBox(height: AppSpacing.tightGap),
                          Text(
                            tool.desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption(AppOverlay.onDarkStrong),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x10),
                    // Where the card goes, not what it accepts: the disc used
                    // to hold an "add photo" glyph, which described the step
                    // *after* this one. An arrow says only "this leads
                    // somewhere", which is all a whole-card target should.
                    const _CardArrow(
                      size: _arrowSize,
                      iconSize: AppSizing.iconMd,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The circular "go" affordance in a card's bottom-right corner.
///
/// A white disc with an ink arrow, sized to the copy beside it. Shared by both
/// card shapes so the grid tiles and the full-width rows carry the same mark;
/// it is purely a signifier — the card itself is the tap target — so it is
/// hidden from assistive tech, which already announces the card as a button.
class _CardArrow extends StatelessWidget {
  final double size;
  final double iconSize;

  const _CardArrow({required this.size, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.onColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          AppIcons.forward,
          color: AppOverlay.ink,
          size: iconSize,
        ),
      ),
    );
  }
}

/// A compact tool tile for the Home 2×2 "top tools" grid.
///
/// Quieter than [ToolCard] — just the tool's name and a launch glyph over the
/// artwork — but it carries the same interactive before/after comparison, so
/// every card in the app behaves alike: grabbable from either side to scrub,
/// tap to launch. Labels are dropped at this small size; the seam and its
/// handle already read as a comparison. Fills whatever box the grid gives it,
/// so the caller owns the sizing.
class ToolGridTile extends StatelessWidget {
  final Tool tool;
  final VoidCallback onTap;

  const ToolGridTile({super.key, required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${tool.name}. ${tool.desc}',
      child: AppCard(
        color: Colors.transparent,
        clip: true,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Grabbable from either side; tapToSeek off so a tap still launches.
            BeforeAfterSlider.scene(
              tool.scene,
              seed: tool.seed,
              art: tool.art,
              drag: BeforeAfterDrag.surface,
              tapToSeek: false,
              showLabels: false,
            ),
            // Readability scrim behind the label.
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppOverlay.bottomScrimStrong),
            ),
            Positioned(
              left: AppSpacing.x12,
              right: AppSpacing.x12,
              bottom: AppSpacing.x12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      tool.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitleOnImage(AppColors.onColor),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.innerGap),
                  const _CardArrow(
                    size: AppSizing.controlXs,
                    iconSize: AppSizing.iconSm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
