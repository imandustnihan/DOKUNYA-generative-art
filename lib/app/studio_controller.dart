import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/graphics/art_engine.dart';
import '../core/graphics/art_model.dart';
import '../core/graphics/engine_catalog.dart';
import '../core/performance/quality.dart';
import '../core/storage/project_repository.dart';
import '../localization/strings.dart';

enum WorkspacePage { home, studio, gallery, settings }

class ArtClock extends ChangeNotifier {
  void pulse() => notifyListeners();
}

class StudioController extends ChangeNotifier with WidgetsBindingObserver {
  StudioController(this.repository, {this.animate = true}) {
    _ticker = Ticker(_tick);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addTimingsCallback(_timings);
  }
  final ProjectRepository repository;
  final bool animate;
  final engine = ArtEngine();
  final clock = ArtClock();
  final autoQuality = AutoQuality();
  final timings = ValueNotifier<double?>(null);
  late final Ticker _ticker;
  ui.FragmentProgram? _program;
  ui.FragmentShader? shader;
  String locale = 'en';
  Quality quality = Quality.auto;
  bool reducedMotion = false,
      tv = false,
      paused = false,
      focusMode = false,
      ambient = false,
      foreground = true,
      busy = false;
  bool dirty = false;
  WorkspacePage page = WorkspacePage.studio;
  List<ArtDocument> documents = [];
  /// Locally persisted instrument favorites; never sent to a server.
  final Set<int> favoriteInstruments = <int>{};
  String? projectId;
  String name = 'Untitled 01';
  double zoom = 1;
  Offset pan = Offset.zero;
  Size canvasSize = const Size(1600, 1000);
  Duration? _last;
  bool _configured = false, _disposed = false;
  ArtStrings get t => ArtStrings(locale);
  bool get motionRunning =>
      animate &&
      !paused &&
      !reducedMotion &&
      foreground &&
      page == WorkspacePage.studio;
  String get qualityName => quality == Quality.auto
      ? '${t('auto')} · ${t(Quality.values[autoQuality.level].name)}'
      : t(quality.name);
  Future<void> load({
    bool television = false,
    String deviceLanguage = 'en',
  }) async {
    final pref = await repository.preferences();
    final language = pref['locale'] ?? deviceLanguage;
    locale = ['en', 'tr', 'az'].contains(language) ? language as String : 'en';
    // Treat preference files as untrusted: ignore malformed and out-of-range IDs.
    final favorites = pref['favoriteInstruments'];
    favoriteInstruments
      ..clear()
      ..addAll(favorites is List
          ? favorites.whereType<int>().where((id) => id >= 0 && id < instrumentCount)
          : const <int>[]);
    reducedMotion = pref['reducedMotion'] == true;
    tv = television || pref['tv'] == true;
    quality =
        Quality.values.where((q) => q.name == pref['quality']).firstOrNull ??
        Quality.auto;
    await refreshGallery();
    _setBudget();
    _syncTicker();
    notifyListeners();
  }

