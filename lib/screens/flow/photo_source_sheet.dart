import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/image_ops.dart';
import '../../data/photo_library.dart';
import '../../state/app_state.dart';
import '../../theme/theme.dart';
import '../../widgets/components/components.dart';

/// Puts a photo into the running edit flow.
///
/// Asks where it comes from, gets it, reads its proportions, and hands it to
/// [FlowController.setPhoto]. The crop step uses this both for the first upload
/// and for replacing one, so choosing and swapping a photo behave identically.
///
/// A dismissed sheet or a cancelled picker leaves the flow exactly as it was.
Future<void> choosePhotoForFlow(BuildContext context, WidgetRef ref) async {
  final source = await _askSource(context);
  if (source == null) return;

  final flow = ref.read(flowProvider.notifier);
  // Captured while the context is current: the picker is a platform round-trip,
  // and this reports a denied permission after it.
  final notify = context.mounted
      ? AppSnack.deferred(context, overlay: true)
      : null;

  try {
    final photo = await PhotoLibrary.pick(source: source);
    if (photo == null) return; // The user backed out of the picker.

    // The crop canvas needs the photo's proportions before it can lay anything
    // out, and reading them here keeps that off the first frame that shows it.
    final aspect = await ImageOps.aspectRatioOf(photo);
    flow.setPhoto(photo, aspect: aspect);
  } on PhotoPickException catch (error) {
    notify?.call(error.message);
  }
}

/// Where the photo comes from. Null when the sheet is dismissed.
Future<PhotoSource?> _askSource(BuildContext context) {
  return showAppSheet<PhotoSource>(
    context,
    builder: (sheetContext) => _SourceSheet(
      onPick: (source) => Navigator.of(sheetContext).pop(source),
    ),
  );
}

class _SourceSheet extends StatelessWidget {
  final ValueChanged<PhotoSource> onPick;

  const _SourceSheet({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return AppBottomSheet(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose a photo',
          textAlign: TextAlign.center,
          style: AppText.sheetTitle(p.textPrimary),
        ),
        const SizedBox(height: AppSpacing.titleToContent),
        Row(
          children: [
            Expanded(
              child: SheetActionButton(
                icon: AppIcons.photos,
                label: 'Library',
                onTap: () => onPick(PhotoSource.gallery),
              ),
            ),
            const SizedBox(width: AppSpacing.itemGap),
            Expanded(
              child: SheetActionButton(
                icon: AppIcons.camera,
                label: 'Camera',
                onTap: () => onPick(PhotoSource.camera),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
