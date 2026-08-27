import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Housekeeping for the on-device folder every finished edit is written to.
///
/// Each enhance run saves two files under app documents — the cropped source
/// that was uploaded and the image the model returned. Nothing removed them.
/// History lives only in memory, so after a relaunch its entries are gone
/// while the files remain: orphaned, invisible in the UI, and unreachable by
/// any code that could clean them up. Left alone that grows without bound for
/// as long as the app is installed.
///
/// It also made the Privacy Policy untrue on two counts — that generated
/// images "are typically stored for about 30 days ... after which they may be
/// automatically deleted", and that deleting them in the app removes them.
/// [purgeExpired] is what makes the first of those actually happen.
class EditsStore {
  EditsStore._();

  /// Matches the retention stated in the Privacy Policy. Changing one without
  /// the other puts the app back out of step with what it promises users.
  static const Duration retention = Duration(days: 30);

  /// Where finished edits live: inside app documents, so they survive relaunch
  /// and can be handed to the OS share sheet by path.
  static Future<Directory> directory() async {
    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory('${documents.path}/edits');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Deletes saved edits older than [retention].
  ///
  /// Best-effort and never throws: this is background tidying, and a file that
  /// can't be read or removed (locked, already gone, permissions) must not
  /// take the app down with it. Returns how many files were removed, which is
  /// what the test asserts against.
  static Future<int> purgeExpired({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(retention);
    var removed = 0;
    try {
      final dir = await directory();
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        try {
          if ((await entity.lastModified()).isBefore(cutoff)) {
            await entity.delete();
            removed++;
          }
        } catch (_) {
          // Skip this one and keep going — one bad file shouldn't stop the
          // sweep from clearing the rest.
        }
      }
    } catch (_) {
      // No documents directory available (a plain Dart test host, say).
    }
    return removed;
  }

  /// Deletes the files behind one history entry.
  ///
  /// Called when a delete the user asked for becomes final — after the undo
  /// window has closed without being used, not the moment the row disappears,
  /// or an undo would restore an entry whose images were already gone.
  ///
  /// Missing and already-deleted paths are ignored, so this is safe for a
  /// simulated edit that never wrote anything to disk.
  static Future<void> deleteFiles(Iterable<String?> paths) async {
    for (final path in paths) {
      if (path == null || path.isEmpty) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Best-effort: the 30-day sweep will catch anything left behind.
      }
    }
  }
}