  Future<void> loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/liquid.frag');
      if (_disposed) return;
      _program = program;
      shader = program.fragmentShader();
      clock.pulse();
    } catch (_) {
      /* Canvas field remains the complete fallback. */
    }
  }

  ui.FragmentShader? exportShader() => _program?.fragmentShader();
  void configureSize(Size size, {bool systemReduceMotion = false}) {
    if (!_configured) {
      autoQuality.conservativeStart(shortestSide: size.shortestSide, tv: tv);
      _configured = true;
      _setBudget();
    }
    if (systemReduceMotion && !reducedMotion) {
      reducedMotion = true;
      _syncTicker();
    }
  }

  void _setBudget() {
    engine.budget = quality == Quality.auto
        ? QualityBudget.profiles[autoQuality.level]
        : QualityBudget.forQuality(quality);
    final target = (engine.budget.particles * engine.settings.density).round();
    if (engine.particleCount > target) engine.particleCount = target;
  }

  void _tick(Duration elapsed) {
    final interval = 1000000 / engine.budget.fps;
    final previous = _last;
    if (previous == null) {
      _last = elapsed;
      clock.pulse();
      return;
    }
    final dt = elapsed - previous;
    if (dt.inMicroseconds + 300 < interval) return;
    _last = elapsed;
    engine.step(dt.inMicroseconds / 1000000);
    clock.pulse();
  }

  int _timingCount = 0;
  double _timingSum = 0;
  void _timings(List<ui.FrameTiming> list) {
    if (!motionRunning) return;
    var changed = false;
    for (final f in list) {
      final raster = f.rasterDuration.inMicroseconds / 1000;
      final build = f.buildDuration.inMicroseconds / 1000;
      if (quality == Quality.auto && autoQuality.observe(raster, build)) {
        changed = true;
        _setBudget();
      }
      _timingSum += math.max(raster, build);
      _timingCount++;
    }
    if (_timingCount >= 60) {
      timings.value = _timingSum / _timingCount;
      _timingSum = 0;
      _timingCount = 0;
    }
    if (changed) notifyListeners();
  }

  void _syncTicker() {
    _last = null;
    if (motionRunning && !_ticker.isActive) {
      _ticker.start();
    } else if (!motionRunning && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) engine.endAll();
    _syncTicker();
  }

  void navigate(WorkspacePage p) {
    page = p;
    _syncTicker();
    notifyListeners();
  }

  void change(ArtSettings value) {
    engine.settings = value;
    _setBudget();
    dirty = true;
    clock.pulse();
    notifyListeners();
  }

  void begin(int id, double x, double y, double pressure) {
    engine.begin(id, x, y, pressure);
    dirty = true;
    clock.pulse();
    notifyListeners();
  }

  void move(int id, double x, double y, double pressure) {
    engine.move(id, x, y, pressure);
    dirty = true;
    clock.pulse();
  }

  void end(int id) {
    engine.end(id);
    notifyListeners();
  }

  void undo() {
    engine.undo();
    dirty = true;
    clock.pulse();
    notifyListeners();
  }

  void redo() {
    engine.redo();
    dirty = true;
    clock.pulse();
    notifyListeners();
  }

  void clear() {
    engine.clear();
    dirty = true;
    clock.pulse();
    notifyListeners();
  }

  void restart() {
    engine.restart((engine.seed * 1664525 + 1013904223) & 0xffffffff);
    dirty = true;
    clock.pulse();
    notifyListeners();
  }

  void pause() {
    paused = !paused;
    _syncTicker();
    notifyListeners();
  }

  void resetView() {
    zoom = 1;
    pan = Offset.zero;
    clock.pulse();
    notifyListeners();
  }

  void setView(double scale, Offset translation) {
    zoom = scale.clamp(.5, 4);
    pan = translation;
    clock.pulse();
  }

  void setFocus(bool value) {
    focusMode = value;
    if (!value) ambient = false;
    notifyListeners();
  }

  void setAmbient(bool value) {
    ambient = value;
    focusMode = value;
    notifyListeners();
  }

  Future<void> refreshGallery() async {
    documents = await repository.list();
    if (!_disposed) notifyListeners();
  }

  Future<void> save(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 100) {
      throw const FormatException('name');
    }
    final id = projectId ?? 'art_${DateTime.now().microsecondsSinceEpoch}';
    final doc = engine.snapshot(id: id, name: trimmed);
    await repository.save(doc);
    projectId = id;
    name = trimmed;
    dirty = false;
    await refreshGallery();
    notifyListeners();
  }

  void open(ArtDocument document, {bool imported = false}) {
    engine.restore(document);
    projectId = imported ? null : document.id;
    name = document.name;
    dirty = imported;
    page = WorkspacePage.studio;
    resetView();
    _syncTicker();
    clock.pulse();
    notifyListeners();
  }

  Future<void> delete(ArtDocument document) async {
    await repository.delete(document.id);
    if (projectId == document.id) {
      projectId = null;
      dirty = true;
    }
    await refreshGallery();
  }

  void preset(ArtMode mode, {int palette = 0, int seed = 2749}) {
    projectId = null;
    name = '${modeNames[mode.index]} ${seed % 1000}';
    engine.settings = ArtSettings(mode: mode, palette: palette);
    engine.restart(seed);
    page = WorkspacePage.studio;
    dirty = true;
    resetView();
    _setBudget();
    _syncTicker();
    notifyListeners();
  }

  Map<String, Object> _preferenceSnapshot() => {
    'locale': locale,
    'quality': quality.name,
    'reducedMotion': reducedMotion,
    'tv': tv,
    'favoriteInstruments': (favoriteInstruments.toList()..sort()),
  };

  Future<void> toggleFavoriteInstrument(int id) async {
    if (id < 0 || id >= instrumentCount) {
      throw RangeError.range(id, 0, instrumentCount - 1);
    }
    if (!favoriteInstruments.add(id)) favoriteInstruments.remove(id);
    notifyListeners();
    try {
      await repository.savePreferences(_preferenceSnapshot());
    } catch (_) {
      // Avoid showing a favorite that has not been stored successfully.
      if (!favoriteInstruments.add(id)) favoriteInstruments.remove(id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> preferences({
    String? language,
    Quality? profile,
    bool? reduce,
    bool? television,
  }) async {
    if (language != null) locale = language;
    if (profile != null) quality = profile;
    if (reduce != null) reducedMotion = reduce;
    if (television != null) tv = television;
    _setBudget();
    _syncTicker();
    notifyListeners();
    await repository.savePreferences(_preferenceSnapshot());
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.removeTimingsCallback(_timings);
    shader?.dispose();
    clock.dispose();
    timings.dispose();
    super.dispose();
  }
}
