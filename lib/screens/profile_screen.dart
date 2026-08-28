import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_info.dart';
import '../data/legal.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../widgets/components/components.dart';
import '../widgets/paywall.dart';
import '../widgets/url_actions.dart';
import 'legal_screen.dart';

/// The Settings tab — redesigned with a personalised header, segmented groups,
/// and a staggered entrance animation.
///
/// Every row here does something. The Cloud Backup and Notifications switches
/// that used to sit in "General" had no backend and no permission prompt behind
/// them — they were controls whose only effect was to change their own colour —
/// and Export Quality is chosen on the result step, beside the image it
/// applies to, rather than twice in two places. What replaced them are the two
/// rows a subscription app actually owes the user: a way to get a purchase
/// back, and a way to pass the app on.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;

  /// Total number of animated sections (header + upgrade card + 3 groups).
  static const int _sectionCount = 5;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: AppDurations.entrance,
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  /// Returns a staggered slide+fade animation for the [index]-th section.
  Animation<double> _sectionAnim(int index) {
    final start = (index / _sectionCount) * 0.5;
    final end = start + 0.5;
    return CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end.clamp(0, 1), curve: AppDurations.decelerate),
    );
  }

  Widget _animatedSection(int index, Widget child) {
    if (!context.motionEnabled) return child;
    return AnimatedBuilder(
      animation: _sectionAnim(index),
      builder: (context, ch) {
        final t = _sectionAnim(index).value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: ch,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final entitlement = ref.watch(entitlementProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.screenTop,
        AppSpacing.screenH,
        AppSpacing.bottomNavClearance,
      ),
      children: [
        // ── Section 0: Profile header ──
        _animatedSection(0, _ProfileHeader(isPro: entitlement.isPro)),

        const SizedBox(height: AppSpacing.sectionGap),

        // ── Section 1: Upgrade card ──
        _animatedSection(
          1,
          _UpgradeCard(
            isPro: entitlement.isPro,
            // Pro users get RevenueCat's Customer Center (manage/cancel);
            // everyone else gets its paywall. Presenting a purchase screen to
            // someone who has already bought is the wrong door.
            onTap: () => _openSubscription(context, entitlement.isPro),
          ),
        ),

        const SizedBox(height: AppSpacing.sectionGap),

        // ── Section 2: Appearance ──
        _animatedSection(
          2,
          SettingsGroup(
            title: 'Appearance',
            tiles: [
              SettingTile(
                icon: dark ? AppIcons.dark : AppIcons.light,
                label: 'Dark Mode',
                onTap: () => ref.read(themeModeProvider.notifier).toggle(),
                trailing: AppSwitch(
                  value: dark,
                  onChanged: (on) => ref
                      .read(themeModeProvider.notifier)
                      .set(on ? ThemeMode.dark : ThemeMode.light),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.itemGap),

        // ── Section 3: Account ──
        _animatedSection(
          3,
          SettingsGroup(
            title: 'Account',
            tiles: [
              SettingTile(
                icon: AppIcons.restore,
                label: 'Restore Purchases',
                value: entitlement.restoring ? 'Restoring…' : null,
                enabled: !entitlement.restoring,
                onTap: () => _restore(context, ref),
              ),
              SettingTile(
                icon: AppIcons.privacy,
                label: 'Privacy Policy',
                onTap: () => LegalScreen.open(
                  context,
                  title: 'Privacy Policy',
                  body: Legal.privacyPolicy,
                ),
              ),
              SettingTile(
                icon: AppIcons.terms,
                label: 'Terms of Use',
                onTap: () => LegalScreen.open(
                  context,
                  title: 'Terms of Use',
                  body: Legal.termsOfUse,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.itemGap),

        // ── Section 4: Share & Rate ──
        _animatedSection(
          4,
          SettingsGroup(
            title: 'About',
            tiles: [
              SettingTile(
                icon: AppIcons.share,
                label: 'Share App',
                onTap: () => _shareApp(context),
              ),
              SettingTile(
                icon: AppIcons.rate,
                label: 'Rate ${AppInfo.shortName}',
                // Opens the Play listing. This used to show a thank-you
                // snackbar and do nothing else — a rating prompt that never
                // reached the store.
                onTap: () => openExternalUrl(context, AppInfo.reviewLink),
              ),
            ],
          ),
        ),

      ],
    );
  }

  /// Hands the invite to the OS share sheet and reports anything that stops it.
  Future<void> _shareApp(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: AppInfo.shareMessage,
          subject: AppInfo.name,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        AppSnack.show(context, "Couldn't open the share sheet just now.");
      }
    }
  }

  /// Opens RevenueCat's paywall, or its Customer Center once the user is
  /// premium.
  ///
  /// Reports a presentation failure rather than swallowing it: without this
  /// the upgrade card is a dead tap whenever no paywall is published for the
  /// current offering, or this build has no RevenueCat key.
  ///
  /// Whatever the user did in there, the entitlement is re-read on the way
  /// out. RevenueCat's `CustomerInfo` listener normally reports a purchase on
  /// its own, but it is only listening if configuring the SDK succeeded during
  /// startup — and the paywall configures it again itself, so the SDK can end
  /// up usable but unwatched. Asking [EntitlementController.refresh]
  /// directly closes that gap: the badge below flips as soon as this returns,
  /// not on the next launch.
  Future<void> _openSubscription(BuildContext context, bool isPro) async {
    final entitlements = ref.read(entitlementProvider.notifier);

    if (isPro) {
      await showCustomerCenter();
      // A cancellation or a plan change made in there changes what the user
      // owns, and this screen is what they come back to.
      await entitlements.refresh();
      return;
    }

    final outcome = await showPaywall();
    if (outcome == PaywallResult.purchased ||
        outcome == PaywallResult.restored) {
      await entitlements.refresh();
    }
    if (!context.mounted) return;
    switch (outcome) {
      case PaywallResult.purchased:
        HapticFeedback.selectionClick();
        AppSnack.show(context, "You're Premium — every tool is unlocked.");
      case PaywallResult.restored:
        AppSnack.show(context, 'Purchases restored. Premium is active.');
      case PaywallResult.error:
        AppSnack.show(
          context,
          "Couldn't open subscriptions right now. Please try again.",
        );
      // Dismissed without buying, or never shown. Nothing happened, so
      // nothing to say.
      case PaywallResult.cancelled:
      case PaywallResult.notPresented:
        break;
    }
  }

  /// Re-reads the stored entitlement and reports what came back.
  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final outcome = await ref.read(entitlementProvider.notifier).restore();
    if (!context.mounted) return;
    switch (outcome) {
      case PurchaseOutcome.success:
        HapticFeedback.selectionClick();
        AppSnack.show(context, 'Purchases restored. Premium is active.');
      case PurchaseOutcome.noneFound:
        AppSnack.show(context, 'No previous purchases found.');
      case PurchaseOutcome.failed:
        AppSnack.show(context, "Couldn't restore right now. Please try again.");
      // A restore already in flight — the row is disabled, so this is only
      // reachable from a double tap that beat the rebuild. Nothing to say.
      case PurchaseOutcome.busy:
        break;
    }
  }

}

/// Personalised header at the top of Settings — a gradient avatar circle with
/// initials, a greeting, and the Pro badge status.
class _ProfileHeader extends StatelessWidget {
  final bool isPro;

  const _ProfileHeader({required this.isPro});

  static const double _avatarSize = 72;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Column(
      children: [
        // Gradient avatar circle
        Container(
          width: _avatarSize,
          height: _avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                p.accent,
                p.accent.withValues(alpha: 0.6),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: p.accent.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            AppIcons.settings,
            color: p.onAccent,
            size: AppSizing.iconXxl,
          ),
        ),
        const SizedBox(height: AppSpacing.titleToContent),
        Text('Settings', style: AppText.largeTitle(p.textPrimary)),
        const SizedBox(height: AppSpacing.tightGap),
        // Pro badge or status line
        AnimatedSwitcher(
          duration: context.motion(AppDurations.quick),
          child: isPro
              ? AppPill.label(
                  '✨ PREMIUM USER',
                  key: const ValueKey('premium'),
                  color: p.accent,
                  textStyle: AppText.badge(p.onAccent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x12,
                    vertical: AppSpacing.x6,
                  ),
                )
              // Nothing under the title for free users — an active
              // subscription is the only status worth stating here.
              : const SizedBox.shrink(key: ValueKey('free')),
        ),
      ],
    );
  }
}

/// The subscription card at the top of Settings.
///
/// It used to be a one-line banner — a title, a sentence of run-together
/// claims and a chevron — which asked for a subscription without ever showing
/// what one contains. This states the offer the way the paywall does: an
/// eyebrow that names the product, a single promise, then the three things Pro
/// actually includes, each on its own line so the eye can land on them. The
/// claims come from [AppInfo.proBenefits], the same list the paywall reads, so
/// the two screens cannot advertise different products.
///
/// Once the user is Pro the card stops selling and confirms instead — it is
/// still tappable, because that is where a subscription is managed.
class _UpgradeCard extends StatelessWidget {
  final bool isPro;
  final VoidCallback onTap;

  const _UpgradeCard({required this.isPro, required this.onTap});

  /// The circular chevron affordance — sized to the title beside it.
  static const double _chevronSize = 32;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    final onInk = p.onAccent;
    final onInkQuiet = p.onAccent.withValues(alpha: 0.74);

    return Semantics(
      button: true,
      label: isPro
          ? '${AppInfo.name} Pro is active. Manage your subscription'
          : 'Upgrade to ${AppInfo.name} Pro',
      child: ExcludeSemantics(
        child: AppPressable(
          onTap: onTap,
          depth: PressDepth.card,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.x20),
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: AppRadius.brXxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${AppInfo.shortName.toUpperCase()} PRO',
                            style: AppText.overline(onInkQuiet),
                          ),
                          const SizedBox(height: AppSpacing.innerGap),
                          Text(
                            isPro
                                ? 'Your subscription is active'
                                : 'Unlock every AI tool',
                            style: AppText.cardTitle(onInk),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.itemGap),
                    // Signifier, not a target of its own — the whole card
                    // opens the paywall.
                    Container(
                      width: _chevronSize,
                      height: _chevronSize,
                      decoration: BoxDecoration(
                        color: onInk.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.chevronRight,
                        color: onInk,
                        size: AppSizing.iconLg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.titleToContent),
                if (isPro)
                  Text(
                    'Thanks for your support — every tool is unlocked, and '
                    'exports run up to 8K.',
                    style: AppText.captionLg(onInkQuiet),
                  )
                else
                  for (int i = 0; i < AppInfo.proBenefits.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.innerGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          AppIcons.check,
                          size: AppSizing.iconSm,
                          color: onInk,
                        ),
                        const SizedBox(width: AppSpacing.innerGap),
                        Expanded(
                          child: Text(
                            AppInfo.proBenefits[i],
                            style: AppText.captionLg(onInk),
                          ),
                        ),
                      ],
                    ),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
