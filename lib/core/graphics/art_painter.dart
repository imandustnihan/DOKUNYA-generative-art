import "dart:typed_data";
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'art_engine.dart';
import 'art_math.dart';
import 'art_model.dart';
import 'procedural_instruments.dart';

class ArtPainter extends CustomPainter {
  ArtPainter(
    this.engine, {
    super.repaint,
    this.shader,
    this.zoom = 1,
    this.pan = Offset.zero,
    this.shaderProvider,
    this.zoomProvider,
    this.panProvider,
  });
  final ArtEngine engine;
  final ui.FragmentShader? shader;
  final double zoom;
  final Offset pan;
  final ui.FragmentShader? Function()? shaderProvider;
  final double Function()? zoomProvider;
  final Offset Function()? panProvider;
  final Paint _paint = Paint()..isAntiAlias = true;
  int _palette = -1;
  List<Color> _colors = [];
  List<Color> get colors {
    if (_palette != engine.settings.palette) {
      _palette = engine.settings.palette;
      _colors = palettes[_palette].map(Color.new).toList();
    }
    return _colors;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawColor(
      Color(backgrounds[engine.settings.background]),
      BlendMode.src,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final offset = panProvider?.call() ?? pan;
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(zoomProvider?.call() ?? zoom);
    final s = engine.settings;
    final c = colors;
    if (s.autoArt && s.instrument >= 0) {
      ProceduralInstruments.paint(canvas, size, engine, c);
    } else if (s.autoArt) {
      switch (s.mode) {
        case ArtMode.neonFlow:
          _neon(canvas, size, c);
        case ArtMode.particleGalaxy:
          _galaxy(canvas, size, c);
        case ArtMode.symmetryLab:
          _symmetry(canvas, size, c);
        case ArtMode.liquidLight:
          _liquid(canvas, size, c);
        case ArtMode.geometryPulse:
          _geometry(canvas, size, c);
      }
    } else if (s.instrument < 0 && s.mode == ArtMode.particleGalaxy) {
      _galaxy(canvas, size, c);
    }
    _strokes(canvas, size, c);
    canvas.restore();
  }

  void _line(
    Canvas canvas,
    Path path,
    Color color,
    double width, {
    bool glow = true,
  }) {
    if (glow && engine.budget.glow) {
      _paint
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: .13)
        ..strokeWidth = width * 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawPath(path, _paint);
    }
    _paint
      ..shader = null
      ..maskFilter = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = color;
    canvas.drawPath(path, _paint);
  }

  void _neon(Canvas canvas, Size size, List<Color> c) {
    final t = engine.time * .16, short = size.shortestSide;
    final count = (engine.budget.ribbons * (.45 + engine.settings.density))
        .round();
    final n = engine.budget.samples;
    final phase = (engine.seed % 360) / 57.3;
    for (var k = 0; k < count; k++) {
      final p = Path();
      final z = k / count;
      for (var j = 0; j <= n; j++) {
        final u = j / n * math.pi * 2;
        final breathe = .92 + .06 * math.sin(t * .6 + z * 3);
        final x =
            .5 +
            (.30 * math.sin(u + t * .65 + z * .65) +
                    .055 * math.sin(u * 3 - t + phase + z * 3)) *
                breathe;
        final y =
            .5 +
            (.30 * math.cos(u * 2 - t * .3 + z * .9) +
                    .045 * math.sin(u * 5 + t + z * 2)) *
                breathe;
        if (j == 0) {
          p.moveTo(x * size.width, y * size.height);
        } else {
          p.lineTo(x * size.width, y * size.height);
        }
      }
      final color = Color.lerp(
        c[k % c.length],
        c[(k + 1) % c.length],
        .35,
      )!.withValues(alpha: .3 + .5 * (1 - z));
      _line(canvas, p, color, (.0015 + z * .0008) * short);
    }
  }

  void _galaxy(Canvas canvas, Size size, List<Color> c) {
    final p = engine.pool, short = size.shortestSide;
    // Fixed-capacity simulation; no particle objects allocated during integration.
    for (var n = 0; n < engine.particleCount; n++) {
      final i = n * 8;
      final age = p[i + 4] / p[i + 5];
      final a = (math.min(1, age * 8) * math.min(1, (1 - age) * 5))
          .clamp(.1, 1)
          .toDouble();
      final color = Color.lerp(
        c[0],
        c[1],
        p[i + 7],
      )!.withValues(alpha: a * .85);
      _paint
        ..style = PaintingStyle.fill
        ..maskFilter = null
        ..shader = null
        ..color = color;
      final pos = Offset(p[i] * size.width, p[i + 1] * size.height);
      final radius = (p[i + 6] * short / 550).clamp(.55, 3.6).toDouble();
      canvas.drawCircle(pos, radius, _paint);
      if (n % 5 == 0 && engine.budget.glow) {
        _paint.color = color.withValues(alpha: .06);
        canvas.drawCircle(pos, radius * 5, _paint);
      }
    }
    if (engine.settings.autoArt) {
      for (var k = 0; k < 3; k++) {
        final rect = Rect.fromCenter(
          center: Offset(size.width * .5, size.height * .5),
          width: short * (.34 + k * .17),
          height: short * (.34 + k * .17),
        );
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6
          ..color = c[k].withValues(alpha: .09);
        canvas.drawOval(rect, _paint);
      }
    }
  }

