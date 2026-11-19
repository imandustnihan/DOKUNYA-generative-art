import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'art_engine.dart';
import 'engine_catalog.dart';

/// Ten independent drawing kernels, each with ten algorithmically different
/// variants. All 100 are deterministic and respond to gesture position,
/// animation time, seed, palette and quality budget.
///
/// A variant is not a separate GPU shader or a separate physics simulator.
/// Its formula, composition and topology are deliberately different within
/// the family. This distinction is documented in the private release notes.
class ProceduralInstruments {
  ProceduralInstruments._();

  static void paint(
    Canvas canvas,
    Size size,
    ArtEngine engine,
    List<Color> colors,
  ) {
    final id = engine.settings.instrument;
    if (id < 0 || id >= instrumentCount || size.isEmpty) return;
    final painter = _InstrumentBrush(canvas, size, engine, colors, id);
    switch (id ~/ 10) {
      case 0:
        painter.orbits();
      case 1:
        painter.ribbons();
      case 2:
        painter.geometry();
      case 3:
        painter.flow();
      case 4:
        painter.gardens();
      case 5:
        painter.particles();
      case 6:
        painter.optical();
      case 7:
        painter.resonance();
      case 8:
        painter.topography();
      case 9:
        painter.kaleidoscope();
    }
  }
}

class _InstrumentBrush {
  _InstrumentBrush(this.canvas, this.size, this.engine, this.colors, this.id);
  final Canvas canvas;
  final Size size;
  final ArtEngine engine;
  final List<Color> colors;
  final int id;
  final Paint brush = Paint()..isAntiAlias = true;
  int get variant => id % 10;
  double get t => engine.time * (.25 + engine.settings.speed * .7);
  double get density => engine.settings.density;
  double get short => size.shortestSide;
  double get seed => (engine.seed % 100003) / 100003;
  double get px =>
      engine.strokes.isEmpty ? .5 : engine.strokes.last.points.last.x;
  double get py =>
      engine.strokes.isEmpty ? .5 : engine.strokes.last.points.last.y;
  Offset point(double x, double y) => Offset(x * size.width, y * size.height);
  Offset polar(double angle, double radius, {double cx = .5, double cy = .5}) =>
      point(cx + radius * math.cos(angle), cy + radius * math.sin(angle));
  double rand(int n) {
    final x =
        math.sin((n + id * 313 + engine.seed % 997) * 127.1) * 43758.5453123;
    return x - x.floorToDouble();
  }

  Color color(int i, [double a = .7]) =>
      colors[i % colors.length].withValues(alpha: a.clamp(0.0, 1.0).toDouble());

  void path(
    Path p,
    int index, {
    double width = 1.2,
    double opacity = .68,
    bool glow = false,
    bool fill = false,
  }) {
    brush
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = width * short / 680
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = null
      ..maskFilter = null;
    if (glow && engine.budget.glow && !fill) {
      brush
        ..color = color(index, opacity * .17)
        ..strokeWidth = width * short / 155
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawPath(p, brush);
      brush.maskFilter = null;
      brush.strokeWidth = width * short / 680;
    }
    brush.color = color(index, opacity);
    canvas.drawPath(p, brush);
  }

  void dot(Offset center, double radius, int colorIndex, double opacity) {
    brush
      ..shader = null
      ..maskFilter = null
      ..style = PaintingStyle.fill
      ..color = color(colorIndex, opacity);
    canvas.drawCircle(center, radius * short / 680, brush);
  }

