import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/graphics/art_engine.dart';
import '../core/graphics/art_model.dart';
import '../core/graphics/art_painter.dart';
import '../core/performance/quality.dart';
import '../core/storage/platform_files.dart';
import '../features/studio/art_canvas.dart';
import '../features/presets/presets.dart';
import 'studio_controller.dart';
import 'theme.dart';

class DokunyaApp extends StatelessWidget {
  const DokunyaApp({super.key, required this.controller});
  final StudioController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: 'DOKUNYA',
      debugShowCheckedModeBanner: false,
      theme: artTheme(tv: controller.tv),
      locale: Locale(controller.locale),
      supportedLocales: const [Locale('en'), Locale('tr'), Locale('az')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => controller.tv
          ? MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: _TvTextScaler(MediaQuery.textScalerOf(context)),
              ),
              child: child!,
            )
          : child!,
      home: Workspace(controller: controller),
    ),
  );
}

class _TvTextScaler extends TextScaler {
  const _TvTextScaler(this.base);
  final TextScaler base;
  @override
  double scale(double fontSize) => base.scale(fontSize) * 1.3;
  @override
  double get textScaleFactor => scale(14) / 14;
}

class Workspace extends StatefulWidget {
  const Workspace({super.key, required this.controller});
  final StudioController controller;
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  StudioController get c => widget.controller;
  bool _controlsVisible = true;
  bool _shortLayout = false;
  Timer? _hideTimer;
  (double, double) _remotePoint = (.5, .5);
  String t(String key) => c.t(key);
  void toast(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(key))));
  }

  Future<void> _guard(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      toast('storageError');
    }
  }

  Future<void> _save() async {
    if (c.busy) return;
    final input = TextEditingController(text: c.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('save')),
        content: TextField(
          key: const ValueKey('project_name'),
          controller: input,
          autofocus: true,
          maxLength: 100,
          decoration: InputDecoration(labelText: t('projectName')),
          onSubmitted: (s) {
            if (s.trim().isNotEmpty) Navigator.pop(context, s.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel')),
          ),
          FilledButton(
            key: const ValueKey('confirm_save'),
            onPressed: () {
              if (input.text.trim().isNotEmpty) {
                Navigator.pop(context, input.text.trim());
              }
            },
            child: Text(t('save')),
          ),
        ],
      ),
    );
    // Let the dialog's outgoing animation detach its editable field.
    if (result != null && mounted) {
      setState(() => c.busy = true);
      await _guard(() async {
        await c.save(result);
        toast('saved');
      });
      if (mounted) setState(() => c.busy = false);
    }
    Future<void>.delayed(const Duration(milliseconds: 300), input.dispose);
  }

  Rect _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return const Rect.fromLTWH(0, 0, 100, 100);
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _export({bool project = false}) async {
    if (c.busy) return;
    final wasPaused = c.paused;
    if (!wasPaused) c.pause();
    setState(() => c.busy = true);
    await _guard(() async {
      final doc = c.engine.snapshot(
        id: c.projectId ?? 'art_export',
        name: c.name,
      );
      final name = 'DOKUNYA_${doc.seed}';
      if (project) {
        final ok = await exportBytes(
          Uint8List.fromList(utf8.encode(ProjectCodec.encode(doc))),
          '$name.dokunya.json',
          'application/json',
          _shareOrigin(),
        );
        toast(ok ? 'exported' : 'cancelled');
      } else {
        final snapshot = ArtEngine()..restore(doc);
        snapshot.budget = c.engine.budget;
        final aspect = c.canvasSize.width / math.max(1, c.canvasSize.height);
        final w = aspect >= 1 ? 2048 : (2048 * aspect).round();
        final h = aspect >= 1 ? (2048 / aspect).round() : 2048;
        final shader = c.exportShader();
        try {
          final bytes = await renderPng(
            snapshot,
            width: w,
            height: h,
            shader: shader,
          );
          final ok = await exportBytes(
            bytes,
            '$name.png',
            'image/png',
            _shareOrigin(),
          );
          toast(ok ? 'exported' : 'cancelled');
        } finally {
          shader?.dispose();
        }
      }
    });
    if (!wasPaused) c.pause();
    if (mounted) setState(() => c.busy = false);
  }

  Future<void> _import() async {
    try {
      const group = XTypeGroup(
        label: 'DOKUNYA / RENIZ / ARTPULSE JSON',
        extensions: ['json'],
        mimeTypes: ['application/json'],
        uniformTypeIdentifiers: ['public.json'],
      );
      final file = await openFile(acceptedTypeGroups: [group]);
      if (file == null) return;
      if (await file.length() > maxImportBytes) {
        throw const FormatException('size');
      }
      final doc = ProjectCodec.decode(await file.readAsString());
      if (!mounted) return;
      if (!await _preserveWork()) return;
      c.open(doc, imported: true);
      toast('imported');
    } catch (_) {
      toast('invalidProject');
    }
  }

  Future<bool> _preserveWork() async {
    if (!c.dirty || c.engine.strokes.isEmpty) return true;
    // Keep the existing piece as a recoverable local composition before replacing it.
    try {
      await c.save(c.name);
      return true;
    } catch (_) {
      toast('storageError');
      return false;
    }
  }

  Future<void> _usePreset(ArtPreset preset) async {
    if (!await _preserveWork()) return;
    c.preset(preset.mode, palette: preset.palette, seed: preset.seed);
  }

  Future<void> _focus({bool ambient = false}) async {
    final value = !c.focusMode;
    if (ambient) {
      c.setAmbient(true);
    } else {
      c.setFocus(value);
    }
    _controlsVisible = true;
    _armHide();
    try {
      await setFullscreen(c.focusMode);
    } catch (_) {
      /* Focus canvas still works on platforms without OS fullscreen. */
    }
  }

  void _armHide() {
    _hideTimer?.cancel();
    if (c.ambient) {
      _hideTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    }
  }

  void _reveal() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _armHide();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey,
        control =
            HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (c.focusMode) {
        unawaited(_focus());
        return KeyEventResult.handled;
      }
      if (c.page != WorkspacePage.studio) {
        c.navigate(WorkspacePage.studio);
        return KeyEventResult.handled;
      }
    }
    if (c.ambient && !_controlsVisible) {
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
        _reveal();
        return KeyEventResult.handled;
      }
      var (x, y) = _remotePoint;
      if (key == LogicalKeyboardKey.arrowLeft) {
        x -= .04;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        x += .04;
      } else if (key == LogicalKeyboardKey.arrowUp) {
        y -= .04;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        y += .04;
      } else {
        return KeyEventResult.ignored;
      }
      _remotePoint = (x.clamp(0, 1), y.clamp(0, 1));
      c.begin(-101, _remotePoint.$1, _remotePoint.$2, .6);
      c.end(-101);
      return KeyEventResult.handled;
    }
    if (c.page != WorkspacePage.studio || c.busy) return KeyEventResult.ignored;
    if (control && key == LogicalKeyboardKey.keyS) {
      unawaited(_save());
      return KeyEventResult.handled;
    }
    if (control && key == LogicalKeyboardKey.keyZ) {
      HardwareKeyboard.instance.isShiftPressed ? c.redo() : c.undo();
      return KeyEventResult.handled;
    }
    if (control) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.space) {
      c.pause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      unawaited(_focus());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyC) {
      c.clear();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      c.restart();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit0) {
      c.resetView();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    c.configureSize(media.size, systemReduceMotion: media.disableAnimations);
    return PopScope(
      canPop: !c.focusMode && c.page == WorkspacePage.studio,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (c.focusMode) {
          unawaited(_focus());
        } else {
          c.navigate(WorkspacePage.studio);
        }
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _key,
        child: Scaffold(
          body: SafeArea(
            child: c.focusMode
                ? _focusCanvas()
                : LayoutBuilder(
                    builder: (context, bounds) {
                      final compact = bounds.maxWidth < 760;
                      _shortLayout =
                          bounds.maxHeight < 460 &&
                          bounds.maxWidth >= 500 &&
                          bounds.maxWidth < 930;
                      if (_shortLayout) {
                        return Row(
                          children: [
                            _navigation(short: true),
                            Expanded(child: _pageContent()),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _header(bounds.maxWidth),
                          Expanded(
                            child: Row(
                              children: [
                                if (!compact) _navigation(),
                                Expanded(child: _pageContent()),
                              ],
                            ),
                          ),
                          if (compact) _bottomNavigation(),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _pageContent() => switch (c.page) {
    WorkspacePage.studio => _studio(),
    WorkspacePage.home => _home(),
    WorkspacePage.gallery => _gallery(),
    WorkspacePage.settings => _settings(),
  };
  Widget _header(double width) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: width < 500 ? 12 : 24,
      vertical: 10,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        const ArtMark(size: 32),
        const SizedBox(width: 10),
        const Flexible(
          child: Text(
            'DOKUNYA',
            maxLines: 1,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
        ),
        if (width >= 1000) ...[
          const SizedBox(width: 18),
          Container(width: 1, height: 24, color: line),
          const SizedBox(width: 18),
          Text(
            t('offline'),
            style: const TextStyle(
              color: muted,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
        ],
        const Spacer(),
        if (c.page == WorkspacePage.studio) ...[
          if (width >= 950)
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Text(
                t(c.dirty ? 'unsaved' : 'local'),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
          if (width >= 550)
            OutlinedButton.icon(
              key: const ValueKey('action_export'),
              onPressed: c.busy ? null : () => _export(),
              icon: const Icon(Icons.north_east, size: 18),
              label: Text(t('export')),
            ),
          if (width >= 550) const SizedBox(width: 10),
          if (width >= 550)
            FilledButton.icon(
              key: const ValueKey('action_save'),
              onPressed: c.busy ? null : _save,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: Text(t('save')),
            )
          else
            _icon(
              Icons.bookmark_add_outlined,
              'save',
              _save,
              key: const ValueKey('action_save'),
            ),
        ],
        _fileMenu(),
      ],
    ),
  );
  Widget _fileMenu() => PopupMenuButton<String>(
    key: const ValueKey('file_menu'),
    tooltip: t('tools'),
    icon: const Icon(Icons.more_horiz, color: muted),
    onSelected: (value) {
      if (value == 'import') _import();
      if (value == 'png') _export();
      if (value == 'json') _export(project: true);
    },
    itemBuilder: (context) => [
      PopupMenuItem(value: 'import', child: Text(t('import'))),
      PopupMenuItem(value: 'png', enabled: !c.busy, child: Text(t('export'))),
      PopupMenuItem(
        value: 'json',
        enabled: !c.busy,
        child: Text(t('exportProject')),
      ),
    ],
  );
  static const _navIcons = [
    Icons.explore_outlined,
    Icons.gesture,
    Icons.grid_view_rounded,
    Icons.tune,
  ];
  Widget _navigation({bool short = false}) => Container(
    width: short ? 64 : (c.tv ? 96 : 78),
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: line)),
    ),
    child: Column(
      children: [
        SizedBox(height: short ? 4 : 20),
        if (short)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: ArtMark(size: 24),
          ),
        for (final p in WorkspacePage.values)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: short ? 2 : 6,
              horizontal: 8,
            ),
            child: Tooltip(
              message: t(p.name),
              child: Semantics(
                selected: c.page == p,
                label: t(p.name),
                button: true,
                child: InkWell(
                  key: ValueKey('nav_${p.name}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => c.navigate(p),
                  child: Container(
                    width: 60,
                    height: short ? 48 : (c.tv ? 76 : 62),
                    decoration: BoxDecoration(
                      color: c.page == p
                          ? accent.withValues(alpha: .12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _navIcons[p.index],
                          size: 24,
                          color: c.page == p ? accent : muted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t(p.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: c.page == p ? accent : muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        if (!short)
          const Padding(
            padding: EdgeInsets.all(22),
            child: Icon(Icons.wifi_off_outlined, size: 19, color: muted),
          ),
      ],
    ),
  );
  Widget _bottomNavigation() => NavigationBar(
    height: 70,
    selectedIndex: c.page.index,
    onDestinationSelected: (i) => c.navigate(WorkspacePage.values[i]),
    labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    destinations: [
      for (final p in WorkspacePage.values)
        NavigationDestination(
          key: ValueKey('nav_${p.name}'),
          icon: Icon(_navIcons[p.index]),
          label: t(p.name),
        ),
    ],
  );
  Widget _studio() => LayoutBuilder(
    builder: (context, bounds) {
      final large = bounds.maxWidth >= 1230, wide = bounds.maxWidth >= 930;
      return Padding(
        padding: EdgeInsets.all(wide ? 20 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (large) ...[
              SizedBox(width: 190, child: _modeSidebar()),
              const SizedBox(width: 20),
            ],
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: PopupMenuButton<ArtMode>(
                          key: const ValueKey('mode_picker'),
                          tooltip: t('modes'),
                          onSelected: (mode) =>
                              c.change(c.engine.settings.copyWith(mode: mode)),
                          itemBuilder: (context) => [
                            for (final mode in ArtMode.values)
                              PopupMenuItem(
                                value: mode,
                                child: Text(modeNames[mode.index]),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    modeNames[c.engine.settings.mode.index],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.expand_more,
                                  color: muted,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _icon(
                        Icons.center_focus_strong,
                        'viewReset',
                        c.resetView,
                      ),
                      if (!wide)
                        _icon(
                          Icons.tune,
                          'parameters',
                          _showInspector,
                          key: const ValueKey('show_inspector'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: line),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ArtCanvas(controller: c),
                            Positioned(
                              top: 16,
                              left: 18,
                              right: 18,
                              child: IgnorePointer(
                                child: Row(
                                  children: [
                                    Text(
                                      t('liveCanvas'),
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white.withValues(
                                          alpha: .35,
                                        ),
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (c.paused || c.reducedMotion)
                                      Text(
                                        t('motionPaused'),
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (c.engine.strokes.isEmpty)
                              Positioned(
                                bottom: 18,
                                left: 12,
                                right: 12,
                                child: IgnorePointer(
                                  child: Center(
                                    child: Text(
                                      t('hint'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: .38,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _toolbar(),
                  if (bounds.maxHeight > 470)
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xff68d5b6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            c.qualityName,
                            style: const TextStyle(color: muted, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ValueListenableBuilder<double?>(
                          valueListenable: c.timings,
                          builder: (context, ms, _) => Text(
                            ms == null ? '' : '${ms.toStringAsFixed(1)} ms',
                            style: const TextStyle(color: muted, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 20),
              SizedBox(width: c.tv ? 300 : 258, child: _inspector()),
            ],
          ],
        ),
      );
    },
  );
  Widget _modeSidebar() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _section(t('modes')),
      const SizedBox(height: 10),
      Expanded(
        child: ListView.separated(
          itemCount: ArtMode.values.length,
          separatorBuilder: (_, i) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final mode = ArtMode.values[i],
                selected = c.engine.settings.mode == mode;
            return Semantics(
              selected: selected,
              child: InkWell(
                key: ValueKey('mode_${modeIds[i]}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => c.change(c.engine.settings.copyWith(mode: mode)),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: selected ? accent.withValues(alpha: .08) : surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? accent.withValues(alpha: .6) : line,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 72,
                          width: double.infinity,
                          child: _Preview(
                            mode: mode,
                            palette: c.engine.settings.palette,
                            seed: 2749 + i * 173,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              modeNames[i],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle,
                              size: 14,
                              color: accent,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
  Widget _toolbar() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        if (_shortLayout) ...[
          _icon(
            Icons.bookmark_add_outlined,
            'save',
            _save,
            key: const ValueKey('action_save'),
          ),
          _fileMenu(),
        ],
        _icon(
          c.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          c.paused ? 'resume' : 'pause',
          c.pause,
          key: const ValueKey('toggle_pause'),
        ),
        Container(width: 1, height: 22, color: line),
        _icon(Icons.undo, 'undo', c.engine.canUndo ? c.undo : null),
        _icon(Icons.redo, 'redo', c.engine.canRedo ? c.redo : null),
        _icon(
          Icons.delete_sweep_outlined,
          'clear',
          c.clear,
          key: const ValueKey('clear_canvas'),
        ),
        _icon(Icons.shuffle_rounded, 'restart', c.restart),
        Container(width: 1, height: 22, color: line),
        _icon(Icons.fullscreen_rounded, 'focus', _focus),
        _icon(Icons.tv_outlined, 'ambient', () => _focus(ambient: true)),
        _icon(Icons.file_download_outlined, 'export', () => _export()),
      ],
    ),
  );
  Widget _inspector() => Material(
    color: surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('parameters'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.tune, size: 17, color: muted),
            ],
          ),
          const SizedBox(height: 26),
          _section(t('palette')),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var p = 0; p < palettes.length; p++)
                Semantics(
                  label: '${t('paletteName')} ${paletteNames[p]}',
                  button: true,
                  selected: c.engine.settings.palette == p,
                  child: Tooltip(
                    message: paletteNames[p],
                    child: InkWell(
                      key: ValueKey('palette_$p'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          c.change(c.engine.settings.copyWith(palette: p)),
                      child: Container(
                        width: 60,
                        height: 48,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: c.engine.settings.palette == p
                                ? accent
                                : line,
                            width: 1.5,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            gradient: LinearGradient(
                              colors: palettes[p].map(Color.new).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _slider(
            'density',
            c.engine.settings.density,
            (v) => c.change(c.engine.settings.copyWith(density: v)),
            min: .05,
          ),
          _slider(
            'speed',
            c.engine.settings.speed,
            (v) => c.change(c.engine.settings.copyWith(speed: v)),
          ),
          _slider(
            'trail',
            c.engine.settings.trail,
            (v) => c.change(c.engine.settings.copyWith(trail: v)),
            min: .1,
          ),
          if (c.engine.settings.mode == ArtMode.symmetryLab) ...[
            const SizedBox(height: 8),
            _section(t('symmetry')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              children: [
                for (final n in [2, 4, 6, 8, 12])
                  ChoiceChip(
                    label: Text('$n'),
                    selected: c.engine.settings.symmetry == n,
                    onSelected: (_) =>
                        c.change(c.engine.settings.copyWith(symmetry: n)),
                    showCheckmark: false,
                  ),
              ],
            ),
            _slider(
              'rotation',
              (c.engine.settings.rotation + math.pi) / (2 * math.pi),
              (v) => c.change(
                c.engine.settings.copyWith(rotation: v * math.pi * 2 - math.pi),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _section(t('background')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < backgrounds.length; i++)
                Semantics(
                  label: '${t('background')} ${i + 1}',
                  selected: c.engine.settings.background == i,
                  button: true,
                  child: InkWell(
                    key: ValueKey('background_$i'),
                    onTap: () =>
                        c.change(c.engine.settings.copyWith(background: i)),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(backgrounds[i]),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.engine.settings.background == i
                              ? accent
                              : line,
                          width: 2,
                        ),
                      ),
                      child: c.engine.settings.background == i
                          ? const Icon(Icons.check, size: 15, color: accent)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(t('automatic'), style: const TextStyle(fontSize: 12)),
            value: c.engine.settings.autoArt,
            onChanged: (v) => c.change(c.engine.settings.copyWith(autoArt: v)),
          ),
          const Divider(),
          _section(t('quality')),
          const SizedBox(height: 8),
          DropdownButtonFormField<Quality>(
            key: ValueKey('quality_${c.quality.name}'),
            initialValue: c.quality,
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            items: [
              for (final q in Quality.values)
                DropdownMenuItem(
                  value: q,
                  child: Text(t(q.name), style: const TextStyle(fontSize: 12)),
                ),
            ],
            onChanged: (q) {
              if (q != null) _guard(() => c.preferences(profile: q));
            },
          ),
          const SizedBox(height: 16),
          Text(
            t(
              c.engine.settings.mode == ArtMode.liquidLight &&
                      c.engine.budget.shader &&
                      c.shader != null
                  ? 'shader'
                  : 'shaderFallback',
            ),
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        ],
      ),
    ),
  );
  Widget _slider(
    String label,
    double value,
    ValueChanged<double> changed, {
    double min = 0,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              t(label),
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
      Slider(
        key: ValueKey('slider_$label'),
        label: '${(value * 100).round()}%',
        semanticFormatterCallback: (v) => '${t(label)} ${(v * 100).round()}%',
        min: min,
        max: 1,
        value: value,
        onChanged: changed,
      ),
    ],
  );
  void _showInspector() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: AnimatedBuilder(
          animation: c,
          builder: (context, _) => _inspector(),
        ),
      ),
    ),
  );
  Widget _home() => LayoutBuilder(
    builder: (context, bounds) {
      final columns = math.max(
        1,
        (bounds.maxWidth / (c.tv ? 400 : 330)).floor(),
      );
      return ListView(
        padding: EdgeInsets.all(bounds.maxWidth < 600 ? 20 : 32),
        children: [
          _section(t('presets')),
          const SizedBox(height: 12),
          Text(
            t('welcome'),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(t('welcomeHint'), style: const TextStyle(color: muted)),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => c.navigate(WorkspacePage.studio),
              icon: const Icon(Icons.gesture),
              label: Text(t('openStudio')),
            ),
          ),
          const SizedBox(height: 36),
          Text(t('curated'), style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: studioPresets.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: c.tv ? 286 : 254,
            ),
            itemBuilder: (context, i) {
              final p = studioPresets[i];
              return _artCard(
                title: p.name,
                subtitle: modeNames[p.mode.index],
                preview: _Preview(
                  mode: p.mode,
                  palette: p.palette,
                  seed: p.seed,
                ),
                onTap: () => _usePreset(p),
              );
            },
          ),
        ],
      );
    },
  );
  Widget _gallery() => LayoutBuilder(
    builder: (context, bounds) {
      final cols = math.max(1, (bounds.maxWidth / 330).floor());
      return ListView(
        padding: EdgeInsets.all(bounds.maxWidth < 600 ? 20 : 32),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Text(
                t('savedWork'),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _import,
                icon: const Icon(Icons.file_open_outlined),
                label: Text(t('import')),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (c.repository.unreadableProjects > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(t('corrupt'), style: const TextStyle(color: accent)),
            ),
          if (c.documents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: 46,
                    color: accent,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t('emptyGallery'),
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t('emptyGalleryHint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => c.navigate(WorkspacePage.studio),
                    child: Text(t('openStudio')),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: c.documents.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 260,
              ),
              itemBuilder: (context, i) {
                final d = c.documents[i];
                return _artCard(
                  title: d.name,
                  subtitle: modeNames[d.settings.mode.index],
                  preview: _Preview(
                    mode: d.settings.mode,
                    palette: d.settings.palette,
                    seed: d.seed,
                    document: d,
                  ),
                  onTap: () async {
                    if (await _preserveWork()) c.open(d);
                  },
                  trailing: IconButton(
                    tooltip: t('delete'),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _delete(d),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
  Future<void> _delete(ArtDocument document) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('confirmDelete')),
        content: Text(t('deleteHint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _guard(() async {
        await c.delete(document);
        toast('deleted');
      });
    }
  }

  Widget _settings() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            t('settings'),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          _section(t('language')),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final item in [
                ('en', 'English'),
                ('tr', 'Türkçe'),
                ('az', 'Azərbaycanca'),
              ])
                ChoiceChip(
                  key: ValueKey('language_${item.$1}'),
                  label: Text(item.$2),
                  selected: c.locale == item.$1,
                  onSelected: (_) =>
                      _guard(() => c.preferences(language: item.$1)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          SwitchListTile.adaptive(
            key: const ValueKey('reduced_motion'),
            contentPadding: EdgeInsets.zero,
            value: c.reducedMotion,
            onChanged: (v) => _guard(() => c.preferences(reduce: v)),
            title: Text(t('reduceMotion')),
            subtitle: Text(
              t('reduceHint'),
              style: const TextStyle(color: muted),
            ),
          ),
          SwitchListTile.adaptive(
            key: const ValueKey('tv_interface'),
            contentPadding: EdgeInsets.zero,
            value: c.tv,
            onChanged: (v) => _guard(() => c.preferences(television: v)),
            title: Text(t('tv')),
            subtitle: Text(t('tvHint'), style: const TextStyle(color: muted)),
          ),
          const Divider(),
          const SizedBox(height: 16),
          _section(t('quality')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in Quality.values)
                ChoiceChip(
                  label: Text(t(q.name)),
                  selected: c.quality == q,
                  onSelected: (_) => _guard(() => c.preferences(profile: q)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t('qualityHint'),
            style: const TextStyle(color: muted, height: 1.6),
          ),
          const SizedBox(height: 28),
          _section(t('shortcuts')),
          const SizedBox(height: 12),
          Text(
            t('shortcutHelp'),
            style: const TextStyle(color: muted, height: 1.8),
          ),
          const SizedBox(height: 28),
          _section(t('privacy')),
          const SizedBox(height: 12),
          Text(
            t('privacyHint'),
            style: const TextStyle(color: muted, height: 1.8),
          ),
          const SizedBox(height: 16),
          Text(
            t('exportHint'),
            style: const TextStyle(color: muted, height: 1.8),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          const ArtMark(),
          const SizedBox(height: 12),
          Text(t('about')),
          TextButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'DOKUNYA',
              applicationVersion: '0.1.0',
            ),
            icon: const Icon(Icons.code, size: 18),
            label: Text(t('licenses')),
          ),
          const SizedBox(height: 8),
          Text(
            t('version'),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(
            t('support'),
            style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 12),
          Text(
            t('brightness'),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
  Widget _focusCanvas() => Listener(
    onPointerDown: (_) => _reveal(),
    child: Stack(
      fit: StackFit.expand,
      children: [
        ArtCanvas(controller: c),
        if (_controlsVisible) ...[
          Positioned(
            top: 12,
            left: 12,
            child: FilledButton.tonalIcon(
              onPressed: _focus,
              icon: const Icon(Icons.fullscreen_exit),
              label: Text(t('exitFocus')),
            ),
          ),
          Positioned(
            bottom: 18,
            left: 12,
            right: 12,
            child: Center(
              child: Material(
                color: surface.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _icon(
                        c.paused ? Icons.play_arrow : Icons.pause,
                        c.paused ? 'resume' : 'pause',
                        c.pause,
                      ),
                      _icon(Icons.shuffle, 'restart', c.restart),
                      _icon(Icons.bookmark_add_outlined, 'save', _save),
                      _icon(
                        Icons.file_download_outlined,
                        'export',
                        () => _export(),
                      ),
                      _icon(Icons.tune, 'parameters', _showInspector),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
  Widget _icon(IconData icon, String label, VoidCallback? action, {Key? key}) =>
      IconButton(
        key: key,
        tooltip: t(label),
        onPressed: c.busy ? null : action,
        icon: Icon(icon, size: c.tv ? 28 : 21),
      );
  Widget _section(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: muted,
      letterSpacing: 1.5,
    ),
  );
  Widget _artCard({
    required String title,
    required String subtitle,
    required Widget preview,
    required VoidCallback onTap,
    Widget? trailing,
  }) => Material(
    color: surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SizedBox.expand(child: preview)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing
                else
                  const Icon(Icons.arrow_outward, size: 18, color: accent),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Preview extends StatefulWidget {
  const _Preview({
    required this.mode,
    required this.palette,
    required this.seed,
    this.document,
  });
  final ArtMode mode;
  final int palette, seed;
  final ArtDocument? document;
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  late ArtEngine _engine;
  void create() {
    _engine = ArtEngine(
      seed: widget.seed,
      settings: ArtSettings(mode: widget.mode, palette: widget.palette),
    );
    _engine.budget = QualityBudget.profiles[0];
    if (widget.document != null) {
      _engine.restore(widget.document!);
    } else {
      _engine.time = 4;
      for (var i = 0; i < 20; i++) {
        _engine.step(1 / 60);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    create();
  }

  @override
  void didUpdateWidget(_Preview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.palette != widget.palette ||
        oldWidget.seed != widget.seed ||
        oldWidget.document != widget.document) {
      create();
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: ArtPainter(_engine),
      child: const SizedBox.expand(),
    ),
  );
}
