import 'dart:async';
import 'dart:convert';

import 'package:dokunya/app/studio_controller.dart';
import 'package:dokunya/core/graphics/art_engine.dart';
import 'package:dokunya/core/storage/key_value_store.dart';
import 'package:dokunya/core/storage/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class PausedProjectStore extends MemoryStore {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> write(String key, String value) async {
    if (key.startsWith('project_')) {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    }
    await super.write(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('draft storage is separate from named gallery projects', () async {
    final store = MemoryStore();
    final repository = ProjectRepository(store);
    final draft = ArtEngine().snapshot(id: 'autosave_draft', name: 'Draft');
    await repository.saveDraft(draft);
    expect(await repository.list(), isEmpty);
    expect((await repository.loadDraft())?.name, 'Draft');
    await repository.clearDraft();
    expect(await repository.loadDraft(), isNull);
  });

  test('invalid draft JSON is preserved and reported', () async {
    final store = MemoryStore();
    await store.write('workspace_draft', '{broken');
    final repository = ProjectRepository(store);
    expect(await repository.loadDraft(), isNull);
    expect(repository.unreadableDraft, isTrue);
    expect(await store.read('workspace_draft'), '{broken');
  });

  test('invalid typed JSON is preserved and reported', () async {
    final store = MemoryStore();
    final valid = ArtEngine().snapshot(id: 'autosave_draft', name: 'Draft');
    final map = jsonDecode(ProjectCodec.encode(valid)) as Map<String, dynamic>;
    final settings = map['settings'] as Map<String, dynamic>;
    settings['mode'] = 123;
    final source = jsonEncode(map);
    await store.write('workspace_draft', source);
    final repository = ProjectRepository(store);
    expect(await repository.loadDraft(), isNull);
    expect(repository.unreadableDraft, isTrue);
    expect(await store.read('workspace_draft'), source);
  });

  test('unsaved strokes recover after restart and manual save clears draft', () async {
    final repository = ProjectRepository(MemoryStore());
    final first = StudioController(repository, animate: false);
    await first.load();
    first.begin(11, .20, .30, .8);
    first.move(11, .40, .60, .7);
    first.end(11);
    expect(await first.flushDraft(), isTrue);
    first.dispose();

    final second = StudioController(repository, animate: false);
    await second.load();
    expect(second.recoveredOnStartup, isTrue);
    expect(second.dirty, isTrue);
    expect(second.engine.strokes.single.points.last.x, .40);
    await second.save('Recovered composition');
    expect(await repository.loadDraft(), isNull);
    expect((await repository.list()).single.name, 'Recovered composition');
    second.dispose();
  });

  test('parameter-only compositions also become recoverable', () async {
    final repository = ProjectRepository(MemoryStore());
    final controller = StudioController(repository, animate: false);
    await controller.load();
    controller.change(controller.engine.settings.copyWith(speed: .3));
    expect(controller.engine.strokes, isEmpty);
    expect(await controller.flushDraft(), isTrue);
    expect((await repository.loadDraft())?.settings.speed, .3);
    controller.dispose();
  });

  test('switching preset replaces the previous draft instead of reviving it', () async {
    final repository = ProjectRepository(MemoryStore());
    final controller = StudioController(repository, animate: false);
    await controller.load();
    controller.begin(1, .1, .1, .6);
    controller.end(1);
    await controller.flushDraft();
    expect((await repository.loadDraft())?.strokes, isNotEmpty);
    controller.preset(controller.engine.settings.mode, seed: 2781);
    await controller.flushDraft();
    final restored = await repository.loadDraft();
    expect(restored?.seed, 2781);
    expect(restored?.strokes, isEmpty);
    controller.dispose();
  });

  test('edits made during manual save survive the save race', () async {
    final store = PausedProjectStore();
    final repository = ProjectRepository(store);
    final controller = StudioController(repository, animate: false);
    await controller.load();
    controller.begin(1, .1, .1, .6);
    controller.end(1);
    final saving = controller.save('First state');
    await store.entered.future;
    controller.begin(2, .4, .4, .7);
    controller.end(2);
    store.release.complete();
    await saving;
    expect(controller.dirty, isTrue);
    expect((await repository.list()).single.strokes, hasLength(1));
    expect((await repository.loadDraft())?.strokes, hasLength(2));
    controller.dispose();
  });
}
