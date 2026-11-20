import 'dart:async';
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
  StudioController(
    this.repository, {
    this.animate = true,
    this.draftDelay = const Duration(seconds: 2),
  }) {
    _ticker = Ticker(_tick);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addTimingsCallback(_timings);
  }
  final ProjectRepository repository;
  final bool animate;
  final Duration draftDelay;
  Timer? _draftTimer;
  int _draftRevision = 0;
  int _workspaceGeneration = 0;
  String? _pendingProjectId;
  bool recoveredOnStartup = false;
  bool draftSaveFailed = false;
  final engine = ArtEngine();
  final clock = ArtClock();
  final autoQuality = AutoQuality();
  final timings = ValueNotifier<double?>(null);
  late final Ticker _ticker;
  ui.FragmentProgram? _program;
  ui.FragmentShader? shader;
  String locale = 'en';
  Quality quality = Quality.auto;
  bool _systemReduceMotion = false, _preferReducedMotion = false;
  bool get reducedMotion => _systemReduceMotion || _preferReducedMotion;
  bool get systemReduceMotion => _systemReduceMotion;
  bool tv = false,
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
      ..addAll(
        favorites is List
            ? favorites.whereType<int>().where(
                (id) => id >= 0 && id < instrumentCount,
              )
            : const <int>[],
      );
    _preferReducedMotion = pref['reducedMotion'] == true;
    tv = television || pref['tv'] == true;
    quality =
        Quality.values.where((q) => q.name == pref['quality']).firstOrNull ??
        Quality.auto;
    await refreshGallery();
    final draft = await repository.loadDraft();
    if (draft != null) {
      final newerManualSave = documents.any(
        (saved) =>
            saved.id == draft.id && saved.savedAt.compareTo(draft.savedAt) >= 0,
      );
      if (!newerManualSave) {
        engine.restore(draft);
        projectId = documents.any((saved) => saved.id == draft.id)
            ? draft.id
            : null;
        name = draft.name;
        dirty = true;
        recoveredOnStartup = true;
      }
    }
    _setBudget();
    _syncTicker();
    notifyListeners();
  }

  Future<void> applyStudioLink(Map<String, String> options) async {
    final language = options['lang'];
    if (language != null &&
        language != locale &&
        ['tr', 'az', 'en'].contains(language)) {
      try {
        await preferences(language: language);
      } catch (_) {
        // The chosen language still applies for this session if storage is full.
      }
    }
    if (dirty) return;
    final id = int.tryParse(options['instrument'] ?? '');
    final mode = modeIds.indexWhere((value) => value == options['mode']);
    if (id != null && id >= 0 && id < instrumentCount) {
      engine.settings = engine.settings.copyWith(
        mode: ArtMode.neonFlow,
        instrument: id,
      );
      name = instrumentName(id);
    } else if (mode >= 0) {
      engine.settings = engine.settings.copyWith(
        mode: ArtMode.values[mode],
        instrument: -1,
      );
      name = modeNames[mode];
    } else {
      return;
    }
    engine.restart(engine.seed);
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
    if (_systemReduceMotion != systemReduceMotion) {
      _systemReduceMotion = systemReduceMotion;
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
    if (!foreground) {
      engine.endAll();
      if (dirty) unawaited(flushDraft());
    }
    _syncTicker();
  }

  void navigate(WorkspacePage p) {
    page = p;
    _syncTicker();
    notifyListeners();
  }

  /// Debounce storage writes without interrupting the drawing loop.
  void _scheduleDraft() {
    if (_disposed || !dirty) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(draftDelay, () {
      _draftTimer = null;
      unawaited(flushDraft());
    });
  }

  /// Preserve the latest workspace; storage failures never erase the canvas.
  Future<bool> flushDraft() async {
    _draftTimer?.cancel();
    _draftTimer = null;
    if (_disposed || !dirty) return false;
    final revision = _draftRevision;
    try {
      final draft = engine.snapshot(
        id: projectId ?? 'autosave_draft',
        name: name.trim().isEmpty ? 'Untitled 01' : name.trim(),
      );
      await repository.saveDraft(draft);
      if (!_disposed) {
        if (revision != _draftRevision) _scheduleDraft();
        if (draftSaveFailed) {
          draftSaveFailed = false;
          notifyListeners();
        }
      }
      return true;
    } catch (_) {
      if (!_disposed) {
        draftSaveFailed = true;
        notifyListeners();
      }
      return false;
    }
  }

  void _markDirty() {
    dirty = true;
    recoveredOnStartup = false;
    _draftRevision++;
    _scheduleDraft();
  }

  void _discardDraft() {
    _workspaceGeneration++;
    _pendingProjectId = null;
    _draftRevision++;
    _draftTimer?.cancel();
    _draftTimer = null;
    recoveredOnStartup = false;
    draftSaveFailed = false;
    // Serialized after earlier draft writes. The new workspace is preserved
    // independently by its next scheduled save.
    unawaited(repository.clearDraft().catchError((Object _) {}));
  }

  void change(ArtSettings value) {
    engine.settings = value;
    _setBudget();
    _markDirty();
    clock.pulse();
    notifyListeners();
  }

  void begin(int id, double x, double y, double pressure) {
    engine.begin(id, x, y, pressure);
    _markDirty();
    clock.pulse();
    notifyListeners();
  }

  void move(int id, double x, double y, double pressure) {
    engine.move(id, x, y, pressure);
    _markDirty();
    clock.pulse();
  }

  void end(int id) {
    engine.end(id);
    if (dirty) _scheduleDraft();
    notifyListeners();
  }

  void undo() {
    engine.undo();
    _markDirty();
    clock.pulse();
    notifyListeners();
  }

  void redo() {
    engine.redo();
    _markDirty();
    clock.pulse();
    notifyListeners();
  }

  void clear() {
    engine.clear();
    _markDirty();
    clock.pulse();
    notifyListeners();
  }

  void restart() {
    engine.restart((engine.seed * 1664525 + 1013904223) & 0xffffffff);
    _markDirty();
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
    final generation = _workspaceGeneration;
    final id =
        projectId ??
        (_pendingProjectId ??= 'art_${DateTime.now().microsecondsSinceEpoch}');
    final snapshotRevision = _draftRevision;
    final doc = engine.snapshot(id: id, name: trimmed);
    try {
      await repository.save(doc);
    } catch (_) {
      _scheduleDraft();
      rethrow;
    }
    if (_disposed || generation != _workspaceGeneration) {
      if (!_disposed) await refreshGallery();
      return;
    }
    projectId = id;
    name = trimmed;
    if (snapshotRevision == _draftRevision) {
      _draftTimer?.cancel();
      _draftTimer = null;
      dirty = false;
      draftSaveFailed = false;
      recoveredOnStartup = false;
      // Enqueue cleanup before another edit or document switch can occur.
      await repository.clearDraft();
    } else {
      // Edits made while the save was in flight still require recovery.
      dirty = true;
      await flushDraft();
    }
    await refreshGallery();
  }

  void open(ArtDocument document, {bool imported = false}) {
    _discardDraft();
    engine.restore(document);
    projectId = imported ? null : document.id;
    name = document.name;
    dirty = imported;
    if (imported) _markDirty();
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
      _pendingProjectId = null;
      _markDirty();
    }
    await refreshGallery();
  }

  void preset(ArtMode mode, {int palette = 0, int seed = 2749}) =>
      _newComposition(
        ArtSettings(mode: mode, palette: palette),
        seed,
        '${modeNames[mode.index]} ${seed % 1000}',
      );

  void startInstrument(int id) {
    RangeError.checkValueInInterval(id, 0, instrumentCount - 1);
    final nextSeed = (engine.seed * 1664525 + 1013904223) & 0xffffffff;
    _newComposition(
      engine.settings.copyWith(mode: ArtMode.neonFlow, instrument: id),
      nextSeed == 0 ? 1 : nextSeed,
      instrumentName(id),
    );
  }

  void _newComposition(ArtSettings settings, int seed, String title) {
    _discardDraft();
    projectId = null;
    name = title;
    engine.settings = settings;
    engine.restart(seed);
    page = WorkspacePage.studio;
    _markDirty();
    resetView();
    _setBudget();
    _syncTicker();
    notifyListeners();
  }

  Map<String, Object> _preferenceSnapshot() => {
    'locale': locale,
    'quality': quality.name,
    'reducedMotion': _preferReducedMotion,
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
    if (reduce != null) _preferReducedMotion = reduce;
    if (television != null) tv = television;
    _setBudget();
    _syncTicker();
    notifyListeners();
    await repository.savePreferences(_preferenceSnapshot());
  }

  @override
  void dispose() {
    if (dirty) unawaited(flushDraft());
    _draftTimer?.cancel();
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
