// Saved edits must not pile up forever.
//
// Every enhance writes a source and a result file into app documents, and
// HistoryController keeps its list only in memory — so after a relaunch the
// entries are gone while the files remain, invisible in the UI and unreachable
// by any code. Nothing deleted them, so an install grew without bound, and the
// Privacy Policy's claim that generated images "may be automatically deleted"
// after about 30 days was untrue.

import 'dart:io';

import 'package:ai_enhancer/data/edits_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Points path_provider at a real temp directory for the duration of a test.
class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('edits_store_test');
    PathProviderPlatform.instance = _TempPathProvider(root.path);
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  /// Writes a file into the edits directory and backdates it by [age].
  Future<File> writeEdit(String name, Duration age) async {
    final dir = await EditsStore.directory();
    final file = File('${dir.path}/$name')..writeAsBytesSync([1, 2, 3]);
    file.setLastModifiedSync(DateTime.now().subtract(age));
    return file;
  }

  test('deletes edits past the retention window', () async {
    final stale = await writeEdit('old_result.png', const Duration(days: 31));

    final removed = await EditsStore.purgeExpired();

    expect(removed, 1);
    expect(stale.existsSync(), isFalse);
  });

  test('keeps edits inside the retention window', () async {
    final fresh = await writeEdit('new_result.png', const Duration(days: 29));
    final today = await writeEdit('today_result.png', Duration.zero);

    final removed = await EditsStore.purgeExpired();

    expect(removed, 0);
    expect(fresh.existsSync(), isTrue);
    expect(today.existsSync(), isTrue);
  });

  test('sweeps only what has expired, leaving the rest', () async {
    final stale = await writeEdit('a_source.png', const Duration(days: 90));
    final alsoStale = await writeEdit('a_result.png', const Duration(days: 45));
    final keep = await writeEdit('b_result.png', const Duration(days: 2));

    final removed = await EditsStore.purgeExpired();

    expect(removed, 2);
    expect(stale.existsSync(), isFalse);
    expect(alsoStale.existsSync(), isFalse);
    expect(keep.existsSync(), isTrue);
  });

  test('an empty or missing directory is not an error', () async {
    expect(await EditsStore.purgeExpired(), 0);
  });

  group('deleteFiles — the user-initiated delete', () {
    test('removes both files behind an entry', () async {
      final source = await writeEdit('x_source.png', Duration.zero);
      final result = await writeEdit('x_result.png', Duration.zero);

      await EditsStore.deleteFiles([source.path, result.path]);

      expect(source.existsSync(), isFalse);
      expect(result.existsSync(), isFalse);
    });

    test('tolerates nulls and paths that are already gone', () async {
      final gone = await writeEdit('gone.png', Duration.zero);
      gone.deleteSync();

      // A simulated edit writes nothing, so its paths are null — deleting it
      // must not throw.
      await expectLater(
        EditsStore.deleteFiles([null, '', gone.path, '/no/such/file.png']),
        completes,
      );
    });

    test('leaves other edits alone', () async {
      final target = await writeEdit('target_result.png', Duration.zero);
      final bystander = await writeEdit('other_result.png', Duration.zero);

      await EditsStore.deleteFiles([target.path]);

      expect(target.existsSync(), isFalse);
      expect(bystander.existsSync(), isTrue);
    });
  });

  test('retention matches what the Privacy Policy states', () {
    // The policy says "about 30 days". If one moves, the other has to.
    expect(EditsStore.retention, const Duration(days: 30));
  });

  test('a documents directory that cannot be read is survivable', () async {
    // Startup housekeeping must never take the app down.
    PathProviderPlatform.instance = _ThrowingPathProvider();
    expect(await EditsStore.purgeExpired(), 0);
  });
}

class _ThrowingPathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    throw PlatformException(code: 'unavailable');
  }
}
