import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:artpulse/core/graphics/art_engine.dart';
import 'package:artpulse/core/graphics/art_math.dart';
import 'package:artpulse/core/graphics/art_model.dart';
import 'package:artpulse/core/performance/quality.dart';

void main() {
  test(
    '32-bit hash multiplication matches an exact large-integer reference',
    () {
      for (final a in [-40000000, -1, 0, 1, 0x7fffffff, 0xffffffff]) {
        for (final b in [69069, 374761393, 1274126177, 0xffffffff]) {
          final exact =
              ((BigInt.from(a) * BigInt.from(b)) & BigInt.from(0xffffffff))
                  .toInt();
          expect(multiply32(a, b), exact);
        }
      }
    },
  );
  test('seeded initialization and evolution are deterministic', () {
    final a = ArtEngine(
      seed: 7,
      settings: const ArtSettings(mode: ArtMode.particleGalaxy),
    );
    final b = ArtEngine(seed: 7, settings: a.settings);
    for (var i = 0; i < 240; i++) {
      a.step(1 / 60);
      b.step(1 / 60);
    }
    expect(a.pool, b.pool);
    expect(a.random.state, b.random.state);
    expect(a.time, b.time);
    expect(ArtEngine(seed: 8).pool, isNot(a.pool));
  });
  test(
    'save/restoration preserves the next simulation step, not only the image',
    () {
      final a = ArtEngine(
        seed: 19,
        settings: const ArtSettings(mode: ArtMode.particleGalaxy),
      );
      a.begin(1, .3, .4, .8);
      a.step(.01);
      a.move(1, .4, .45, .9);
      a.end(1);
      for (var i = 0; i < 180; i++) {
        a.step(1 / 60);
      }
      final doc = a.snapshot(id: 'sample', name: 'A piece');
      final decoded = ProjectCodec.decode(ProjectCodec.encode(doc));
      final b = ArtEngine()..restore(decoded);
      expect(decoded.settings.toJson(), doc.settings.toJson());
      expect(
        decoded.strokes.first.points.last.toJson(),
        doc.strokes.first.points.last.toJson(),
      );
      a.step(1 / 60);
      b.step(1 / 60);
      expect(
        a.pool.sublist(0, a.particleCount * 8),
        b.pool.sublist(0, b.particleCount * 8),
      );
      expect(a.time, b.time);
      expect(a.random.state, b.random.state);
    },
  );
  test('gesture attraction changes the particle trajectory', () {
    final a = ArtEngine(
      seed: 5,
      settings: const ArtSettings(mode: ArtMode.particleGalaxy),
    );
    final b = ArtEngine(seed: 5, settings: a.settings);
    a.begin(1, .7, .2, .5);
    for (var i = 0; i < 60; i++) {
      a.step(1 / 60);
      b.step(1 / 60);
    }
    expect(a.pool, isNot(b.pool));
    expect(a.strokes, hasLength(1));
  });
  test('softened attraction stays finite at zero distance', () {
    final force = softenedAttraction(.5, .5, .5, .5);
    expect(force, (0.0, 0.0));
    final near = softenedAttraction(.5, .5, .50000001, .5);
    expect(near.$1.isFinite, isTrue);
    expect(near.$1.abs(), lessThan(2));
  });
  test(
    'symmetry rotations preserve radius and close after a complete orbit',
    () {
      for (final sectors in [2, 4, 6, 8, 12]) {
        final p = rotatePoint(.8, .6, 2 * math.pi / sectors);
        expect(
          math.pow(p.$1 - .5, 2) + math.pow(p.$2 - .5, 2),
          closeTo(.1, 1e-10),
        );
        final end = rotatePoint(.8, .6, 2 * math.pi);
        expect(end.$1, closeTo(.8, 1e-10));
        expect(end.$2, closeTo(.6, 1e-10));
      }
    },
  );
  test('smooth noise is bounded and continuous at lattice boundaries', () {
    for (var x = -10; x < 10; x++) {
      expect(smoothNoise(x * .37, x * .13, 5), inInclusiveRange(0, 1));
    }
    expect(
      (smoothNoise(.999999, .4, 17) - smoothNoise(1.000001, .4, 17)).abs(),
      lessThan(.0001),
    );
  });
  test('long sessions and hostile delta times have bounded finite state', () {
    final e = ArtEngine(
      settings: const ArtSettings(mode: ArtMode.particleGalaxy, density: 1),
    );
    e.budget = QualityBudget.profiles.last;
    for (var i = 0; i < 12000; i++) {
      e.step(i % 20 == 0 ? 1000 : 1 / 60);
    }
    e.step(double.nan);
    e.step(double.infinity);
    e.step(-1);
    expect(e.particleCount, lessThanOrEqualTo(e.budget.particles));
    expect(e.pool.every((v) => v.isFinite), isTrue);
    expect(
      ProjectCodec.decode(
        ProjectCodec.encode(e.snapshot(id: 'long', name: 'Long')),
      ).particles.length,
      e.particleCount * 8,
    );
  });
  test('stroke and pointer storage is bounded with repeated long input', () {
    final e = ArtEngine();
    for (var s = 0; s < 200; s++) {
      e.begin(1, .2, .3, .8);
      for (var p = 0; p < 1500; p++) {
        e.move(1, (p % 100) / 100, (p % 90) / 90, .7);
      }
      e.end(1);
    }
    expect(e.strokes.length, lessThanOrEqualTo(maxStrokes));
    expect(e.sampleCount, lessThanOrEqualTo(maxSamples));
    expect(e.strokes.every((s) => s.points.length <= 1024), isTrue);
    expect(e.pointers, isEmpty);
    e.undo();
    expect(e.canRedo, isTrue);
    e.redo();
    expect(e.canRedo, isFalse);
  });
  test('clear produces a genuinely empty canvas state and restart restores generation', () {
    final e = ArtEngine();
    e.begin(1, .1, .1, .4);
    e.clear();
    expect(e.strokes, isEmpty);
    expect(e.particleCount, 0);
    expect(e.settings.autoArt, isFalse);
    e.restart(7);
    expect(e.settings.autoArt, isTrue);
    expect(e.seed, 7);
  });
  test('all quality profiles change actual work budgets', () {
    for (var i = 1; i < QualityBudget.profiles.length; i++) {
      expect(
        QualityBudget.profiles[i].particles,
        greaterThan(QualityBudget.profiles[i - 1].particles),
      );
      expect(
        QualityBudget.profiles[i].samples,
        greaterThan(QualityBudget.profiles[i - 1].samples),
      );
    }
    expect(QualityBudget.profiles.first.fps, 30);
  });
  test('auto quality requires sustained measurements and uses hysteresis', () {
    final q = AutoQuality();
    for (var i = 0; i < 119; i++) {
      expect(q.observe(25, 3), isFalse);
    }
    expect(q.observe(25, 3), isTrue);
    expect(q.level, 1);
    for (var i = 0; i < 899; i++) {
      expect(q.observe(4, 3), isFalse);
    }
    expect(q.observe(4, 3), isTrue);
    expect(q.level, 2);
  });
  group('untrusted project validation', () {
    late Map<String, dynamic> valid;
    setUp(
      () => valid = jsonDecode(
        ProjectCodec.encode(ArtEngine().snapshot(id: 'safe', name: 'Safe')),
      ) as Map<String, dynamic>,
    );
    for (final field in ['schemaVersion', 'algorithmVersion']) {
      test('rejects unsupported $field', () {
        valid[field] = 999;
        expect(
          () => ProjectCodec.decode(jsonEncode(valid)),
          throwsFormatException,
        );
      });
    }
    test(
      'rejects traversal ids, invalid parameters, and bad colour payloads',
      () {
        valid['id'] = '../escape';
        expect(
          () => ProjectCodec.decode(jsonEncode(valid)),
          throwsFormatException,
        );
        valid['id'] = 'safe';
        (valid['settings'] as Map)['speed'] = 100;
        expect(
          () => ProjectCodec.decode(jsonEncode(valid)),
          throwsFormatException,
        );
        (valid['settings'] as Map)['speed'] = .5;
        (valid['settings'] as Map)['colors'] = [0];
        expect(
          () => ProjectCodec.decode(jsonEncode(valid)),
          throwsFormatException,
        );
      },
    );
    test('rejects excessive nesting, oversized input and malformed JSON', () {
      expect(
        () => ProjectCodec.decode('${'[' * 20}0${']' * 20}'),
        throwsFormatException,
      );
      expect(
        () => ProjectCodec.decode(' ' * (maxImportBytes + 1)),
        throwsFormatException,
      );
      expect(() => ProjectCodec.decode('{broken'), throwsFormatException);
    });
    test('rejects out-of-range particle values and negative lifetime', () {
      valid['particles'] = [.5, .5, 0, 0, 0, -1, 1, .5];
      expect(
        () => ProjectCodec.decode(jsonEncode(valid)),
        throwsFormatException,
      );
    });
  });
}
