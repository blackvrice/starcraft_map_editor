import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/recovery_snapshot.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_document.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_recovery_store.dart';

void main() {
  late Directory root;
  late LocalRecoveryStore store;
  String snapshot(String text) => RecoverySnapshot(
    savedAt: DateTime.utc(2026, 10, 3),
    source: EudSourceDocument.untitled(documentId: 'test', initialText: text),
  ).encode();
  setUp(() async {
    root = await Directory.systemTemp.createTemp('recovery_store_');
    store = LocalRecoveryStore(Directory('${root.path}/recovery'));
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'verified generations survive restart; partial and unrelated files are ignored',
    () async {
      final content = snapshot('한글\nline 2');
      await store.write('checkpoint-first', content);
      await File(
        '${store.directory.path}/checkpoint-interrupted.json.partial',
      ).writeAsString('{');
      await File('${store.directory.path}/other.json').writeAsString('{}');
      final restarted = LocalRecoveryStore(store.directory);
      final entries = await restarted.list();
      expect(entries.single.id, 'checkpoint-first');
      expect(entries.single.content, content);
      await expectLater(
        store.write('checkpoint-first', snapshot('replacement')),
        throwsA(isA<FileSystemException>()),
      );
      expect((await store.list()).single.content, content);
      await restarted.remove('checkpoint-first');
      expect(await store.list(), isEmpty);
      expect(await File('${store.directory.path}/other.json').exists(), isTrue);
    },
  );

  test(
    'checksum damage is surfaced and invalid writes cannot displace a good generation',
    () async {
      await store.write('checkpoint-good', snapshot('original'));
      await expectLater(
        store.write('checkpoint-bad', '{'),
        throwsA(isA<Object>()),
      );
      expect((await store.list()).single.id, 'checkpoint-good');
      final file = File('${store.directory.path}/checkpoint-good.json');
      final envelope =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      envelope['content'] = snapshot('tampered');
      await file.writeAsString(jsonEncode(envelope));
      expect((await store.list()).single.content, '');
      await store.remove('checkpoint-good');
      expect(await store.list(), isEmpty);
    },
  );

  test(
    'path traversal and non-directory roots never write outside the store',
    () async {
      await expectLater(
        store.write('../escape', snapshot('x')),
        throwsFormatException,
      );
      await expectLater(store.remove('../escape'), throwsFormatException);
      expect(await File('${root.path}/escape.json').exists(), isFalse);
      final occupied = File('${root.path}/occupied');
      await occupied.writeAsString('keep');
      await expectLater(
        LocalRecoveryStore(
          Directory(occupied.path),
        ).write('checkpoint-test', snapshot('x')),
        throwsA(isA<FileSystemException>()),
      );
      expect(await occupied.readAsString(), 'keep');
    },
  );
}
