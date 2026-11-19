import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:artpulse/app/artpulse_app.dart';
import 'package:artpulse/app/studio_controller.dart';
import 'package:artpulse/core/graphics/art_model.dart';
import 'package:artpulse/core/graphics/art_engine.dart';
import 'package:artpulse/core/performance/quality.dart';
import 'package:artpulse/core/graphics/art_painter.dart';
import 'package:artpulse/core/storage/key_value_store.dart';
import 'package:artpulse/core/storage/project_repository.dart';

Future<StudioController> boot(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
  double scale = 1,
  bool animate = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  final c = StudioController(
    ProjectRepository(MemoryStore()),
    animate: animate,
  );
  await c.load();
  await tester.pumpWidget(ArtPulseApp(controller: c));
  if (animate) {
    await tester.pump(const Duration(milliseconds: 32));
  } else {
    await tester.pumpAndSettle();
  }
  addTearDown(() {
    c.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('NotoSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('draw, change mode and parameters, save, clear, reopen', (
    tester,
  ) async {
    final c = await boot(tester);
    final canvas = find.byKey(const ValueKey('art_canvas'));
    final center = tester.getCenter(canvas);
    final gesture = await tester.startGesture(center - const Offset(50, 30));
    await gesture.moveBy(const Offset(100, 60));
    await gesture.up();
    await tester.pump();
    expect(c.engine.strokes, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('mode_picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Symmetry Lab').last);
    await tester.pumpAndSettle();
    expect(c.engine.settings.mode, ArtMode.symmetryLab);
    await tester.tap(find.byKey(const ValueKey('palette_1')));
    await tester.pump();
    expect(c.engine.settings.palette, 1);
    final slider = find.byKey(const ValueKey('slider_density'));
    await tester.drag(slider, const Offset(-50, 0));
    await tester.pump();
    expect(c.engine.settings.density, lessThan(.55));
    await tester.tap(find.byKey(const ValueKey('action_save')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('project_name')),
      'Saved gesture',
    );
    await tester.tap(find.byKey(const ValueKey('confirm_save')));
    await tester.pumpAndSettle();
    expect(c.documents, hasLength(1));
    expect(c.documents.first.name, 'Saved gesture');
    c.clear();
    expect(c.engine.strokes, isEmpty);
    c.open(c.documents.first);
    await tester.pump();
    expect(c.engine.strokes, hasLength(1));
    expect(tester.takeException(), isNull);
  });
  for (final config in [
    ('small_phone', const Size(320, 568), 1.0),
    ('large_phone', const Size(430, 932), 1.0),
    ('landscape_phone', const Size(740, 360), 1.0),
    ('tablet', const Size(900, 1100), 1.0),
    ('desktop', const Size(1440, 900), 1.0),
    ('tv', const Size(1920, 1080), 1.0),
    ('large_text', const Size(360, 740), 2.0),
  ]) {
    testWidgets('adaptive ${config.$1} and golden', (tester) async {
      final c = await boot(tester, size: config.$2, scale: config.$3);
      if (config.$1 == 'tv') {
        c.tv = true;
        await tester.pump();
      }
      expect(find.byKey(const ValueKey('art_canvas')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${config.$1}.png'),
      );
      for (final page in [
        WorkspacePage.home,
        WorkspacePage.gallery,
        WorkspacePage.settings,
      ]) {
        c.navigate(page);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${config.$1}: ${page.name}',
        );
      }
    });
  }
  testWidgets('all three locales apply to the actual UI', (tester) async {
    final c = await boot(tester);
    for (final item in [
      ('tr', 'Ayarlar'),
      ('az', 'Ayarlar'),
      ('en', 'Settings'),
    ]) {
      await c.preferences(language: item.$1);
      c.navigate(WorkspacePage.settings);
      await tester.pumpAndSettle();
      expect(find.text(item.$2), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'reduced motion and application background stop time progression',
    (tester) async {
      final c = await boot(tester, animate: false);
      await c.preferences(reduce: true);
      final before = c.engine.time;
      await tester.pump(const Duration(seconds: 1));
      expect(c.engine.time, before);
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(c.foreground, isFalse);
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(c.foreground, isTrue);
    },
  );
  testWidgets('two-finger zoom preserves project content', (tester) async {
    final c = await boot(tester);
    final center = tester.getCenter(find.byKey(const ValueKey('art_canvas')));
    final a = await tester.startGesture(
      center - const Offset(40, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 2,
    );
    await b.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(c.zoom, greaterThan(1));
    await a.up();
    await b.up();
    c.resetView();
    expect(c.zoom, 1);
    expect(c.engine.strokes, isNotEmpty);
  });
  testWidgets('remote-style focus traversal and activation need no mouse', (
    tester,
  ) async {
    final c = await boot(tester, size: const Size(1920, 1080));
    c.tv = true;
    c.navigate(WorkspacePage.home);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('PNG renderer outputs real images for all engines', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final mode in ArtMode.values) {
        final e = ArtEngine(settings: ArtSettings(mode: mode));
        e.begin(1, .25, .25, .8);
        e.move(1, .75, .65, .7);
        e.end(1);
        final bytes = await renderPng(e, width: 400, height: 300);
        expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 400);
        expect(image.height, 300);
        image.dispose();
        codec.dispose();
      }
    });
  });
  testWidgets('real ticker stops in background and with reduced motion', (
    tester,
  ) async {
    final c = await boot(tester, animate: true);
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 32));
    expect(c.engine.time, greaterThan(0));
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    final stopped = c.engine.time;
    await tester.pump(const Duration(seconds: 1));
    expect(c.engine.time, stopped);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 32));
    expect(c.engine.time, greaterThan(stopped));
    await c.preferences(reduce: true);
    final reduced = c.engine.time;
    await tester.pump(const Duration(seconds: 1));
    expect(c.engine.time, reduced);
  });
  testWidgets('Liquid shader loads, renders and retains Canvas fallback', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset('shaders/liquid.frag');
      final shader = program.fragmentShader();
      final e = ArtEngine(
        settings: const ArtSettings(mode: ArtMode.liquidLight),
      );
      e.budget = QualityBudget.profiles[3];
      final gpu = await renderPng(e, width: 320, height: 240, shader: shader);
      e.budget = QualityBudget.profiles[0];
      final fallback = await renderPng(e, width: 320, height: 240);
      expect(gpu.length, greaterThan(1000));
      expect(fallback.length, greaterThan(1000));
      expect(gpu, isNot(fallback));
      shader.dispose();
    });
  });
  testWidgets('animation repaints without replacing the canvas painter', (
    tester,
  ) async {
    final c = await boot(tester, animate: true);
    final before = tester
        .widget<CustomPaint>(find.byKey(const ValueKey('art_paint')))
        .painter;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    final after = tester
        .widget<CustomPaint>(find.byKey(const ValueKey('art_paint')))
        .painter;
    expect(identical(before, after), isTrue);
    expect(c.engine.time, greaterThan(0));
  });
  testWidgets(
    'rotation preserves the drawing and releases transient pointers',
    (tester) async {
      final c = await boot(tester, size: const Size(430, 932));
      final canvas = find.byKey(const ValueKey('art_canvas'));
      final gesture = await tester.startGesture(tester.getCenter(canvas));
      await gesture.moveBy(const Offset(40, 30));
      final samples = c.engine.sampleCount;
      expect(c.engine.pointers, isNotEmpty);
      tester.view.physicalSize = const Size(740, 360);
      await tester.pump();
      await tester.pump();
      expect(c.engine.sampleCount, samples);
      expect(c.engine.pointers, isEmpty);
      expect(tester.getSize(canvas).height, greaterThan(180));
      expect(find.byKey(const ValueKey('action_save')), findsOneWidget);
      await gesture.up();
      expect(tester.takeException(), isNull);
    },
  );
}
