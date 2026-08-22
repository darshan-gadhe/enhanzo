import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_info.dart';
import '../data/catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme.dart';
import '../widgets/components/components.dart';
import '../widgets/demo_image.dart' show kToolArtAspect;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// The four marquee tools promoted to the 2×2 grid at the top of Home. Named
  /// (rather than positional) so the grid always launches the catalog entry it
  /// shows, and so these can be excluded from the list below without a second
  /// source of truth. Order here is the order they appear in the grid.
  static const List<String> _topToolNames = [
    'AI Enhance',
    'HD Upscale',
    'Restore Photo',
    'Object Removal',
  ];

  void _launch(WidgetRef ref, String tool) {
    // Straight into the flow: the photo is chosen on the crop step, where the
    // upload control lives.
    ref.read(flowProvider.notifier).pickTool(tool);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topTools = [for (final name in _topToolNames) Catalog.toolNamed(name)];
    final promoted = _topToolNames.toSet();

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.bottomNavClearance),
      children: [
        // Top bar: the wordmark alone.
        //
        // The upgrade pill that used to sit here is gone: Settings already
        // carries the offer in a card that can actually make the case, and a
        // permanent "Get Pro" chip over every session sells on a screen the
        // user came to *work* on.
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.screenTop,
            AppSpacing.screenH,
            0,
          ),
          child: ScreenHeader(
            title: AppInfo.shortName,
            titleStyle: AppText.wordmark,
          ),
        ),

        // The four most-reached-for tools, up top in a 2×2 grid — the fast lane
        // into the app's core edits.
        const SizedBox(height: AppSpacing.itemGap),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: SectionTitleRow('Most used'),
        ),
        const SizedBox(height: AppSpacing.titleToContent),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: _TopToolsGrid(
            tools: topTools,
            onTap: (t) => _launch(ref, t.name),
          ),
        ),

        // Everything else, grouped by category as a single column of full-width
        // cards — the same rows the Tools tab uses, minus the promoted four.
        for (final category in Catalog.categories) ...[
          () {
            final rest = category.tools
                .where((t) => !promoted.contains(t.name))
                .toList();
            if (rest.isEmpty) return const SizedBox.shrink();
            return _ToolSection(
              category: category.name,
              tools: rest,
              onTap: (t) => _launch(ref, t.name),
            );
          }(),
        ],
      ],
    );
  }
}

/// One category's remaining tools rendered as the Tools-page single-column
/// list: a section title with a count over a stack of full-width [ToolCard]s.
class _ToolSection extends StatelessWidget {
  final String category;
  final List<Tool> tools;
  final ValueChanged<Tool> onTap;

  const _ToolSection({
    required this.category,
    required this.tools,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = '${tools.length} ${tools.length == 1 ? 'tool' : 'tools'}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sectionGap),
          SectionTitleRow(category, trailing: count),
          const SizedBox(height: AppSpacing.titleToContent),
          for (int i = 0; i < tools.length; i++) ...[
            ToolCard(tool: tools[i], onTap: () => onTap(tools[i])),
            if (i != tools.length - 1)
              const SizedBox(height: AppSpacing.itemGap),
          ],
        ],
      ),
    );
  }
}

/// The promoted tools at the top of Home. Responsive: 1 column on narrow
/// screens (<340px), 2 on phones, 3 on tablets (>600px). Each tile is sized to
/// the artwork's 3:2 ratio so the photography is never cropped and tiles in a
/// row always agree on size without an intrinsic pass.
class _TopToolsGrid extends StatelessWidget {
  final List<Tool> tools;
  final ValueChanged<Tool> onTap;

  const _TopToolsGrid({required this.tools, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width < 340 ? 1 : width > 600 ? 3 : 2;

        Widget tile(Tool tool) => AspectRatio(
          aspectRatio: kToolArtAspect,
          child: ToolGridTile(tool: tool, onTap: () => onTap(tool)),
        );

        final rows = <Widget>[];
        for (int i = 0; i < tools.length; i += cols) {
          if (rows.isNotEmpty) {
            rows.add(const SizedBox(height: AppSpacing.itemGap));
          }
          final rowChildren = <Widget>[];
          for (int j = 0; j < cols; j++) {
            if (j > 0) {
              rowChildren.add(const SizedBox(width: AppSpacing.itemGap));
            }
            if (i + j < tools.length) {
              rowChildren.add(Expanded(child: tile(tools[i + j])));
            } else {
              rowChildren.add(const Expanded(child: SizedBox.shrink()));
            }
          }
          rows.add(Row(children: rowChildren));
        }
        return Column(children: rows);
      },
    );
  }
}

