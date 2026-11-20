import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

enum ArtMode {
  neonFlow,
  particleGalaxy,
  symmetryLab,
  liquidLight,
  geometryPulse,
}

enum Quality { eco, low, medium, high, ultra, auto }

const modeIds = [
  'neon_flow',
  'particle_galaxy',
  'symmetry_lab',
  'liquid_light',
  'geometry_pulse',
];
const modeNames = [
  'Neon Flow',
  'Particle Galaxy',
  'Symmetry Lab',
  'Liquid Light',
  'Geometry Pulse',
];
const paletteNames = [
  'Ultraviolet',
  'Borealis',
  'Solar',
  'Rose quartz',
  'Glacier',
  'Monochrome',
];
const palettes = <List<int>>[
  [0xffb086ff, 0xff66e4ff, 0xfff587d5, 0xff7457ff],
  [0xff52ffc5, 0xff52abff, 0xffc8ff77, 0xffb494ff],
  [0xffffbd69, 0xffff6379, 0xffe786ff, 0xffffe9a0],
  [0xffff9acb, 0xffccabff, 0xffffd4e5, 0xff8c85ff],
  [0xff8cdfff, 0xff77a6ff, 0xffb3fff2, 0xffe3f5ff],
  [0xfff1edff, 0xff9693b0, 0xffc3c3d9, 0xff73718b],
];
const backgrounds = [0xff080911, 0xff131024, 0xff071b20, 0xff21131c];
const maxSamples = 12000;
const maxStrokes = 96;
const maxParticles = 1600;
const maxImportBytes = 4 * 1024 * 1024;

double finiteNumber(Object? value, double min, double max) {
  if (value is! num || !value.isFinite || value < min || value > max) {
    throw const FormatException('number');
  }
  return value.toDouble();
}

int checkedInt(Object? value, int min, int max) {
  if (value is! int || value < min || value > max) {
    throw const FormatException('integer');
  }
  return value;
}

class ArtSettings {
  const ArtSettings({
    this.mode = ArtMode.neonFlow,
    this.instrument = -1,
    this.speed = .65,
    this.density = .55,
    this.trail = .75,
    this.symmetry = 6,
    this.rotation = 0,
    this.palette = 0,
    this.background = 0,
    this.autoArt = true,
  });
  final ArtMode mode;

  /// -1 keeps the five original engines; 0..99 selects new procedural engines.
  final int instrument;
  final double speed, density, trail, rotation;
  final int symmetry, palette, background;
  final bool autoArt;
  ArtSettings copyWith({
    ArtMode? mode,
    int? instrument,
    double? speed,
    double? density,
    double? trail,
    int? symmetry,
    double? rotation,
    int? palette,
    int? background,
    bool? autoArt,
  }) => ArtSettings(
    mode: mode ?? this.mode,
    instrument: instrument ?? this.instrument,
    speed: speed ?? this.speed,
    density: density ?? this.density,
    trail: trail ?? this.trail,
    symmetry: symmetry ?? this.symmetry,
    rotation: rotation ?? this.rotation,
    palette: palette ?? this.palette,
    background: background ?? this.background,
    autoArt: autoArt ?? this.autoArt,
  );
  Map<String, Object> toJson() => {
    'mode': modeIds[mode.index],
    'instrument': instrument,
    'speed': speed,
    'density': density,
    'trail': trail,
    'symmetry': symmetry,
    'rotation': rotation,
    'palette': palette,
    'colors': palettes[palette],
    'background': background,
    'autoArt': autoArt,
  };
  factory ArtSettings.fromJson(Map<String, dynamic> j) {
    final i = modeIds.indexWhere((id) => id == j['mode']);
    if (i < 0 ||
        j['symmetry'] is! int ||
        ![2, 4, 6, 8, 12].contains(j['symmetry']) ||
        j['autoArt'] is! bool) {
      throw const FormatException('settings');
    }
    // Backward compatible with JSON documents saved before the new catalog.
    final instrument = j.containsKey('instrument')
        ? checkedInt(j['instrument'], -1, 99)
        : -1;
    final p = checkedInt(j['palette'], 0, palettes.length - 1);
    if (jsonEncode(j['colors']) != jsonEncode(palettes[p])) {
      throw const FormatException('palette');
    }
    return ArtSettings(
      mode: ArtMode.values[i],
      instrument: instrument,
      speed: finiteNumber(j['speed'], 0, 1),
      density: finiteNumber(j['density'], .05, 1),
      trail: finiteNumber(j['trail'], .1, 1),
      symmetry: j['symmetry'] as int,
      rotation: finiteNumber(j['rotation'], -math.pi, math.pi),
      palette: p,
      background: checkedInt(j['background'], 0, backgrounds.length - 1),
      autoArt: j['autoArt'] as bool,
    );
  }
}

