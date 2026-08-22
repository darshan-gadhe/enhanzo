import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ads/ad_config.dart';
import '../../data/ads/interstitial_ad_service.dart';
import '../../data/ads/rewarded_ad_service.dart';
import '../../data/catalog.dart';
import '../../data/replicate/real_esrgan.dart';
import '../../data/replicate/replicate_config.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/theme.dart';
import '../../widgets/components/components.dart';
import '../../widgets/demo_image.dart';
import '../../widgets/edit_image.dart';
import '../../widgets/paywall.dart';
import '../../widgets/rewarded_ad_gate.dart';
import '../../widgets/share_sheet.dart';
import 'photo_source_sheet.dart';

/// Shows a Meta interstitial after a finished edit — free users only.
///
/// Deliberately placed at a task *boundary*, not inside one: this fires once
/// the edit is already saved to History and the flow has closed, so it never
/// interrupts work in progress and nothing the user did is waiting on it.
/// That is also what Meta's and Play's policies ask for — a full-screen ad
/// between activities rather than across one.
///
/// Fire-and-forget by design: no-fill, no network or an unconfigured
/// placement all resolve to "nothing happens", which is the correct outcome
/// for an ad that was never owed to anyone.
void _maybeShowInterstitial(WidgetRef ref) {
  if (ref.read(entitlementProvider).isPro) return;
  unawaited(InterstitialAdService.showInterstitial());
}

/// Whether an enhance run may start now — showing the rewarded-ad gate first
/// when, and only when, it genuinely applies.
///
/// The gate is deliberately *skipped* in every case where asking for the
/// user's attention would be dishonest or useless:
///
/// * **Pro users** have already paid for an ad-free app.
/// * **The demo pipeline** (no photo picked) spends nothing to run.
/// * **A build with no Replicate credentials** is about to fail with its own
///   message — an ad in front of an error is worse than no ad.
/// * **A tool with no model behind it** (Object Removal, Background, …) is
///   likewise about to fail, so it is never gated.
/// * **No placement configured, or not Android** — the run proceeds. This is
///   the important one: without it, a build whose
///   `META_REWARDED_PLACEMENT_ID` is blank would leave free users unable to
///   enhance anything at all.
///
/// Returns true if the caller should go ahead and start the run.
Future<bool> _adGateAllows(
  BuildContext context,
  WidgetRef ref,
  String tool,
) async {
  if (ref.read(entitlementProvider).isPro) return true;

  final state = ref.read(flowProvider);
  if (state.photo == null) return true;
  if (!ReplicateConfig.isConfigured) return true;
  if (!RealEsrgan.supports(tool)) return true;
  if (!RewardedAdService.isSupportedPlatform ||
      !AdConfig.isRewardedConfigured) {
    return true;
  }

  final result = await showRewardedAdGate(context, ref, actionVerb: 'Enhance');
  switch (result) {
    case AdGateResult.rewardEarned:
      return true;
    case AdGateResult.choseGoPremium:
      // RevenueCat's paywall is a native modal presented over whatever is on
      // screen, so the flow no longer has to be torn down to reveal it — the
      // user keeps their photo and crop, and a purchase drops them straight
      // back here.
      final outcome = await showPaywall();
      if (!context.mounted) return false;
      if (outcome == PaywallResult.error) {
        // RevenueCat could not present — no key for this build, or no paywall
        // published for the current offering. Say so: the user deliberately
        // asked for Premium, and silently returning them to the canvas with
        // nothing on screen is the dead-button experience this gate exists to
        // avoid.
        AppSnack.show(
          context,
          "Couldn't open subscriptions right now. Please try again.",
          overlay: true,
        );
        return false;
      }
      // Bought or restored: they are Pro now, so the run they were trying to
      // start should just proceed. The entitlement listener has already
      // updated state by this point.
      return outcome == PaywallResult.purchased ||
          outcome == PaywallResult.restored;
    case AdGateResult.dismissed:
      return false;
  }
}

