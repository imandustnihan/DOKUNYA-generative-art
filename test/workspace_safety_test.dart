import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dokunya/app/studio_controller.dart';
import 'package:dokunya/core/graphics/art_model.dart';
import 'package:dokunya/core/graphics/engine_catalog.dart';
import 'package:dokunya/core/storage/key_value_store.dart';
import 'package:dokunya/core/storage/project_repository.dart';
import 'package:dokunya/core/storage/store_io.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class DraftQuotaStore extends MemoryStore {
  bool full = false;
  @override
  Future<void> write(String key, String value) async {
    if (full && key.startsWith('workspace_draft')) throw StateError('quota');
    await super.write(key, value);
  }
}

class DelayedSaveStore extends MemoryStore {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(String key, String value) async {
    if (key.startsWith('project_') && !started.isCompleted) {
      started.complete();
      await release.future;
    }
    await super.write(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'damaged native bytes survive further edits, recovery and manual saves',
    () async {
      final dir = await Directory.systemTemp.createTemp('dokunya-draft-');
      addTearDown(() => dir.delete(recursive: true));
      final store = FileStore(dir);
      final original = File('${dir.path}/workspace_draft.json');
      await original.writeAsBytes([0xff, 0xc0]);
      final repo = ProjectRepository(store);
      final first = StudioController(repo, animate: false);
      await first.load();
      expect(repo.unreadableDraft, isTrue);
      first.startInstrument(99);
      await first.flushDraft();
      first.dispose();
      final restarted = StudioController(
        ProjectRepository(store),
        animate: false,
      );
      await restarted.load();
      expect(restarted.engine.settings.instrument, 99);
      expect(restarted.recoveredOnStartup, isTrue);
      await restarted.save('Mosaic');
      expect(await original.readAsBytes(), [0xff, 0xc0]);
      restarted.dispose();
      await original.writeAsBytes(List.filled(maxImportBytes + 1, 32));
      expect(await repo.loadDraft(), isNull);
      expect(repo.unreadableDraft, isTrue);
      expect(await original.length(), maxImportBytes + 1);
    },
  );

  test(
    'malformed setting types isolate a gallery entry from valid legacy art',
    () async {
      final store = MemoryStore(), repo = ProjectRepository(store);
      final legacy = await File('test/fixtures/legacy_artpulse_v0_1.json')
          .readAsString();
      final data = jsonDecode(legacy) as Map<String, dynamic>;
      for (final mode in modeIds) {
        data['id'] = mode;
        data['settings']['mode'] = mode;
        await store.write('project_$mode', jsonEncode(data));
      }
      data['settings']['mode'] = 12;
      await store.write('project_bad', jsonEncode(data));
      final docs = await repo.list();
      expect(docs.map((d) => d.settings.mode).toSet(), ArtMode.values.toSet());
      expect(docs.every((d) => d.settings.instrument == -1), isTrue);
      expect(repo.unreadableProjects, 1);
      expect(await store.read('project_bad'), jsonEncode(data));
    },
  );

  test(
    'instrument selection preserves an earlier named project for all 100 IDs',
    () async {
      final repo = ProjectRepository(MemoryStore());
      final c = StudioController(repo, animate: false);
      await c.load();
      c.begin(1, .1, .3, .8);
      c.end(1);
      await c.save('Original');
      for (var id = 0; id < instrumentCount; id++) {
        c.startInstrument(id);
        expect(c.projectId, isNull);
        expect(c.engine.settings.instrument, id);
        expect(c.name, instrumentName(id));
        expect(c.page, WorkspacePage.studio);
      }
      await c.save('Last tool');
      expect(
        (await repo.list()).map((d) => d.name),
        containsAll(['Last tool', 'Original']),
      );
      expect(
        c.documents.singleWhere((d) => d.name == 'Original').strokes,
        hasLength(1),
      );
      c.dispose();
    },
  );

  test('save completion after a document switch preserves the new identity and draft', () async {
    final store = DelayedSaveStore(), repo = ProjectRepository(store);
    final c = StudioController(repo, animate: false);
    await c.load();
    c.startInstrument(2);
    final first = c.save('Earlier work');
    await store.started.future;
    c.startInstrument(47);
    final write = c.flushDraft();
    store.release.complete();
    await Future.wait([first, write]);
    expect(c.projectId, isNull);
    expect(c.name, instrumentName(47));
    expect((await repo.loadDraft())!.settings.instrument, 47);
    expect((await repo.list()).single.settings.instrument, 2);
    c.dispose();
  });

  test('background flush keeps the previous draft on quota failure and recovers on retry', () async {
    final store = DraftQuotaStore(), repo = ProjectRepository(store);
    final c = StudioController(
      repo,
      animate: false,
      draftDelay: const Duration(hours: 1),
    );
    await c.load();
    c.change(c.engine.settings.copyWith(speed: .2));
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect((await repo.loadDraft())?.settings.speed, .2);
    store.full = true;
    c.change(c.engine.settings.copyWith(speed: .8));
    expect(await c.flushDraft(), isFalse);
    expect(c.draftSaveFailed, isTrue);
    expect((await repo.loadDraft())?.settings.speed, .2);
    expect(c.engine.settings.speed, .8);
    store.full = false;
    expect(await c.flushDraft(), isTrue);
    expect(c.draftSaveFailed, isFalse);
    expect((await repo.loadDraft())?.settings.speed, .8);
    c.dispose();
  });

  test('website links honor locale and protect a restored drawing', () async {
    final store = MemoryStore(), repo = ProjectRepository(store);
    final c = StudioController(repo, animate: false);
    await c.load();
    await c.applyStudioLink({'instrument': '99', 'lang': 'az'});
    expect(c.locale, 'az');
    expect(c.engine.settings.instrument, 99);
    expect(await repo.loadDraft(), isNull);
    await c.applyStudioLink({'mode': 'symmetry_lab', 'instrument': 'bad'});
    expect(c.engine.settings.mode, ArtMode.symmetryLab);
    c.begin(1, .1, .2, .7);
    c.end(1);
    await c.flushDraft();
    c.dispose();
    final reopened = StudioController(ProjectRepository(store), animate: false);
    await reopened.load();
    await reopened.applyStudioLink({'instrument': '0', 'lang': 'tr'});
    expect(reopened.engine.settings.mode, ArtMode.symmetryLab);
    expect(reopened.engine.strokes, hasLength(1));
    expect(reopened.locale, 'tr');
    reopened.dispose();
  });

  test(
    'system reduced motion follows the OS without saving it as a user choice',
    () async {
      final repo = ProjectRepository(MemoryStore());
      final c = StudioController(repo, animate: false);
      await c.load();
      c.configureSize(const Size(400, 800), systemReduceMotion: true);
      await c.toggleFavoriteInstrument(0);
      expect((await repo.preferences())['reducedMotion'], false);
      c.configureSize(const Size(400, 800));
      expect(c.reducedMotion, false);
      await c.preferences(reduce: true);
      expect(c.reducedMotion, true);
      c.dispose();
    },
  );
}