  // 00-09: parametric and dynamical orbits.
  void orbits() {
    final count = 11 + (density * 17).round();
    for (var k = 0; k < count; k++) {
      final pathShape = Path();
      final phase = k * .15 + t * .24 + seed;
      for (var j = 0; j <= 180; j++) {
        final u = j / 180 * math.pi * 2;
        final turns = 1 + variant % 4;
        final theta = u * turns + phase;
        final r = switch (variant) {
          0 => .045 + .34 * math.sqrt(j / 180),
          1 => .028 * math.exp(1.65 * j / 180),
          2 => .17 + .14 * math.cos(u * 3 + k * .2),
          3 => .18 + .13 * math.sin(u * 7 + phase),
          4 => .21 + .15 * math.sin(2 * u) * math.cos(u * 5),
          5 => .03 + .32 * (j / 180),
          6 => .14 + .11 * math.sin(3 * u) + .06 * math.cos(u * 5),
          7 => .23 / (1 + .7 * math.cos(3 * u + phase)),
          8 => .18 + .12 * math.sin(9 * u + t),
          _ => .12 + .08 * math.cos(6 * u) + .07 * math.sin(11 * u),
        };
        final xy = polar(
          theta,
          r,
          cx: .5 + (px - .5) * .1,
          cy: .5 + (py - .5) * .1,
        );
        if (j == 0) {
          pathShape.moveTo(xy.dx, xy.dy);
        } else {
          pathShape.lineTo(xy.dx, xy.dy);
        }
      }
      path(
        pathShape,
        k,
        width: 1.4 + k % 3,
        opacity: .2 + .55 * (1 - k / count),
        glow: k % 5 == 0,
      );
    }
  }

  // 10-19: ten independent oscillator interference rules.
  void ribbons() {
    final count = 10 + (density * 24).round();
    for (var k = 0; k < count; k++) {
      final p = Path();
      final y0 = (k + .5) / count;
      for (var j = 0; j <= 140; j++) {
        final u = j / 140, angle = u * math.pi * 2;
        final bend = switch (variant) {
          0 => math.sin(angle * 2.5 + t) * math.cos(angle + k * .13),
          1 => math.cos(angle * 3 - t + k * .07),
          2 => math.sin(angle * 4 + t) * math.sin(angle * .7),
          3 => math.sin(angle * 8 - t) / (1.2 + math.cos(angle * 2).abs()),
          4 => math.sin(angle + t) + .45 * math.sin(angle * 7 - t),
          5 => math.cos(angle * 2 + t * .5) * math.sin(angle * 3),
          6 => math.sin(angle * 6 + k * .22) * math.cos(t + angle),
          7 => math.sin(angle * 3 + t + math.sin(angle * 5)),
          8 => math.cos(angle * 11 - t) * math.exp(-math.pow((u - .5) * 3, 2)),
          _ =>
            .6 * math.sin(angle * 9 + t) + .4 * math.cos(angle * 13 - t * .7),
        };
        final xy = point(
          u,
          y0 + bend * (.035 + .09 * density) + (py - .5) * .06,
        );
        if (j == 0) {
          p.moveTo(xy.dx, xy.dy);
        } else {
          p.lineTo(xy.dx, xy.dy);
        }
      }
      path(
        p,
        k,
        width: k % 7 == 0 ? 3 : 1.2,
        opacity: .18 + .56 * (1 - (k / count) * .6),
        glow: k % 8 == 0,
      );
    }
  }

  // 20-29: different polygon/tiling topologies.
  void geometry() {
    final count = 18 + (density * 17).round();
    for (var k = 0; k < count; k++) {
      final p = Path();
      final angle = t * .13 + k * .22;
      final sides = 3 + ((k + variant * 3) % 11);
      final radius = .07 + .32 * (k + .5) / count;
      final corners = switch (variant) {
        0 => sides,
        1 => 12,
        2 => 5,
        3 => 6,
        4 => 8,
        5 => 9,
        6 => 4,
        7 => 13,
        8 => 7,
        _ => 16,
      };
      for (var j = 0; j <= corners; j++) {
        final a = angle + j / corners * math.pi * 2;
        final r = switch (variant) {
          0 => radius,
          1 => radius * (j.isEven ? .45 : 1.0),
          2 => radius * (j.isEven ? .7 : 1.1),
          3 => radius * (.8 + .2 * math.sin(k * .3 + j)),
          4 => radius * (1 + .18 * math.cos(j * .7 + t)),
          5 => radius * (j % 3 == 0 ? 1 : .46),
          6 => radius * (j.isOdd ? 1.16 : .45),
          7 => radius * (j % 4 == 0 ? 1.25 : .75),
          8 => radius * (j % 3 == 1 ? .4 : 1.03),
          _ => radius * (.65 + .4 * math.sin(j + k)),
        };
        final xy = polar(
          a,
          r,
          cx: .5 + (px - .5) * .08,
          cy: .5 + (py - .5) * .08,
        );
        if (j == 0) {
          p.moveTo(xy.dx, xy.dy);
        } else {
          p.lineTo(xy.dx, xy.dy);
        }
      }
      path(
        p,
        k,
        width: 1 + k % 3,
        opacity: .22 + .5 * (1 - k / count),
        glow: k % 7 == 0,
      );
    }
  }