class ArtPoint {
  const ArtPoint(this.x, this.y, this.pressure, this.velocity, this.time);
  final double x, y, pressure, velocity, time;
  List<double> toJson() => [x, y, pressure, velocity, time];
  factory ArtPoint.fromJson(Object? raw) {
    if (raw is! List || raw.length != 5) throw const FormatException('point');
    return ArtPoint(
      finiteNumber(raw[0], 0, 1),
      finiteNumber(raw[1], 0, 1),
      finiteNumber(raw[2], .1, 1),
      finiteNumber(raw[3], 0, 10),
      finiteNumber(raw[4], 0, 1e9),
    );
  }
}

class ArtStroke {
  ArtStroke(this.points, this.color);
  final List<ArtPoint> points;
  final int color;
  ArtStroke clone() => ArtStroke(List.of(points), color);
  Map<String, Object> toJson() => {
    'color': color,
    'points': points.map((p) => p.toJson()).toList(),
  };
}

class ArtDocument {
  ArtDocument({
    required this.id,
    required this.name,
    required this.seed,
    required this.time,
    required this.settings,
    required this.strokes,
    required this.particles,
    required this.randomState,
    this.savedAt = '',
  });
  final String id, name, savedAt;
  final int seed, randomState;
  final double time;
  final ArtSettings settings;
  final List<ArtStroke> strokes;
  final Float64List particles;
  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'algorithmVersion': 1,
    'id': id,
    'name': name,
    'seed': seed,
    'time': time,
    'settings': settings.toJson(),
    'savedAt': savedAt,
    'randomState': randomState,
    'strokes': strokes.map((s) => s.toJson()).toList(),
    'particles': particles.toList(),
  };
}

class ProjectCodec {
  static String encode(ArtDocument document) => jsonEncode(document.toJson());
  static ArtDocument decode(String source) {
    if (source.length > maxImportBytes ||
        (source.length > maxImportBytes ~/ 3 &&
            utf8.encode(source).length > maxImportBytes)) {
      throw const FormatException('size');
    }
    // Check nesting before handing untrusted content to the JSON parser.
    var depth = 0, quoted = false, escaped = false;
    for (final c in source.codeUnits) {
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (c == 92) {
          escaped = true;
        } else if (c == 34) {
          quoted = false;
        }
      } else if (c == 34) {
        quoted = true;
      } else if (c == 91 || c == 123) {
        if (++depth > 16) throw const FormatException('depth');
      } else if (c == 93 || c == 125) {
        if (--depth < 0) throw const FormatException('json');
      }
    }
    final raw = jsonDecode(source);
    if (raw is! Map<String, dynamic> ||
        raw['schemaVersion'] != 1 ||
        raw['algorithmVersion'] != 1) {
      throw const FormatException('version');
    }
    if (raw['id'] is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(raw['id'] as String)) {
      throw const FormatException('id');
    }
    if (raw['name'] is! String ||
        (raw['name'] as String).trim().isEmpty ||
        (raw['name'] as String).length > 100) {
      throw const FormatException('name');
    }
    final strokes = <ArtStroke>[];
    final list = raw['strokes'];
    if (list is! List || list.length > maxStrokes) {
      throw const FormatException('strokes');
    }
    var samples = 0;
    for (final s in list) {
      if (s is! Map || s['points'] is! List) {
        throw const FormatException('stroke');
      }
      final pts = s['points'] as List;
      samples += pts.length;
      if (pts.isEmpty || pts.length > 1024 || samples > maxSamples) {
        throw const FormatException('samples');
      }
      strokes.add(
        ArtStroke(
          pts.map(ArtPoint.fromJson).toList(),
          checkedInt(s['color'], 0, 3),
        ),
      );
    }
    final particles = raw['particles'];
    if (particles is! List ||
        particles.length > maxParticles * 8 ||
        particles.length % 8 != 0) {
      throw const FormatException('particles');
    }
    final pool = Float64List(particles.length);
    const mins = [-.5, -.5, -10.0, -10.0, 0.0, .1, .1, 0.0];
    const maxs = [1.5, 1.5, 10.0, 10.0, 60.0, 60.0, 8.0, 1.0];
    for (var i = 0; i < pool.length; i++) {
      pool[i] = finiteNumber(particles[i], mins[i % 8], maxs[i % 8]);
    }
    if (raw['settings'] is! Map<String, dynamic>) {
      throw const FormatException('settings');
    }
    final saved = raw['savedAt'];
    if (saved is! String || saved.length > 40) {
      throw const FormatException('date');
    }
    return ArtDocument(
      id: raw['id'] as String,
      name: (raw['name'] as String).trim(),
      seed: checkedInt(raw['seed'], 1, 0xffffffff),
      randomState: checkedInt(raw['randomState'], 1, 0xffffffff),
      time: finiteNumber(raw['time'], 0, 1e9),
      settings: ArtSettings.fromJson(raw['settings'] as Map<String, dynamic>),
      strokes: strokes,
      particles: pool,
      savedAt: saved,
    );
  }
}