  void _symmetry(Canvas canvas, Size size, List<Color> c) {
    final short = size.shortestSide,
        t = engine.time * .12 + engine.settings.rotation;
    final center = Offset(size.width / 2, size.height / 2);
    final sectors = engine.settings.symmetry;
    final n = engine.budget.samples;
    for (var ring = 0; ring < engine.budget.ribbons; ring++) {
      final path = Path();
      for (var j = 0; j <= n * 2; j++) {
        final a = j / (n * 2) * math.pi * 2;
        final r =
            short *
            (.10 +
                ring * .018 +
                .12 * math.pow(math.sin(a * sectors / 2 + t * .2), 2));
        final pos = center + Offset(math.cos(a + t), math.sin(a + t)) * r;
        if (j == 0) {
          path.moveTo(pos.dx, pos.dy);
        } else {
          path.lineTo(pos.dx, pos.dy);
        }
      }
      path.close();
      _line(
        canvas,
        path,
        c[ring % c.length].withValues(alpha: .48),
        .9 + ring * .035,
        glow: ring % 3 == 0,
      );
    }
  }

  void _liquid(Canvas canvas, Size size, List<Color> c) {
    final pointer = engine.strokes.isEmpty
        ? (.5, .5)
        : (
            engine.strokes.last.points.last.x,
            engine.strokes.last.points.last.y,
          );
    final f = shaderProvider?.call() ?? shader;
    if (f != null && engine.budget.shader) {
      f.setFloat(0, size.width);
      f.setFloat(1, size.height);
      f.setFloat(2, engine.time * .15);
      f.setFloat(3, pointer.$1);
      f.setFloat(4, pointer.$2);
      var i = 5;
      for (final color in [
        ...c.take(3),
        Color(backgrounds[engine.settings.background]),
      ]) {
        f.setFloat(i++, color.r);
        f.setFloat(i++, color.g);
        f.setFloat(i++, color.b);
      }
      f.setFloat(17, engine.settings.density);
      _paint
        ..style = PaintingStyle.fill
        ..maskFilter = null
        ..shader = f;
      canvas.drawRect(Offset.zero & size, _paint);
      _paint.shader = null;
      return;
    }
    final count = (4 + engine.settings.density * engine.budget.ribbons).round();
    for (var k = 0; k < count; k++) {
      final t = engine.time * .09, z = k * .9 + (engine.seed % 100) * .01;
      final x =
          size.width * (.5 + .28 * math.sin(t + z) + (pointer.$1 - .5) * .15);
      final y =
          size.height *
          (.5 + .25 * math.cos(t * .8 + z * 1.7) + (pointer.$2 - .5) * .15);
      final r = size.shortestSide * (.22 + .08 * math.sin(z + t));
      final rect = Rect.fromCircle(center: Offset(x, y), radius: r);
      _paint
        ..style = PaintingStyle.fill
        ..maskFilter = null
        ..shader = ui.Gradient.radial(
          Offset(x, y),
          r,
          [
            c[k % c.length].withValues(alpha: .42),
            c[(k + 1) % c.length].withValues(alpha: .12),
            Colors.transparent,
          ],
          [0, .5, 1],
        );
      canvas.drawOval(rect, _paint);
    }
    _paint.shader = null;
    // A low-cost flowing contour supplements the field without a physics claim.
    for (var k = 0; k < engine.budget.ribbons; k++) {
      final path = Path();
      for (var j = 0; j <= engine.budget.samples; j++) {
        final x = j / engine.budget.samples;
        final y =
            .5 +
            .23 *
                math.sin(x * 6.2 + engine.time * .16 + k * .16) *
                math.sin(x * 3 + k * .2);
        if (j == 0) {
          path.moveTo(x * size.width, y * size.height);
        } else {
          path.lineTo(x * size.width, y * size.height);
        }
      }
      _line(
        canvas,
        path,
        c[k % c.length].withValues(alpha: .18),
        1,
        glow: false,
      );
    }
  }

