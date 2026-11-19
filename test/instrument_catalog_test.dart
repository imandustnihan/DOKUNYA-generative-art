import 'package:flutter_test/flutter_test.dart';
import 'package:dokunya/core/graphics/art_engine.dart';
import 'package:dokunya/core/graphics/art_model.dart';
import 'package:dokunya/core/graphics/art_painter.dart';
import 'package:dokunya/core/graphics/engine_catalog.dart';
import 'package:dokunya/core/performance/quality.dart';
import 'package:dokunya/app/studio_controller.dart';
import 'package:dokunya/core/storage/key_value_store.dart';
import 'package:dokunya/core/storage/project_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'favorites persist, survive preference updates, and validate IDs',
    () async {
      final store = MemoryStore();
      final first = StudioController(ProjectRepository(store), animate: false);
      await first.load();
      expect(first.favoriteInstruments, isEmpty);
      await first.toggleFavoriteInstrument(0);
      await first.toggleFavoriteInstrument(99);
      await first.preferences(language: 'tr');
      expect(first.favoriteInstruments, {0, 99});
      first.dispose();

      final second = StudioController(ProjectRepository(store), animate: false);
      await second.load();
      expect(second.favoriteInstruments, {0, 99});
      expect(second.locale, 'tr');
      await second.toggleFavoriteInstrument(0);
      expect(second.favoriteInstruments, {99});
      await expectLater(second.toggleFavoriteInstrument(100), throwsRangeError);
      second.dispose();
    },
  );

  test(
    'favorite restore ignores corrupt and out-of-range preference IDs',
    () async {
      final store = MemoryStore();
      await store.write(
        'preferences',
        '{"favoriteInstruments":[-1,0,100,99,"bad",0],"locale":"az"}',
      );
      final controller = StudioController(
        ProjectRepository(store),
        animate: false,
      );
      await controller.load();
      expect(controller.favoriteInstruments, {0, 99});
      expect(controller.locale, 'az');
      controller.dispose();
    },
  );

  test('catalog exposes exactly 100 stable and distinct named instruments', () {
    expect(engineFamilies.length, 10);
    expect(engineTitles.length, 10);
    expect(engineTitles.every((category) => category.length == 10), isTrue);
    final names = [
      for (var id = 0; id < instrumentCount; id++) instrumentName(id),
    ];
    expect(instrumentCount, 100);
    expect(names.toSet().length, 100);
    expect(() => instrumentName(-1), throwsRangeError);
    expect(() => instrumentName(100), throwsRangeError);
  });

  test('new instrument ID is preserved in version-one JSON', () {
    final engine = ArtEngine(settings: const ArtSettings(instrument: 99));
    engine.begin(1, .2, .2, .8);
    engine.move(1, .8, .6, .7);
    engine.end(1);
    final doc = engine.snapshot(id: 'catalog99', name: 'Kaleido Mosaic');
    final encoded = ProjectCodec.encode(doc);
    final decoded = ProjectCodec.decode(encoded);
    expect(decoded.settings.instrument, 99);
    expect(decoded.strokes.length, 1);
    expect(decoded.settings.mode, ArtMode.neonFlow);
  });

  test('legacy documents without instrument metadata remain loadable', () {
    final original = ArtEngine(
      settings: const ArtSettings(mode: ArtMode.symmetryLab),
    ).snapshot(id: 'legacy', name: 'Older creation');
    final json = original.toJson();
    final settings = Map<String, Object>.of(
      json['settings']! as Map<String, Object>,
    );
    settings.remove('instrument');
    expect(ArtSettings.fromJson(settings).instrument, -1);
    expect(ArtSettings.fromJson(settings).mode, ArtMode.symmetryLab);
    expect(
      () => ArtSettings.fromJson({...settings, 'instrument': 100}),
      throwsFormatException,
    );
  });

  testWidgets('all 100 distinct instruments generate real PNG output', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final fingerprints = <int>{};
      for (var id = 0; id < instrumentCount; id++) {
        final engine = ArtEngine(
          seed: 2749,
          settings: ArtSettings(
            instrument: id,
            palette: id ~/ 10 % palettes.length,
          ),
        );
        engine.budget = QualityBudget.profiles[0];
        engine.time = 1.5;
        final bytes = await renderPng(engine, width: 160, height: 110);
        expect(bytes.sublist(0, 8), [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ], reason: 'instrument $id');
        expect(
          bytes.length,
          greaterThan(450),
          reason: 'instrument $id is blank',
        );
        var hash = 2166136261;
        for (final b in bytes) {
          hash = ((hash ^ b) * 16777619) & 0xffffffff;
        }
        expect(
          fingerprints.add(hash),
          isTrue,
          reason: 'duplicate PNG rendering for instrument $id',
        );
      }
      expect(fingerprints.length, 100);
    });
  });
}