/// Full-screen modal overlay that renders the current [EditFlow] step.
class EditFlowOverlay extends ConsumerWidget {
  const EditFlowOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(flowProvider.select((s) => s.step));
    switch (step) {
      case EditFlow.crop:
        return const _CropStep();
      case EditFlow.tool:
        return const _ToolPickStep();
      case EditFlow.processing:
        return const _ProcessingStep();
      case EditFlow.result:
        return const _ResultStep();
      case EditFlow.error:
        return const _ErrorStep();
      case null:
        return const SizedBox.shrink();
    }
  }
}

/// The top bar of a full-screen flow step: a leading and trailing accessory
/// with the title held on the true horizontal centre between them.
///
/// A plain space-between row leaves the title off-centre whenever the two sides
/// differ in width (Cancel vs Next, a close circle vs a share circle), so the
/// title is centred absolutely and the accessories are pinned to the edges over
/// it. The title reserves [_sideReserve] on each side so it clears the widest
/// text action the flow uses before it ellipsises. Reads the top safe-area
/// inset itself so callers don't repeat it.
class _OverlayNavBar extends StatelessWidget {
  final Widget? leading;
  final Widget? trailing;
  final String title;
  final Color titleColor;

  /// Optional bottom hairline — used on the light tool-picker, omitted on the
  /// dark editing canvases where a divider would only add noise.
  final Color? borderColor;

  const _OverlayNavBar({
    required this.title,
    required this.titleColor,
    this.leading,
    this.trailing,
    this.borderColor,
  });

  /// Space reserved on each side of the centred title so it never runs under an
  /// accessory. Sized past the widest nav text action (Cancel).
  static const double _sideReserve = 76;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        topInset + AppSpacing.x12,
        AppSpacing.screenH,
        AppSpacing.x14,
      ),
      decoration: borderColor != null
          ? BoxDecoration(border: Border(bottom: BorderSide(color: borderColor!)))
          : null,
      child: SizedBox(
        // A stable bar height so the title sits on the same axis as the
        // accessories regardless of their individual heights.
        height: AppSizing.minTapTarget,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _sideReserve),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.navTitle(titleColor),
              ),
            ),
            if (leading != null)
              Align(alignment: Alignment.centerLeft, child: leading),
            if (trailing != null)
              Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ),
      ),
    );
  }
}

// ============ CROP ============
class _CropStep extends ConsumerWidget {
  const _CropStep();

  /// Widest the crop canvas is allowed to grow on large screens.
  static const double _canvasMaxWidth = 320;

