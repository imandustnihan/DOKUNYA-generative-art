import 'dart:convert';
import 'dart:io';

import 'package:dokunya/core/graphics/art_engine.dart';
import 'package:dokunya/core/graphics/art_model.dart';
import 'package:dokunya/core/performance/quality.dart';

void main() {
  final rows = <Map<String, Object>>[];
  for (var level = 0; level < QualityBudget.profiles.length; level++) {
    final e = ArtEngine(
      seed: 2749,
      settings: const ArtSettings(mode: ArtMode.particleGalaxy, density: 1),
    );
    e.budget = QualityBudget.profiles[level];
    for (var i = 0; i < 1200; i++) {
      e.step(1 / 60);
    }
    final memoryBefore = ProcessInfo.currentRss;
    final timings = <int>[];
    final watch = Stopwatch();
    for (var i = 0; i < 3600; i++) {
      watch
        ..reset()
        ..start();
      e.step(1 / 60);
      watch.stop();
      timings.add(watch.elapsedMicroseconds);
    }
    timings.sort();
    rows.add({
      'profile': Quality.values[level].name,
      'particles': e.particleCount,
      'steps': timings.length,
      'mean_us': timings.reduce((a, b) => a + b) / timings.length,
      'p50_us': timings[timings.length ~/ 2],
      'p95_us': timings[(timings.length * .95).floor()],
      'max_us': timings.last,
      'rss_before': memoryBefore,
      'rss_after': ProcessInfo.currentRss,
    });
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'scope': 'AOT CPU simulation only; excludes painting, GPU, battery and physical-device behavior',
      'dart': Platform.version,
      'os': Platform.operatingSystemVersion,
      'processors': Platform.numberOfProcessors,
      'results': rows,
    }),
  );
}
