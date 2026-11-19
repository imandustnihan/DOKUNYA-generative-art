import '../graphics/art_model.dart';

class QualityBudget {
  const QualityBudget(
    this.particles,
    this.samples,
    this.ribbons,
    this.glow,
    this.fps,
    this.shader,
  );
  final int particles, samples, ribbons, fps;
  final bool glow, shader;
  static const profiles = [
    QualityBudget(80, 40, 4, false, 30, false),
    QualityBudget(180, 64, 6, false, 60, false),
    QualityBudget(400, 90, 9, true, 60, false),
    QualityBudget(800, 130, 12, true, 60, true),
    QualityBudget(1400, 180, 16, true, 120, true),
  ];
  static QualityBudget forQuality(Quality q) =>
      profiles[q == Quality.auto ? 2 : q.index];
}

class AutoQuality {
  int level = 2;
  int _slow = 0, _fast = 0;
  // A window is 60 rendered frame timings. Hysteresis prevents oscillation.
  bool observe(double rasterMs, double buildMs) {
    final worst = rasterMs > buildMs ? rasterMs : buildMs;
    if (worst > 19) {
      _slow++;
      _fast = 0;
    } else if (worst < 9) {
      _fast++;
      _slow = 0;
    } else {
      _slow = 0;
      _fast = 0;
    }
    if (_slow >= 120 && level > 0) {
      level--;
      _slow = 0;
      return true;
    }
    if (_fast >= 900 && level < 3) {
      level++;
      _fast = 0;
      return true;
    }
    return false;
  }

  void conservativeStart({required double shortestSide, required bool tv}) {
    level = tv || shortestSide < 400 ? 1 : 2;
    _slow = 0;
    _fast = 0;
  }
}