  // 30-39: trajectories integrated through distinct velocity fields.
  void flow() {
    final count = 14 + (density * 42).round();
    for (var k = 0; k < count; k++) {
      var x = rand(k * 13 + 1), y = rand(k * 17 + 9);
      final p = Path()..moveTo(x * size.width, y * size.height);
      for (var j = 0; j < 80; j++) {
        final dx = x - px, dy = y - py;
        final a = switch (variant) {
          0 => math.atan2(dy, dx) + math.pi * .5,
          1 => math.sin(x * 13 + t) * math.cos(y * 11),
          2 => math.atan2(dy, dx) + math.sin(x * 8 + y * 7),
          3 => math.atan2(.5 - y, .5 - x) + 2 * math.pi,
          4 => math.sin(x * 17 + y * 9 + t),
          5 => math.atan2(dy, dx) - math.pi * .6 + math.cos(y * 7),
          6 => math.cos(x * 8 - y * 12 + t),
          7 => math.sin((x + y) * 18 + t) * 2,
          8 => math.atan2(dy, dx) + math.pi + .7 * math.sin(x * 6),
          _ => math.sin(x * 19 + t) + math.cos(y * 21 - t),
        };
        x += math.cos(a) * .007;
        y += math.sin(a) * .007;
        if (x < -.1 || x > 1.1 || y < -.1 || y > 1.1) break;
        p.lineTo(x * size.width, y * size.height);
      }
      path(
        p,
        k,
        width: .8 + rand(k) * 1.4,
        opacity: .3 + rand(k + 10) * .55,
        glow: k % 13 == 0,
      );
    }
  }

  // 40-49: recursively branching structures with different growth laws.
  void gardens() {
    void branch(Offset from, double a, double len, int depth, int k, Path p) {
      if (depth == 0 || len < .002) return;
      final next =
          from +
          Offset(
            math.cos(a) * len * size.width,
            math.sin(a) * len * size.height,
          );
      p.moveTo(from.dx, from.dy);
      p.lineTo(next.dx, next.dy);
      final split = switch (variant) {
        0 => .42,
        1 => .25,
        2 => .66,
        3 => .34,
        4 => .78,
        5 => .29,
        6 => .52,
        7 => .18,
        8 => .61,
        _ => .47,
      };
      final rotate = math.sin(t * .4 + depth * 2 + k) * .09;
      branch(
        next,
        a - split + rotate,
        len * (.62 + .02 * variant),
        depth - 1,
        k,
        p,
      );
      if (depth % (variant % 3 + 1) == 0 || variant.isEven) {
        branch(
          next,
          a + split + rotate,
          len * (.59 + .014 * variant),
          depth - 1,
          k + 1,
          p,
        );
      }
    }

    for (var k = 0; k < 8 + (density * 6).round(); k++) {
      final p = Path();
      final root = point((k + .5) / (8 + (density * 6).round()), 1.02);
      final stem = -.5 * math.pi + (k - 5) * .06 + (px - .5) * .3;
      branch(root, stem, .16 + rand(k) * .09, 5 + variant % 2, k, p);
      path(
        p,
        k,
        width: .8 + (variant % 3) * .4,
        opacity: .3 + .5 * rand(k + 53),
        glow: k % 6 == 0,
      );
    }
  }

