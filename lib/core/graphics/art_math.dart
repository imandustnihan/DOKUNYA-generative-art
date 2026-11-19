import 'dart:math' as math;

class SeededRandom {
  SeededRandom(int seed) : state = seed & 0xffffffff {
    if (state == 0) state = 1;
  }
  int state;
  double next() {
    var x = state;
    x = (x ^ (x << 13)) & 0xffffffff;
    x = (x ^ (x >> 17)) & 0xffffffff;
    x = (x ^ (x << 5)) & 0xffffffff;
    state = x;
    return x / 4294967296;
  }
}

(double, double) rotatePoint(double x, double y, double angle) => (
  .5 + (x - .5) * math.cos(angle) - (y - .5) * math.sin(angle),
  .5 + (x - .5) * math.sin(angle) + (y - .5) * math.cos(angle),
);

// An original smooth value-noise implementation, not Perlin/Simplex noise.
// Keep intermediate products below JS's exact-integer limit so web and VM
// hashes agree even when the full product would exceed 53 bits.
int multiply32(int a, int b) {
  final low = (a & 0xffff) * (b & 0xffff);
  final cross =
      (((a >> 16) * (b & 0xffff) + (a & 0xffff) * (b >> 16)) & 0xffff) << 16;
  return (low + cross) & 0xffffffff;
}

double _lattice(int x, int y, int seed) {
  var n =
      (multiply32(x, 374761393) +
          multiply32(y, 668265263) +
          multiply32(seed, 69069)) &
      0x7fffffff;
  n = multiply32(n ^ (n >> 13), 1274126177) & 0x7fffffff;
  return ((n ^ (n >> 16)) & 0x7fffffff) / 2147483647;
}

double smoothNoise(double x, double y, int seed) {
  final ix = x.floor(), iy = y.floor();
  var fx = x - ix, fy = y - iy;
  fx = fx * fx * (3 - 2 * fx);
  fy = fy * fy * (3 - 2 * fy);
  final a = _lattice(ix, iy, seed), b = _lattice(ix + 1, iy, seed);
  final c = _lattice(ix, iy + 1, seed), d = _lattice(ix + 1, iy + 1, seed);
  return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy;
}

(double, double) softenedAttraction(double x, double y, double tx, double ty) {
  final dx = tx - x, dy = ty - y;
  final r2 = dx * dx + dy * dy + .012;
  final strength = math.min(1.8, .025 / r2);
  final length = math.sqrt(r2);
  return (dx / length * strength, dy / length * strength);
}
