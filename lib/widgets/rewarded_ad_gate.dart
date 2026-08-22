import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/ads_state.dart';
import '../theme/theme.dart';
import 'components/components.dart';

/// What the user decided in [showRewardedAdGate].
enum AdGateResult {
  /// An ad was watched through to completion — unlock the one thing this
  /// gate was for, immediately. Never returned for a merely-opened ad; see
  /// [RewardedAdService].
  rewardEarned,

  /// The user chose Premium instead of watching an ad. The caller should
  /// open the paywall — this sheet never does that itself, since what
  /// "Premium" means (which screen, which plan) is the caller's call, not
  /// this generic gate's.
  choseGoPremium,

  /// The sheet was dismissed without either choice — do nothing.
  dismissed,
}

/// The "Watch Ad to Continue" / "Go Premium" choice, as a reusable gate in
/// front of any single free action.
///
/// This is deliberately generic: it doesn't know or care what it's gating —
/// callers pass [actionVerb] (e.g. `'Generate'`, `'Enhance'`) and the copy
/// follows. Wiring it to a real action is exactly two steps: call this, then
/// act on the result —
///
/// ```dart
/// final result = await showRewardedAdGate(context, ref, actionVerb: 'Generate');
/// switch (result) {
///   case AdGateResult.rewardEarned: // run the one free generation
///   case AdGateResult.choseGoPremium: // open the paywall
///   case AdGateResult.dismissed: // do nothing
/// }
/// ```
///
/// Neither path is ever forced on the user — declining the ad always leaves
/// Premium visible, and declining both just closes the sheet with no
/// consequence.
Future<AdGateResult> showRewardedAdGate(
  BuildContext context,
  WidgetRef ref, {
  required String actionVerb,
}) async {
  // [adGateProvider] outlives the sheet, so a failure from a previous attempt
  // is still in its state when this one opens. Without this the gate would
  // greet the user with "No ad right now — Try Again" before they had asked
  // for anything, for an attempt that never happened.
  ref.read(adGateProvider.notifier).reset();

  final result = await showAppSheet<AdGateResult>(
    context,
    isScrollControlled: true,
    builder: (sheetContext) => _RewardedAdGateSheet(actionVerb: actionVerb),
  );
  return result ?? AdGateResult.dismissed;
}

class _RewardedAdGateSheet extends ConsumerWidget {
  final String actionVerb;

  const _RewardedAdGateSheet({required this.actionVerb});

  Future<void> _watchAd(BuildContext context, WidgetRef ref) async {
    final earned = await ref.read(adGateProvider.notifier).watch();
    if (!context.mounted) return;
    if (earned) {
      Navigator.of(context).pop(AdGateResult.rewardEarned);
    }
    // A dismissed-early or unavailable ad leaves the sheet open — the status
    // read below switches it to the failure/retry state, or simply lets the
    // user try again, rather than closing out from under them.
  }

  void _goPremium(BuildContext context) {
    Navigator.of(context).pop(AdGateResult.choseGoPremium);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PaletteScope.of(context);
    final status = ref.watch(adGateProvider).status;
    final loading = status == AdGateStatus.loading;
    final failed = status == AdGateStatus.failed;

    return AppBottomSheet(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: AppSizing.controlLg,
            height: AppSizing.controlLg,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              failed ? AppIcons.error : AppIcons.playCircle,
              color: failed ? AppColors.danger : p.accent,
              size: AppSizing.iconXxl,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.titleToContent),
        Text(
          failed ? 'No ad right now' : 'One free $actionVerb',
          textAlign: TextAlign.center,
          style: AppText.sheetTitle(p.textPrimary),
        ),
        const SizedBox(height: AppSpacing.innerGap),
        Text(
          failed
              ? "We couldn't load an ad just now — try again in a moment, or skip straight to Premium."
              : 'Watch a short ad to unlock this one, or go Premium for unlimited, ad-free access.',
          textAlign: TextAlign.center,
          style: AppText.captionLg(p.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        AppButton(
          label: failed ? 'Try Again' : 'Watch Ad to $actionVerb',
          onTap: () => _watchAd(context, ref),
          loading: loading,
          color: p.accent,
          labelColor: p.onAccent,
        ),
        const SizedBox(height: AppSpacing.itemGap),
        GhostPill(
          label: 'Go Premium — $actionVerb Without Ads',
          // Always available, even mid-load: choosing Premium is never
          // blocked by an ad the user has changed their mind about waiting
          // for. Nothing was granted by starting that load, so abandoning it
          // here costs the user nothing.
          onTap: () => _goPremium(context),
        ),
      ],
    );
  }
}