  /// "Next" — gated only on the branch that goes straight into processing.
  /// With no tool chosen yet this just advances to the picker, which spends
  /// nothing, so the ad is asked for there instead.
  Future<void> _cropNext(BuildContext context, WidgetRef ref) async {
    final state = ref.read(flowProvider);
    if (state.tool.isEmpty) {
      ref.read(flowProvider.notifier).cropNext();
      return;
    }
    if (!await _adGateAllows(context, ref, state.displayTool)) return;
    // The gate awaits a sheet, so the flow may have been closed or rewound
    // underneath it before this resumes.
    if (!context.mounted) return;
    if (ref.read(flowProvider).step != EditFlow.crop) return;
    ref.read(flowProvider.notifier).cropNext();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PaletteScope.of(context);
    final flow = ref.read(flowProvider.notifier);
    final state = ref.watch(flowProvider);
    final tool = Catalog.toolNamed(state.displayTool);

    return Container(
      color: p.screenBg,
      child: Column(
        children: [
          _OverlayNavBar(
            title: 'Crop',
            titleColor: p.textPrimary,
            leading: AppTextButton(
              label: 'Cancel',
              color: p.textSecondary,
              prominent: false,
              onTap: flow.close,
            ),
            trailing: AppTextButton(
              label: 'Next',
              color: p.accent,
              onTap: () => _cropNext(context, ref),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _canvasMaxWidth),
                  // The canvas re-proportions itself when a ratio is chosen,
                  // which is the whole point of the control below: the chips
                  // used to be decoration on a permanently 3:4 frame. What it
                  // shows here — the photo covering this frame — is exactly
                  // the region that gets cropped out and uploaded.
                  child: AnimatedContainer(
                    duration: context.motion(AppDurations.base),
                    curve: AppDurations.emphasized,
                    child: AspectRatio(
                      aspectRatio: state.displayRatio,
                      child: CustomPaint(
                        foregroundPainter: _CropGridPainter(),
                        child: ClipRRect(
                          borderRadius: AppRadius.brLg,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              EditImage(
                                file: state.photo,
                                scene: tool.scene,
                                variant: DemoVariant.before,
                                seed: tool.seed,
                                art: tool.art,
                              ),
                              // Says whose photo this is. Until something is
                              // uploaded the canvas shows the tool's sample
                              // imagery, and an unlabelled sample is easily
                              // mistaken for the user's own picture.
                              if (state.photo == null)
                                Positioned(
                                  top: AppSpacing.x8,
                                  left: AppSpacing.x8,
                                  child: AppPill.label(
                                    'SAMPLE',
                                    color: AppOverlay.scrimMed,
                                    textStyle: AppText.tag(AppColors.onColor),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.x8,
                                      vertical: AppSpacing.x4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Upload lives here, on the step that shows what it replaces, rather
          // than as another tile on Home: the user sees the frame, the sample
          // it currently holds, and the control that swaps in their own photo
          // in one place.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              0,
              AppSpacing.screenH,
              AppSpacing.x16,
            ),
            child: _UploadControl(hasPhoto: state.photo != null),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              0,
              AppSpacing.screenH,
              AppSpacing.x40,
            ),
            child: _RatioChipRow(
              selected: state.cropRatio,
              onSelect: flow.setCropRatio,
            ),
          ),
        ],
      ),
    );
  }
}

/// The edit's photo control: upload one, or swap the one already loaded.
///
/// Two states, one action. With nothing uploaded it is the step's primary
/// button — the accent CTA, because choosing a photo is the thing to do here.
/// Once a photo is in, it steps back to a ghost pill: the work has moved on to
/// framing it, and replacing it is now the secondary path.
class _UploadControl extends ConsumerWidget {
  final bool hasPhoto;

  const _UploadControl({required this.hasPhoto});

  /// Ceiling on the button width, so it reads as a control under the canvas
  /// rather than a full-bleed page action on a tablet.
  static const double _maxWidth = 260;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PaletteScope.of(context);
    void pick() => choosePhotoForFlow(context, ref);

    if (hasPhoto) {
      return Center(child: GhostPill(label: 'Change photo', onTap: pick));
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: AppButton(
          label: 'Upload a photo',
          onTap: pick,
          color: p.accent,
          labelColor: p.onAccent,
          borderRadius: AppRadius.brPill,
        ),
      ),
    );
  }
}

/// The crop-ratio selector: every frame the edit can be cut to.
class _RatioChipRow extends StatelessWidget {
  final CropRatio selected;
  final ValueChanged<CropRatio> onSelect;

  const _RatioChipRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return AppChipBar(
      chips: [
        for (final ratio in CropRatio.values)
          AppChip(
            label: ratio.label,
            active: ratio == selected,
            onTap: () => onSelect(ratio),
            activeColor: p.accent,
            activeLabel: p.onAccent,
            inactiveColor: p.secondarySurface,
            inactiveLabel: p.textPrimary,
          ),
      ],
    );
  }
}

class _CropGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Rule-of-thirds grid.
    final grid = Paint()
      ..color = AppColors.onColor.withValues(alpha: 0.35)
      ..strokeWidth = AppSizing.strokeHairline;
    for (int i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), grid);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
    }
    // Bright frame outline.
    final frame = Paint()
      ..color = AppOverlay.onDarkHi
      ..strokeWidth = AppSizing.strokeHairline
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, frame);
  }

  @override
  bool shouldRepaint(_CropGridPainter oldDelegate) => false;
}

// ============ TOOL PICKER ============
class _ToolPickStep extends ConsumerWidget {
  const _ToolPickStep();