  // 50-59: deterministic stochastic spatial processes.
  void particles() {
    final count = math.min(320, (90 + 225 * density).round());
    for (var k = 0; k < count; k++) {
      final a = rand(3 * k) * math.pi * 2;
      final r = math.sqrt(rand(3 * k + 1));
      final drift = math.sin(t * .7 + k * .7) * .017;
      final x = switch (variant) {
        0 => .5 + math.cos(a) * r * .48,
        1 => .5 + math.cos(a * 3) * r * .40,
        2 => .5 + math.cos(a) * r * .27,
        3 => rand(k * 23 + 1),
        4 => .5 + math.cos(a + r * 14) * r * .48,
        5 => .5 + math.cos(a) * r * .41,
        6 => rand(k + 98),
        7 => .5 + math.cos(a * 2) * r * .48,
        8 => .5 + math.sin(a * 6) * r * .40,
        _ => .5 + math.cos(a + t * .12) * r * .45,
      };
      final y = switch (variant) {
        0 => .5 + math.sin(a) * r * .48,
        1 => .5 + math.sin(a * 3) * r * .45,
        2 => .5 + math.sin(a) * r * .35,
        3 => rand(k * 31 + 2),
        4 => .5 + math.sin(a + r * 14) * r * .42,
        5 => .5 + math.sin(a * 2) * r * .45,
        6 => rand(k + 191),
        7 => .5 + math.sin(a * 2) * r * .46,
        8 => .5 + math.cos(a * 5) * r * .42,
        _ => .5 + math.sin(a + t * .12) * r * .45,
      };
      final b = switch (variant) {
        0 => drift,
        1 => drift * 3,
        2 => -drift,
        3 => drift,
        4 => drift * .5,
        5 => -drift * 2,
        6 => drift,
        7 => drift * 1.5,
        8 => -drift,
        _ => drift * 3,
      };
      final p = point(x + b + (px - .5) * .06, y - b + (py - .5) * .06);
      dot(
        p,
        .6 + rand(k * 17) * (2.7 + variant % 4),
        k,
        .24 + .72 * rand(k * 13),
      );
      if (k % (12 + variant) == 0) {
        final v = Path()
          ..moveTo(p.dx - 5, p.dy)
          ..lineTo(p.dx + 5, p.dy);
        path(v, k, width: .8, opacity: .65);
      }
    }
  }

  // 60-69: phase-shifted interference and moire structures.
  void optical() {
    final count = 19 + (density * 22).round();
    for (var k = 0; k < count; k++) {
      final p = Path();
      for (var j = 0; j <= 130; j++) {
        final u = j / 130;
        final v = (k + .5) / count;
        final offset = switch (variant) {
          0 => .09 * math.sin(u * 25 + v * 9 + t),
          1 => .05 * math.cos(u * 60 + v * 6),
          2 => .08 * math.sin(u * 15 + v * 25 + t),
          3 => .03 * math.sin(u * 40 + v * 40),
          4 => .06 * math.cos(u * 19 + t) * math.sin(v * 8),
          5 => .06 * math.sin(u * 17 + v * 11) * math.cos(u * 8),
          6 => .04 * math.sin(u * 32 + v * 5),
          7 => .07 * math.sin(u * 9 + v * 45 + t),
          8 => .06 * math.sin(u * 14) + .035 * math.cos(u * 35 + v * 20),
          _ => .06 * math.sin(u * 32 + v * 15) * math.cos(v * 11 + t),
        };
        final xy = variant.isEven ? point(u, v + offset) : point(v + offset, u);
        if (j == 0) {
          p.moveTo(xy.dx, xy.dy);
        } else {
          p.lineTo(xy.dx, xy.dy);
        }
      }
      path(
        p,
        k,
        width: k % 5 == 0 ? 1.8 : .9,
        opacity: .26 + .50 * (1 - k / count),
      );
    }
  }

