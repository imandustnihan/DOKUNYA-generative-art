import 'dart:math' as math;
import 'dart:typed_data';

import 'art_math.dart';
import 'art_model.dart';
import '../performance/quality.dart';

class ArtEngine {
  ArtEngine({int seed = 2749, this.settings = const ArtSettings()})
    : random = SeededRandom(seed),
      seed = seed {
    _fillInitial();
  }
  int seed;
  SeededRandom random;
  ArtSettings settings;
  double time = 0;
  final List<ArtStroke> strokes = [];
  final List<ArtStroke> _redo = [];
  final Map<int, ArtStroke> _active = {};
  final Map<int, (double, double)> pointers = {};
  final Float64List pool = Float64List(maxParticles * 8);
  int particleCount = 0;
  QualityBudget budget = QualityBudget.profiles[2];
  bool get canUndo => strokes.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get sampleCount => strokes.fold(0, (sum, s) => sum + s.points.length);

  void _fillInitial() {
    if (!settings.autoArt) return;
    for (
      var i = 0;
      i < math.min(120, budget.particles * settings.density).floor();
      i++
    ) {
      _spawn(null, null, prewarm: true);
    }
  }

  void _spawn(double? x, double? y, {bool prewarm = false}) {
    if (particleCount >= maxParticles) return;
    final i = particleCount++ * 8;
    final a = random.next() * math.pi * 2, r = math.sqrt(random.next()) * .44;
    pool[i] = x ?? (.5 + math.cos(a) * r);
    pool[i + 1] = y ?? (.5 + math.sin(a) * r);
    pool[i + 2] = math.cos(a) * (.04 + random.next() * .12);
    pool[i + 3] = math.sin(a) * (.04 + random.next() * .12);
    pool[i + 4] = prewarm ? random.next() * 3 : 0;
    pool[i + 5] = 4 + random.next() * 6;
    pool[i + 6] = .5 + random.next() * 2;
    pool[i + 7] = random.next();
  }

  void begin(int id, double x, double y, double pressure) {
    if (_active.containsKey(id)) end(id);
    if (_active.length >= 10) return;
    _redo.clear();
    while (strokes.length >= maxStrokes || sampleCount >= maxSamples - 1) {
      final oldest = strokes.removeAt(0);
      _active.removeWhere((_, s) => identical(s, oldest));
    }
    final s = ArtStroke([
      ArtPoint(x.clamp(0, 1), y.clamp(0, 1), pressure.clamp(.1, 1), 0, time),
    ], strokes.length % 4);
    strokes.add(s);
    _active[id] = s;
    pointers[id] = (x, y);
    if (settings.mode == ArtMode.particleGalaxy) {
      for (var i = 0; i < 18; i++) {
        _spawn(x, y);
      }
    }
  }

  void move(int id, double x, double y, double pressure) {
    final s = _active[id];
    if (s == null) return;
    x = x.clamp(0, 1);
    y = y.clamp(0, 1);
    final prev = s.points.last;
    final dist = math.sqrt(math.pow(x - prev.x, 2) + math.pow(y - prev.y, 2));
    if (dist < .002) return;
    final dt = math.max(1 / 240, time - prev.time);
    if (sampleCount >= maxSamples) return;
    if (s.points.length >= 1024) {
      final reduced = [
        for (var i = 0; i < s.points.length; i += 2) s.points[i],
      ];
      s.points
        ..clear()
        ..addAll(reduced);
    }
    s.points.add(
      ArtPoint(x, y, pressure.clamp(.1, 1), (dist / dt).clamp(0, 10), time),
    );
    pointers[id] = (x, y);
    if (settings.mode == ArtMode.particleGalaxy) {
      for (var i = 0; i < 4; i++) {
        _spawn(x, y);
      }
    }
  }

  void end(int id) {
    _active.remove(id);
    pointers.remove(id);
  }

  void endAll() {
    _active.clear();
    pointers.clear();
  }

  void undo() {
    endAll();
    if (canUndo) _redo.add(strokes.removeLast());
  }

  void redo() {
    endAll();
    if (canRedo) strokes.add(_redo.removeLast());
  }

  void clear() {
    endAll();
    strokes.clear();
    _redo.clear();
    particleCount = 0;
    settings = settings.copyWith(autoArt: false);
  }

  void restart(int value) {
    clear();
    seed = value;
    random = SeededRandom(value);
    time = 0;
    settings = settings.copyWith(autoArt: true);
    _fillInitial();
  }

  void step(double seconds) {
    if (!seconds.isFinite || seconds <= 0) return;
    final dt = seconds.clamp(0, 1 / 15) * (.15 + settings.speed * 1.6);
    time += dt;
    if (settings.mode != ArtMode.particleGalaxy) return;
    final target = (budget.particles * settings.density).round();
    if (particleCount > target) particleCount = target;
    if (settings.autoArt) {
      for (var n = 0; n < 6 && particleCount < target; n++) {
        _spawn(null, null);
      }
    }
    for (var n = particleCount - 1; n >= 0; n--) {
      final i = n * 8;
      var ax = 0.0, ay = 0.0;
      for (final p in pointers.values) {
        final a = softenedAttraction(pool[i], pool[i + 1], p.$1, p.$2);
        ax += a.$1;
        ay += a.$2;
      }
      final flow =
          smoothNoise(pool[i] * 3 + time * .04, pool[i + 1] * 3, seed) *
          math.pi *
          4;
      ax += math.cos(flow) * .04;
      ay += math.sin(flow) * .04;
      final damping = math.exp(-.4 * dt);
      pool[i + 2] = (pool[i + 2] + ax * dt) * damping;
      pool[i + 3] = (pool[i + 3] + ay * dt) * damping;
      pool[i] += pool[i + 2] * dt;
      pool[i + 1] += pool[i + 3] * dt;
      pool[i + 4] += dt;
      if (pool[i + 4] > pool[i + 5] ||
          pool[i] < -.2 ||
          pool[i] > 1.2 ||
          pool[i + 1] < -.2 ||
          pool[i + 1] > 1.2) {
        for (var j = 0; j < 8; j++) {
          pool[i + j] = pool[(particleCount - 1) * 8 + j];
        }
        particleCount--;
        if (settings.autoArt) _spawn(null, null);
      }
    }
  }

  ArtDocument snapshot({required String id, required String name}) =>
      ArtDocument(
        id: id,
        name: name,
        seed: seed,
        time: time,
        settings: settings,
        strokes: strokes.map((s) => s.clone()).toList(),
        particles: Float64List.fromList(pool.sublist(0, particleCount * 8)),
        randomState: random.state,
        savedAt: DateTime.now().toUtc().toIso8601String(),
      );
  void restore(ArtDocument d) {
    endAll();
    seed = d.seed;
    random = SeededRandom(d.randomState);
    time = d.time;
    settings = d.settings;
    strokes
      ..clear()
      ..addAll(d.strokes.map((s) => s.clone()));
    _redo.clear();
    pool.setAll(0, d.particles);
    particleCount = d.particles.length ~/ 8;
  }
}
