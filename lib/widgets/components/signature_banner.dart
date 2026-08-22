import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../demo_image.dart';
import 'app_badge.dart';
import 'app_card.dart';

/// A translucent rounded-square glyph tile that reads as glass over imagery.
///
/// The floating mark on a [SignatureBanner], but pulled out so any surface laid
/// over a photo can carry the same chip. Fill and stroke come from the
/// white-on-dark [AppOverlay] ladder, so it sits legibly on light and dark
/// scenes alike without a per-scene tint.
class GlassIconChip extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;

  const GlassIconChip({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize = AppSizing.iconLg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppOverlay.fillStrong,
        borderRadius: AppRadius.brLg,
        border: Border.all(
          color: AppOverlay.stroke,
          width: AppSizing.strokeHairline,
        ),
      ),
      child: Icon(icon, color: AppColors.onColor, size: iconSize),
    );
  }
}

/// A full-width cinematic feature banner — the hub's marquee surface.
///
/// A single 16:9 scene under a left-weighted scrim, with a glass glyph chip
/// floating top-left, an optional status [badge], the title/subtitle pinned
/// bottom-left and a chevron affordance bottom-right. The whole card is the tap
/// target. Use it sparingly — one curated highlight per hub — so it stays the
/// heaviest thing on the screen rather than competing with the list beneath it.
///
/// The scene comes from the procedural [DemoImage] system, so the banner needs
/// no bundled artwork; swap in an `Image` inside the stack to feature a real
/// photo later.
class SignatureBanner extends StatelessWidget {
  final DemoScene scene;
  final int seed;
  final IconData icon;
  final String title;
  final String subtitle;
  final AppBadge? badge;
  final VoidCallback onTap;

  const SignatureBanner({
    super.key,
    required this.scene,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.seed = 7,
    this.badge,
  });

  /// Chevron affordance in the bottom-right corner. Sized past the touch floor
  /// even though the whole card is the target, so it reads as pressable.
  static const double _chevron = 44;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: AppCard(
        color: Colors.transparent,
        borderRadius: AppRadius.brXxl,
        clip: true,
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DemoImage(scene: scene, seed: seed),
              // Left scrim carries the chip/title column; the bottom scrim
              // reinforces the title against a bright lower edge.
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppOverlay.bannerScrim),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppOverlay.bottomScrimStrong),
              ),

              // Floating glyph chip.
              Positioned(
                top: AppSpacing.x16,
                left: AppSpacing.x16,
                child: GlassIconChip(icon: icon),
              ),

              // Status badge, balanced opposite the chip.
              if (badge != null)
                Positioned(top: AppSpacing.x16, right: AppSpacing.x16, child: badge!),

              // Title block + chevron, pinned to the bottom.
              Positioned(
                left: AppSpacing.x16,
                right: AppSpacing.x16,
                bottom: AppSpacing.x16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.sectionTitle(AppColors.onColor),
                          ),
                          const SizedBox(height: AppSpacing.tightGap),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyCompact(AppOverlay.onDarkStrong),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.innerGap),
                    Container(
                      width: _chevron,
                      height: _chevron,
                      decoration: const BoxDecoration(
                        color: AppOverlay.fillStrong,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        AppIcons.forward,
                        color: AppColors.onColor,
                        size: AppSizing.iconLg,
                      ),
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