  void _geometry(Canvas canvas, Size size, List<Color> c) {
    final center = Offset(size.width * .5, size.height * .5),
        short = size.shortestSide;
    final t = engine.time * .15;
    for (var k = 0; k < engine.budget.ribbons + 3; k++) {
      final r = short * (.075 + k * .022) * (1 + .025 * math.sin(t + k * .2));
      final sides = 3 + (k % 5), path = Path();
      for (var j = 0; j < sides; j++) {
        final a =
            j / sides * math.pi * 2 +
            t * (k.isEven ? 1 : -1) * .3 +
            engine.settings.rotation;
        final p = center + Offset(math.cos(a), math.sin(a)) * r;
        if (j == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      _line(
        canvas,
        path,
        c[k % c.length].withValues(alpha: .18 + k * .032),
        1.1,
        glow: k % 3 == 0,
      );
    }
  }

  void _strokes(Canvas canvas, Size size, List<Color> c) {
    final s = engine.settings;
    final sectors = s.instrument < 0 && s.mode == ArtMode.symmetryLab
        ? s.symmetry
        : 1;
    for (final stroke in engine.strokes) {
      for (var sector = 0; sector < sectors; sector++) {
        final angle =
            sector / sectors * math.pi * 2 + (sectors > 1 ? s.rotation : 0);
        Offset pos(ArtPoint p) {
          final xy = sectors == 1 ? (p.x, p.y) : rotatePoint(p.x, p.y, angle);
          return Offset(xy.$1 * size.width, xy.$2 * size.height);
        }

        final pts = stroke.points;
        final color = c[stroke.color];
        if (s.mode == ArtMode.geometryPulse || s.mode == ArtMode.liquidLight) {
          final stride = s.mode == ArtMode.liquidLight ? 12 : 18;
          for (var j = 0; j < pts.length; j += stride) {
            final p = pos(pts[j]);
            final age = engine.time - pts[j].time;
            final radius =
                size.shortestSide *
                (.012 + .025 * s.trail + .006 * math.sin(age * .7));
            if (s.mode == ArtMode.liquidLight) {
              _paint
                ..maskFilter = null
                ..style = PaintingStyle.fill
                ..shader = ui.Gradient.radial(p, radius * 4, [
                  color.withValues(alpha: .35),
                  color.withValues(alpha: 0),
                ]);
              canvas.drawCircle(p, radius * 4, _paint);
              _paint.shader = null;
            } else {
              final path = Path();
              final sides = 3 + stroke.color;
              for (var v = 0; v < sides; v++) {
                final a = v / sides * math.pi * 2 + age * .16;
                final q = p + Offset(math.cos(a), math.sin(a)) * radius;
                if (v == 0) {
                  path.moveTo(q.dx, q.dy);
                } else {
                  path.lineTo(q.dx, q.dy);
                }
              }
              path.close();
              _line(
                canvas,
                path,
                color.withValues(alpha: .65),
                1.3,
                glow: false,
              );
            }
          }
        }
        final last = pts.last;
        final start = (pts.length * (1 - s.trail) * .8).floor();
        if (pts.length == 1) {
          _paint
            ..style = PaintingStyle.fill
            ..shader = null
            ..maskFilter = null
            ..color = color;
          canvas.drawCircle(pos(last), 2 + last.pressure * 3, _paint);
          continue;
        }
        // Segment groups keep speed/pressure meaningful without one draw call per sample.
        for (var b = start; b < pts.length - 1; b += 16) {
          final end = math.min(pts.length - 1, b + 16), path = Path();
          var p = pos(pts[b]);
          path.moveTo(p.dx, p.dy);
          for (var j = b + 1; j <= end; j++) {
            final next = pos(pts[j]), mid = (p + next) / 2;
            path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
            p = next;
          }
          path.lineTo(p.dx, p.dy);
          final width =
              (1.3 + pts[b].pressure * 2.2 + math.min(3, pts[b].velocity * 2)) *
              size.shortestSide /
              650;
          _line(
            canvas,
            path,
            color.withValues(alpha: sectors > 1 ? .7 : .85),
            width.clamp(.8, 7).toDouble(),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant ArtPainter oldDelegate) => true;
}

Future<Uint8List> renderPng(
  ArtEngine engine, {
  int width = 1600,
  int height = 1000,
  double zoom = 1,
  Offset pan = Offset.zero,
  ui.FragmentShader? shader,
}) async {
  final w = width.clamp(64, 2560), h = height.clamp(64, 2560);
  final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
  ArtPainter(
    engine,
    shader: shader,
    zoom: zoom,
    pan: pan,
  ).paint(canvas, Size(w.toDouble(), h.toDouble()));
  final picture = recorder.endRecording();
  late final ui.Image image;
  try {
    image = await picture.toImage(w, h);
  } finally {
    picture.dispose();
  }
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
