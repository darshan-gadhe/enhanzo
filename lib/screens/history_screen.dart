import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../widgets/components/components.dart';
import '../widgets/demo_image.dart';
import '../widgets/edit_image.dart';
import '../widgets/share_sheet.dart';

/// 'Today' / 'Yesterday' / 'Mar 8' style group label.
String _dateLabel(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[time.month - 1]} ${time.day}';
}

/// '2:14 PM' style time label.
String _timeLabel(DateTime time) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  /// Shape of one history tile — a near-square preview above the two-line
  /// identity block.
  static const double _tileAspectRatio = 0.83;

  /// The user's text scale, capped.
  ///
  /// Past ~1.4 the tiles would be taller than they are wide and stop reading as
  /// a grid; the labels ellipsise beyond that point anyway.
  static double _textScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PaletteScope.of(context);
    final entries = ref.watch(historyProvider);

    // Empty: the header sits at the top and a rich, centred prompt owns the
    // rest of the viewport rather than a top-anchored icon-and-caption block.
    if (entries.isEmpty) {
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.screenTop,
              AppSpacing.screenH,
              0,
            ),
            child: ScreenHeader(title: 'History'),
          ),
          Expanded(
            child: _HistoryEmptyState(
              onStart: () => ref.read(flowProvider.notifier).startUpload(),
            ),
          ),
        ],
      );
    }

    // Group consecutive entries by calendar day (list is newest first).
    final groups = <(String, List<HistoryEntry>)>[];
    for (final e in entries) {
      final label = _dateLabel(e.time);
      if (groups.isEmpty || groups.last.$1 != label) {
        groups.add((label, [e]));
      } else {
        groups.last.$2.add(e);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.screenTop,
        AppSpacing.screenH,
        AppSpacing.bottomNavClearance,
      ),
      children: [
        ScreenHeader(
          title: 'History',
          subtitle: entries.length == 1 ? '1 edit' : '${entries.length} edits',
        ),
        for (int g = 0; g < groups.length; g++) ...[
          // The first group sits under the header's hairline, so it gets the
          // header's own gap rather than a full section break.
          SizedBox(
            height: g == 0 ? AppSpacing.itemGap : AppSpacing.sectionGap,
          ),
          Text(groups[g].$1, style: AppText.groupLabel(p.textSecondary)),
          const SizedBox(height: AppSpacing.titleToContent),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 600 ? 3 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.itemGap,
                crossAxisSpacing: AppSpacing.itemGap,
                // The tile is a fixed-ratio box holding two lines of text under
                // an image, so raising the text size has to make it taller or
                // the labels collide with the preview. Dividing the ratio by the
                // scale grows height while width stays column-bound.
                childAspectRatio: _tileAspectRatio / _textScale(context),
                children: [
                  for (final e in groups[g].$2)
                    _HistoryCard(
                      entry: e,
                      onTap: () => _showDetail(context, ref, e.id),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref, int id) {
    showAppSheet<void>(
      context,
      isScrollControlled: true,
      builder: (_) => _DetailSheet(entryId: id),
    );
  }
}

/// The History tab's first-run state: a fanned stack of sample edits over a
/// short prompt and the action that creates the first real one.
///
/// Vertically centred in whatever space the header leaves, and wrapped in a
/// scroll view so it keeps its shape on short screens and at large text sizes
/// instead of overflowing.
class _HistoryEmptyState extends StatelessWidget {
  final VoidCallback onStart;

  const _HistoryEmptyState({required this.onStart});

  /// Widest the action is allowed to grow — a full-bleed button under a centred
  /// column reads as a page CTA rather than part of the empty state.
  static const double _actionMaxWidth = 240;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    // A minimum-height box inside a scroll view centres the column when it fits
    // the space the header leaves and lets it scroll when it doesn't. It has to
    // be this rather than SliverFillRemaining(hasScrollBody: false), which sizes
    // itself from the child's intrinsic height — a measurement the LayoutBuilder
    // inside the fanned preview can't answer.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x32,
              AppSpacing.x24,
              AppSpacing.x32,
              AppSpacing.bottomNavClearance,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _FannedPreview(),
                const SizedBox(height: AppSpacing.sectionGap),
                Text(
                  'No edits yet',
                  textAlign: TextAlign.center,
                  style: AppText.emptyTitle(p.textPrimary),
                ),
                const SizedBox(height: AppSpacing.innerGap),
                Text(
                  'Your finished edits collect here, so you can revisit or '
                  'share them any time.',
                  textAlign: TextAlign.center,
                  style: AppText.captionLg(p.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _actionMaxWidth),
                  child: AppButton(
                    label: 'Start an edit',
                    onTap: onStart,
                    color: p.accent,
                    labelColor: p.onAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three sample edits fanned like a small stack of prints — the visual promise
/// of what the tab fills up with. Purely decorative, so it's hidden from
/// assistive tech; the title and message carry the meaning.
class _FannedPreview extends StatelessWidget {
  const _FannedPreview();

  /// The three scenes shown, chosen for variety — a place, a face, a mood — so
  /// the stack reads as "your different edits", not one repeated thumbnail.
  static const List<(DemoScene, int)> _cards = [
    (DemoScene.landscape, 3),
    (DemoScene.portrait, 1),
    (DemoScene.sunset, 5),
  ];

  /// Fan geometry: how far the side prints slide out, drop down and tilt.
  static const double _tilt = 0.12; // radians (~7°)

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Cap the footprint so the stack doesn't balloon on tablets, and
          // derive every dimension from it so it scales cleanly on small
          // phones.
          final w = constraints.maxWidth.clamp(0.0, 300.0);
          final cardW = w * 0.42;
          final cardH = cardW * 1.28;
          final dx = cardW * 0.56;
          final dy = cardH * 0.10;

          Widget card(int i) => _PhotoCard(
            scene: _cards[i].$1,
            seed: _cards[i].$2,
            width: cardW,
            height: cardH,
          );

          return SizedBox(
            width: w,
            height: cardH + dy * 2 + AppSpacing.x12,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: Offset(-dx, dy),
                  child: Transform.rotate(angle: -_tilt, child: card(0)),
                ),
                Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.rotate(angle: _tilt, child: card(2)),
                ),
                card(1),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One print in the [_FannedPreview]: a rounded demo scene inside a white
/// border. The border is white in both themes so the stack always reads as
/// prints — on light the resting shadow separates it, on dark the white edge
/// does.
class _PhotoCard extends StatelessWidget {
  final DemoScene scene;
  final int seed;
  final double width;
  final double height;

  const _PhotoCard({
    required this.scene,
    required this.seed,
    required this.width,
    required this.height,
  });

  static const double _frame = 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(_frame),
      decoration: const BoxDecoration(
        color: AppColors.onColor,
        borderRadius: AppRadius.brXl,
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl - _frame),
        child: DemoImage(scene: scene, seed: seed),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;

  const _HistoryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Semantics(
      button: true,
      label: '${entry.tool}, ${entry.badge}, ${_timeLabel(entry.time)}',
      child: AppCard(
        borderRadius: AppRadius.brXl,
        clip: true,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EditImage(
                    file: entry.resultPath == null
                        ? null
                        : File(entry.resultPath!),
                    scene: entry.scene,
                    seed: entry.seed,
                    art: entry.art,
                  ),
                  Positioned(
                    top: AppSpacing.x8,
                    left: AppSpacing.x8,
                    child: AppPill.label(
                      entry.badge,
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
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x12,
                vertical: AppSpacing.x12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.tool, style: AppText.tileTitle(p.textPrimary)),
                  const SizedBox(height: AppSpacing.tightGap),
                  Text(
                    _timeLabel(entry.time),
                    style: AppText.captionSm(p.textSecondary),
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

/// Bottom sheet with a large preview and actions for one history entry.
class _DetailSheet extends ConsumerWidget {
  final int entryId;

  const _DetailSheet({required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PaletteScope.of(context);
    final entries = ref.watch(historyProvider);
    HistoryEntry? found;
    for (final e in entries) {
      if (e.id == entryId) {
        found = e;
        break;
      }
    }
    if (found == null) return const SizedBox.shrink();
    final entry = found;

    final history = ref.read(historyProvider.notifier);

    return AppBottomSheet(
      children: [
        ClipRRect(
          borderRadius: AppRadius.brXl,
          child: AspectRatio(
            aspectRatio: kToolArtAspect,
            child: entry.hasImages
                ? BeforeAfterSlider(
                    before: EditImage(
                      file: entry.sourcePath == null
                          ? null
                          : File(entry.sourcePath!),
                      scene: entry.scene,
                      variant: DemoVariant.before,
                      seed: entry.seed,
                      art: entry.art,
                    ),
                    after: EditImage(
                      file: File(entry.resultPath!),
                      scene: entry.scene,
                      seed: entry.seed,
                      art: entry.art,
                    ),
                  )
                : DemoImage(
                    scene: entry.scene,
                    seed: entry.seed,
                    art: entry.art,
                  ),
          ),
        ),
        // Preview → identity → actions. Sheets run on titleToContent
        // throughout the app; a full section break is too heavy in one.
        const SizedBox(height: AppSpacing.titleToContent),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.tool, style: AppText.sheetTitle(p.textPrimary)),
                  const SizedBox(height: AppSpacing.tightGap),
                  Text(
                    '${_dateLabel(entry.time)} · ${_timeLabel(entry.time)}'
                    ' · ${entry.badge}',
                    style: AppText.captionMd(p.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.titleToContent),
        Row(
          children: [
            Expanded(
              child: SheetActionButton(
                icon: AppIcons.adjust,
                label: 'Edit again',
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(flowProvider.notifier).pickTool(entry.tool);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.itemGap),
            Expanded(
              child: SheetActionButton(
                icon: AppIcons.share,
                label: 'Share',
                onTap: () {
                  Navigator.of(context).pop();
                  showShareSheet(
                    context,
                    subject: entry.tool,
                    file: entry.resultPath == null
                        ? null
                        : File(entry.resultPath!),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.itemGap),
            Expanded(
              child: SheetActionButton(
                icon: AppIcons.delete,
                label: 'Delete',
                destructive: true,
                onTap: () {
                  // Deleting one edit is low-stakes and instantly reversible,
                  // so it offers an undo rather than a confirmation dialog:
                  // a modal would tax every deletion to guard against the rare
                  // mistaken one. The index is captured first so undo can put
                  // the entry back in its own day group.
                  final index = entries.indexWhere((e) => e.id == entry.id);
                  final undo = AppSnack.undoable(context);
                  Navigator.of(context).pop();
                  history.remove(entry.id);
                  undo(
                    'Edit deleted',
                    actionLabel: 'Undo',
                    onAction: () => history.restore(entry, index),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