  // 70-79: harmonics with distinct envelope and spectral interactions.
  void resonance() {
    final count = 10 + (density * 20).round();
    for (var k = 0; k < count; k++) {
      final p = Path();
      for (var j = 0; j <= 240; j++) {
        final u = j / 240, a = u * math.pi * 2;
        final harmonic = switch (variant) {
          0 => math.sin(3 * a + t),
          1 => math.sin(5 * a) + .5 * math.sin(11 * a - t),
          2 => math.cos(7 * a + t) * math.cos(3 * a),
          3 => math.sin(13 * a + t) * math.sin(2 * a),
          4 => math.sin(2 * a) + math.cos(9 * a + t),
          5 => math.cos(4 * a + t) + .5 * math.sin(17 * a),
          6 => math.sin(21 * a - t) * math.cos(5 * a),
          7 => math.sin(6 * a) * math.sin(11 * a + t),
          8 => math.cos(17 * a) * math.cos(3 * a - t),
          _ => math.sin(27 * a + t) + .3 * math.cos(7 * a),
        };
        final r = .08 + .26 * (k + 1) / count + harmonic * .028;
        final xy = polar(
          a + k * .024,
          r,
          cx: .5 + (px - .5) * .05,
          cy: .5 + (py - .5) * .05,
        );
        if (j == 0) {
          p.moveTo(xy.dx, xy.dy);
        } else {
          p.lineTo(xy.dx, xy.dy);
        }
      }
      path(
        p,
        k,
        width: 1.2,
        opacity: .3 + .5 * (1 - k / count),
        glow: k % 6 == 0,
      );
    }
  }

  // 80-89: distinct analytic contours with nonlinear terrain modulation.
  void topography() {
    final count = 17 + (density * 19).round();
    for (var k = 0; k < count; k++) {
      final p = Path(), v = (k + 1) / (count + 1);
      for (var j = 0; j <= 165; j++) {
        final x = j / 165;
        final a = x * math.pi * 2;
        final h = switch (variant) {
          0 => .07 * math.sin(a * 2 + t + math.cos(a * 5)),
          1 => .06 * math.cos(a * 5 + v * 12 + t),
          2 => .03 * math.sin(a * 12 + t) + .05 * math.cos(a * 2),
          3 => .07 * math.sin(a * 3 + v * 5),
          4 => .04 * math.sin(a * 7) * math.sin(a * 2 + t),
          5 => .06 * math.sin(a * 4 + v * 20 + t * .5),
          6 => .04 * math.cos(a * 10 + v * 10) + .02 * math.sin(a * 2),
          7 => .07 * math.sin(a + math.sin(a * 8) + t),
          8 => .04 * math.cos(a * 16 + t) * math.sin(a * 3),
          _ => .08 * math.sin(a * 2 + t) * math.cos(a * 7 + v * 7),
        };
        final xy = point(x, v + h + (py - .5) * .035);
        if (j == 0) {
          p.moveTo(xy.dx, xy.dy);
        } else {
          p.lineTo(xy.dx, xy.dy);
        }
      }
      path(p, k, width: .9 + k % 3 * .4, opacity: .3 + .5 * (1 - k / count));
    }
  }

  // 90-99: ten radial tiling arrangements and petal deformation laws.
  void kaleidoscope() {
    final petals = 5 + variant * 2;
    final layers = 7 + (density * 8).round();
    for (var k = 0; k < layers; k++) {
      final p = Path();
      for (var petal = 0; petal < petals; petal++) {
        final phase = petal * math.pi * 2 / petals + t * .08;
        final spread = (petal + variant % 4) % 4;
        final radius = .10 + .30 * (k + 1) / layers;
        final x = polar(phase, radius * (spread.isEven ? .7 : 1.0));
        if (petal == 0) p.moveTo(x.dx, x.dy);
        final left = polar(
          phase + math.pi / petals,
          radius * (.25 + .04 * (variant % 4)),
        );
        final right = polar(
          phase + 2 * math.pi / petals,
          radius * (spread == 2 ? 1.2 : 1),
        );
        p.quadraticBezierTo(left.dx, left.dy, right.dx, right.dy);
      }
      p.close();
      path(
        p,
        k,
        width: 1 + k % 3,
        opacity: .24 + .56 * (1 - k / layers),
        glow: k % 4 == 0,
      );
    }
    for (var p = 0; p < petals; p++) {
      final a = p * math.pi * 2 / petals + t * .1;
      dot(polar(a, .34), 1.7 + variant % 3, p, .55);
    }
  }
}
