import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:artpulse/core/graphics/art_engine.dart';
import 'package:artpulse/core/storage/key_value_store.dart';
import 'package:artpulse/core/storage/project_repository.dart';
import 'package:artpulse/core/storage/store_io.dart';

class FailingStore extends MemoryStore {
  bool fail = true;
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw const FileSystemException('disk full');
    await super.write(key, value);
  }
}

void main() {
  test('repository serializes writes and preserves actual strokes', () async {
    final store = MemoryStore(), e = ArtEngine();
    final repo = ProjectRepository(store);
    e.begin(1, .2, .3, .6);
    e.move(1, .4, .5, .9);
    e.end(1);
    final d = e.snapshot(id: 'first', name: 'First');
    await Future.wait([repo.save(d), repo.delete(d.id), repo.save(d)]);
    final saved = await repo.list();
    expect(saved, hasLength(1));
    expect(saved.first.strokes.first.points.last.x, .4);
    expect(saved.first.name, 'First');
  });
  test(
    'failed write surfaces an error and does not poison later saves',
    () async {
      final store = FailingStore(), repo = ProjectRepository(FailingStore());
      final actual = ProjectRepository(store);
      final d = ArtEngine().snapshot(id: 'sample', name: 'Sample');
      await expectLater(actual.save(d), throwsA(isA<FileSystemException>()));
      store.fail = false;
      await actual.save(d);
      expect(await actual.list(), hasLength(1));
      expect(await repo.list(), isEmpty);
    },
  );
  test('corrupt saved projects remain untouched and are reported', () async {
    final store = MemoryStore();
    await store.write('project_broken', '{"schemaVersion":99}');
    final repo = ProjectRepository(store);
    expect(await repo.list(), isEmpty);
    expect(repo.unreadableProjects, 1);
    expect(await store.read('project_broken'), isNotNull);
  });
  test(
    'native storage replaces files and recovers an interrupted rename',
    () async {
      final dir = await Directory.systemTemp.createTemp('artpulse-test-');
      addTearDown(() => dir.delete(recursive: true));
      final store = FileStore(dir);
      await store.write('sample', 'one');
      await store.write('sample', 'two');
      expect(await store.read('sample'), 'two');
      await File('${dir.path}/sample.json')
          .rename('${dir.path}/sample.json.bak');
      expect(await store.keys(), contains('sample'));
      expect(await store.read('sample'), 'two');
      expect(File('${dir.path}/sample.json.bak').existsSync(), isFalse);
      await expectLater(store.write('../escape', 'x'), throwsFormatException);
      await store.remove('sample');
      expect(await store.keys(), isEmpty);
    },
  );
}