  /// Choosing a tool here starts the run immediately, so this is where the
  /// gate belongs for a flow that entered without a tool already picked.
  Future<void> _chooseTool(
    BuildContext context,
    WidgetRef ref,
    String tool,
  ) async {
    if (!await _adGateAllows(context, ref, tool)) return;
    if (!context.mounted) return;
    if (ref.read(flowProvider).step != EditFlow.tool) return;
    ref.read(flowProvider.notifier).chooseTool(tool);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PaletteScope.of(context);
    final flow = ref.read(flowProvider.notifier);
    final categories = Catalog.categories;

    return Container(
      color: p.screenBg,
      child: Column(
        children: [
          _OverlayNavBar(
            title: 'Choose a tool',
            titleColor: p.textPrimary,
            borderColor: p.border,
            leading: AppTextButton(
              label: 'Back',
              color: p.accent,
              prominent: false,
              onTap: flow.back,
            ),
            trailing: AppTextButton(
              label: 'Cancel',
              color: p.textSecondary,
              prominent: false,
              onTap: flow.close,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.x20),
              children: [
                for (int i = 0; i < categories.length; i++) ...[
                  Text(
                    categories[i].name,
                    style: AppText.groupLabel(p.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.titleToContent),
                  Wrap(
                    spacing: AppSpacing.itemGap,
                    runSpacing: AppSpacing.itemGap,
                    children: [
                      for (final t in categories[i].tools)
                        _ToolPill(
                          tool: t,
                          onTap: () => _chooseTool(context, ref, t.name),
                        ),
                    ],
                  ),
                  if (i != categories.length - 1)
                    const SizedBox(height: AppSpacing.sectionGap),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One choice in the tool picker.
///
/// Just the name. The tinted glyph these carried was the same abstract mark on
/// every pill in a different colour — it distinguished nothing and told the
/// user nothing about what the tool does, so its removal leaves the label as
/// the thing being read. The description still reaches screen readers.
class _ToolPill extends StatelessWidget {
  final Tool tool;
  final VoidCallback onTap;
  const _ToolPill({required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Semantics(
      button: true,
      label: '${tool.name}. ${tool.desc}',
      child: AppPill(
        color: p.elevated,
        border: Border.all(color: p.cardBorder),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16,
          vertical: AppSpacing.x12,
        ),
        onTap: onTap,
        child: Text(tool.name, style: AppText.badgeLg(p.textPrimary)),
      ),
    );
  }
}

// ============ PROCESSING ============
/// The photo a job is working on — the shared subject shown on both the
/// processing and error surfaces, so a failure keeps the same frame the wait
/// had rather than cutting to a bare message.
class _JobPreview extends StatelessWidget {
  final Tool tool;
  final double ratio;

  /// The user's photo, when the job is a real one.
  final File? photo;

  const _JobPreview({required this.tool, required this.ratio, this.photo});

  /// Width of the preview; its height follows the chosen crop ratio.
  static const double _width = 200;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      child: AspectRatio(
        aspectRatio: ratio,
        child: ClipRRect(
          borderRadius: AppRadius.brXl,
          child: Stack(
            children: [
              Positioned.fill(
                child: EditImage(
                  file: photo,
                  scene: tool.scene,
                  variant: DemoVariant.before,
                  seed: tool.seed,
                  art: tool.art,
                ),
              ),
              Positioned.fill(
                child: ColoredBox(
                  color: AppOverlay.canvas.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessingStep extends ConsumerWidget {
  const _ProcessingStep();

  /// Width of the reveal card and the progress bar beneath it.
  static const double _contentWidth = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PaletteScope.of(context);
    final flow = ref.read(flowProvider.notifier);
    final state = ref.watch(flowProvider);
    final tool = Catalog.toolNamed(state.displayTool);
    final frac = (state.progress / 100).clamp(0.0, 1.0);

    return Container(
      color: p.screenBg,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The edit rendering in real time: the photo upgrades from its
                // dull original to the enhanced result top-down as the job runs,
                // a bright scan edge riding the boundary — so the wait shows the
                // work rather than spinning beside it.
                //
                // On a live job there is no enhanced version to reveal until
                // the model answers, so only the scan edge travels: the app
                // must not paint an "after" it hasn't received.
                Semantics(
                  label: '${state.progress.round()} percent complete',
                  child: _EnhanceReveal(
                    tool: tool,
                    photo: state.photo,
                    live: state.isLive,
                    ratio: state.displayRatio,
                    progress: frac,
                    width: _contentWidth,
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                Text(
                  state.displayTool,
                  textAlign: TextAlign.center,
                  style: AppText.sectionTitle(p.textPrimary),
                ),
                const SizedBox(height: AppSpacing.innerGap),
                // The stage the job is genuinely in — uploading, waiting on the
                // model, downloading — rather than invented "Analyzing…" copy.
                // The simulated pipeline has no stages, so it says only what it
                // is doing.
                Text(
                  state.phase?.label ?? 'Processing your photo',
                  textAlign: TextAlign.center,
                  style: AppText.bodyCompact(p.textSecondary),
                ),
                const SizedBox(height: AppSpacing.titleToContent),
                SizedBox(
                  width: _contentWidth,
                  child: _ProgressBar(value: frac),
                ),
                const SizedBox(height: AppSpacing.innerGap),
                Text(
                  '${state.progress.round()}%',
                  style: AppText.captionMd(p.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                // Cancelling a job returns to the step that configured it,
                // rather than discarding the whole flow — the user wanted to
                // stop *this* run, not start over.
                GhostPill(label: 'Cancel', onTap: flow.back),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The live edit preview on the processing screen — Enhanzo's own take on a
/// progress visual, built around what an enhancer actually does.
///
/// The photo is stacked twice: the dull *before* underneath and the enhanced
/// *after* on top, with the after clipped to the top [progress] of the frame.
/// As the job advances the enhanced version sweeps down over the original, led
/// by a bright scan edge — the picture visibly upgrading. The boundary is tied
/// to real progress (not a decorative loop), so it honestly reports how far the
/// work has got; it glides between the timer's steps unless reduced motion is
/// on, in which case it simply jumps to each reported value.
class _EnhanceReveal extends StatelessWidget {
  final Tool tool;
  final double ratio;
  final double progress; // 0..1
  final double width;

  /// The user's photo, when the job is a real one.
  final File? photo;

  /// True when a model is doing the work. The enhanced layer is then withheld —
  /// it doesn't exist yet — and only the scan edge sweeps the original.
  final bool live;

  const _EnhanceReveal({
    required this.tool,
    required this.ratio,
    required this.progress,
    required this.width,
    this.photo,
    this.live = false,
  });

  /// Height of the soft scan band trailing the bright edge.
  static const double _bandHeight = 44;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: ratio,
        child: ClipRRect(
          borderRadius: AppRadius.brXl,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: progress),
            duration: context.motion(AppDurations.base),
            curve: AppDurations.easeOut,
            builder: (context, value, _) {
              final revealed = value.clamp(0.0, 1.0);
              final scanning = revealed > 0.001 && revealed < 0.999;
              return LayoutBuilder(
                builder: (context, c) {
                  final edgeY = c.maxHeight * revealed;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Dull original underneath.
                      EditImage(
                        file: photo,
                        scene: tool.scene,
                        variant: DemoVariant.before,
                        seed: tool.seed,
                        art: tool.art,
                      ),
                      // Enhanced result, revealed from the top down. Only the
                      // simulated pipeline has one to reveal.
                      if (!live)
                        ClipRect(
                          clipper: _TopClipper(revealed),
                          child: DemoImage(
                            scene: tool.scene,
                            variant: DemoVariant.after,
                            seed: tool.seed,
                            art: tool.art,
                          ),
                        ),
                      // Soft scan band trailing the edge (sits over imagery, so
                      // its white is correct in either theme).
                      if (scanning)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: (edgeY - _bandHeight).clamp(0.0, c.maxHeight),
                          height: _bandHeight,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00FFFFFF), Color(0x3DFFFFFF)],
                              ),
                            ),
                          ),
                        ),
                      // Bright scan edge.
                      if (scanning)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: (edgeY - AppSizing.strokeThin / 2)
                              .clamp(0.0, c.maxHeight),
                          height: AppSizing.strokeThin,
                          child: const ColoredBox(color: AppColors.onColor),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A slim determinate progress track. Adapts to the theme (grey track, accent
/// fill) and eases its fill between the job's reported steps.
class _ProgressBar extends StatelessWidget {
  final double value; // 0..1

  const _ProgressBar({required this.value});

  static const double _height = 8;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return ClipRRect(
      borderRadius: AppRadius.brPill,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            Container(
              width: c.maxWidth,
              height: _height,
              color: p.secondarySurface,
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: value.clamp(0.0, 1.0)),
              duration: context.motion(AppDurations.base),
              curve: AppDurations.easeOut,
              builder: (context, v, _) => Container(
                width: c.maxWidth * v,
                height: _height,
                color: p.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clips a child to the top [fraction] of its box — the enhanced-reveal mask.
class _TopClipper extends CustomClipper<Rect> {
  final double fraction;
  const _TopClipper(this.fraction);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * fraction);

  @override
  bool shouldReclip(_TopClipper old) => old.fraction != fraction;
}

/// The failure surface for a processing job — reached when the flow lands on
/// [EditFlow.error] (the seam `FlowController.fail` exposes for a real backend).
///
/// It mirrors [_ProcessingStep] on the same dark canvas, keeping the job's
/// subject in view, so a failure reads as a continuation of the wait rather
/// than a jarring new screen. Two exits: "Try Again" restarts the run
/// ([FlowController.retry]) and the ghost "Back" returns to the step that
/// configured the job. Nothing is charged for a failed edit and the source
/// photo is untouched, so the copy can promise the photo is safe.
class _ErrorStep extends ConsumerWidget {
  const _ErrorStep();

  /// Ceiling on the action width so the buttons don't stretch to the full inset
  /// on large screens — they stay a compact stack under the message.
  static const double _actionMaxWidth = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PaletteScope.of(context);
    final flow = ref.read(flowProvider.notifier);
    final state = ref.watch(flowProvider);
    final tool = Catalog.toolNamed(state.displayTool);

    return Container(
      color: p.screenBg,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The photo the failed job was working on — same subject the
                // processing step showed, so the failure stays anchored to it.
                _JobPreview(
                  tool: tool,
                  ratio: state.displayRatio,
                  photo: state.photo,
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                // Status glyph. Colour is paired with the icon and the heading
                // below, never carrying the meaning on its own.
                Container(
                  width: AppSizing.emptyGlyph,
                  height: AppSizing.emptyGlyph,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    AppIcons.error,
                    size: AppSizing.iconXxxl,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: AppSpacing.x24),
                Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: AppText.sectionTitle(p.textPrimary),
                ),
                const SizedBox(height: AppSpacing.innerGap),
                // What actually went wrong, when the pipeline knows: a rejected
                // token, an unreachable server and a model that choked on the
                // photo need different responses from the user.
                Text(
                  state.failure ??
                      "This edit didn't finish. Your photo is safe — give it "
                          'another try.',
                  textAlign: TextAlign.center,
                  style: AppText.bodyCompact(p.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _actionMaxWidth),
                  child: AppButton(
                    label: 'Try Again',
                    onTap: flow.retry,
                    color: p.accent,
                    labelColor: p.onAccent,
                    labelStyle: AppText.cta(p.onAccent),
                    borderRadius: AppRadius.brPill,
                  ),
                ),
                const SizedBox(height: AppSpacing.itemGap),
                GhostPill(label: 'Back', onTap: flow.back),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============ RESULT (before/after slider) ============
class _ResultStep extends ConsumerWidget {
  const _ResultStep();

  /// Widest the before/after canvas is allowed to grow on large screens.
  static const double _canvasMaxWidth = 330;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PaletteScope.of(context);
    final flow = ref.read(flowProvider.notifier);
    final state = ref.watch(flowProvider);
    final tool = Catalog.toolNamed(state.displayTool);
    final pos = state.comparePos; // 3..97
    final quality = ref.watch(settingsProvider.select((s) => s.exportQuality));

    return Container(
      color: p.screenBg,
      child: Column(
        children: [
          _OverlayNavBar(
            title: state.displayTool,
            titleColor: p.textPrimary,
            leading: AppCircleIconButton(
              icon: AppIcons.close,
              semanticLabel: 'Close',
              background: p.secondarySurface,
              iconColor: p.textPrimary,
              onTap: flow.close,
            ),
            trailing: AppCircleIconButton(
              icon: AppIcons.share,
              semanticLabel: 'Share',
              background: p.secondarySurface,
              iconColor: p.textPrimary,
              onTap: () => showShareSheet(
                context,
                subject: state.displayTool,
                file: state.result,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x16,
                  vertical: AppSpacing.x12,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _canvasMaxWidth),
                  child: AspectRatio(
                    // The frame chosen on the crop step, honoured here.
                    aspectRatio: state.displayRatio,
                    child: ClipRRect(
                      borderRadius: AppRadius.brXxl,
                      // A real edit compares the exact file that was uploaded
                      // with the exact file the model returned; without one it
                      // falls back to the tool's demo pair.
                      child: BeforeAfterSlider(
                        before: EditImage(
                          file: state.source,
                          scene: tool.scene,
                          variant: DemoVariant.before,
                          seed: tool.seed,
                          art: tool.art,
                        ),
                        after: EditImage(
                          file: state.result,
                          scene: tool.scene,
                          seed: tool.seed,
                          art: tool.art,
                        ),
                        position: pos / 100,
                        onChanged: (v) => flow.setComparePos(v * 100),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // What the edit is.
          //
          // A finished run states what the model actually did — the upscale it
          // applied and whether faces were restored. Only the simulated
          // pipeline shows the export-size chips, because only there is the
          // size still an open choice rather than a fact about a file that
          // already exists.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.x8,
              AppSpacing.screenH,
              AppSpacing.x4,
            ),
            child: state.outputLabel != null
                ? Text(
                    'Enhanced ${state.outputLabel}',
                    textAlign: TextAlign.center,
                    style: AppText.captionMd(p.textSecondary),
                  )
                : _ExportChipRow(
                    selected: quality,
                    onSelect: (q) =>
                        ref.read(settingsProvider.notifier).setExportQuality(q),
                  ),
          ),
          // Bottom actions
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.x14,
              AppSpacing.screenH,
              MediaQuery.of(context).padding.bottom + AppSpacing.x20,
            ),
            child: Row(
              children: [
                AppSquareIconButton(
                  icon: AppIcons.refresh,
                  background: p.secondarySurface,
                  iconColor: p.textPrimary,
                  size: AppSizing.controlLg,
                  iconSize: AppSizing.iconXl,
                  border: Border.all(color: p.border2),
                  onTap: flow.applyAnother,
                ),
                const SizedBox(width: AppSpacing.itemGap),
                Expanded(
                  child: AppButton(
                    label: 'Save to History',
                    color: p.accent,
                    labelColor: p.onAccent,
                    onTap: () {
                      final notify = AppSnack.deferred(context);
                      // A real edit is filed under what the model did; a
                      // simulated one under the chosen export size, which is
                      // all it has.
                      final badge = state.outputLabel ?? quality;
                      ref
                          .read(historyProvider.notifier)
                          .add(
                            tool: state.displayTool,
                            badge: badge,
                            scene: tool.scene,
                            seed: tool.seed,
                            art: tool.art,
                            sourcePath: state.source?.path,
                            resultPath: state.result?.path,
                          );
                      flow.close();
                      _maybeShowInterstitial(ref);
                      AppHaptics.success();
                      // States plainly what happened. The old copy claimed the
                      // file had been written to the device at a given
                      // resolution, which nothing here actually does.
                      notify('Added to History · $badge');
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Export-size selector on the result screen.
class _ExportChipRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _ExportChipRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return AppChipBar(
      chips: [
        for (final quality in AppSettings.qualities)
          AppChip(
            label: quality,
            active: quality == selected,
            onTap: () => onSelect(quality),
            activeColor: p.accent,
            activeLabel: p.onAccent,
            inactiveColor: p.secondarySurface,
            inactiveLabel: p.textSecondary,
          ),
      ],
    );
  }
}
