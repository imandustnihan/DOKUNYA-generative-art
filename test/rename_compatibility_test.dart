import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dokunya/core/graphics/art_engine.dart';
import 'package:dokunya/core/graphics/art_model.dart';
import 'package:dokunya/core/storage/key_value_store.dart';
import 'package:dokunya/core/storage/project_repository.dart';

void main() {
  test('DOKUNYA imports the original browser-exported ARTPULSE v0.1 JSON', () {
    final raw = File('test/fixtures/legacy_artpulse_v0_1.json').readAsStringSync();
    final original = ProjectCodec.decode(raw);
    expect(original.name, 'Browser verified');
    final encoded = ProjectCodec.encode(original);
    final reopened = ProjectCodec.decode(encoded);
    expect(reopened.strokes.length, original.strokes.length);
    expect(reopened.id, original.id);
  });
  test('DOKUNYA can read original ARTPULSE schema 1 projects', () async {
    final engine = ArtEngine();
    engine.begin(1, .25, .35, .7);
    engine.move(1, .75, .85, .9);
    engine.end(1);
    final original = engine.snapshot(id: 'legacy', name: 'ARTPULSE original');
    final legacyBytes = ProjectCodec.encode(original);
    final dokunyaDocument = ProjectCodec.decode(legacyBytes);
    expect(dokunyaDocument.id, original.id);
    expect(dokunyaDocument.strokes.length, original.strokes.length);
    final store = MemoryStore();
    await store.write('project_legacy', legacyBytes);
    final listed = await ProjectRepository(store).list();
    expect(listed, hasLength(1));
    expect(listed.single.name, 'ARTPULSE original');
  });
  test('DOKUNYA imports previous-release JSON without modifying schema', () {
    final engine = ArtEngine();
    engine.begin(4, .1, .2, .5);
    engine.move(4, .7, .9, .8);
    engine.end(4);
    final prior = engine.snapshot(id: 'legacy-v011-saved', name: 'Legacy v0.1.1 sample');
    final bytes = ProjectCodec.encode(prior);
    final imported = ProjectCodec.decode(bytes);
    expect(imported.id, 'legacy-v011-saved');
    expect(imported.name, 'Legacy v0.1.1 sample');
    expect(imported.strokes.length, prior.strokes.length);
  });
}
