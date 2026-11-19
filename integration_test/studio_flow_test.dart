import 'package:artpulse/app/artpulse_app.dart';
import 'package:artpulse/app/studio_controller.dart';
import 'package:artpulse/core/graphics/art_model.dart';
import 'package:artpulse/core/graphics/art_painter.dart';
import 'package:artpulse/core/storage/store.dart';
import 'package:artpulse/core/storage/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real local storage: gesture, save, new repository, reopen, PNG',
    (tester) async {
      final repository = ProjectRepository(await createStore());
      final c = StudioController(repository, animate: false);
      await c.load();
      c.locale = 'en';
      final id = 'integration_${DateTime.now().microsecondsSinceEpoch}';
      c.projectId = id;
      addTearDown(() async {
        await repository.delete(id);
        c.dispose();
      });
      await tester.pumpWidget(ArtPulseApp(controller: c));
      await tester.pumpAndSettle();
      final canvas = find.byKey(const ValueKey('art_canvas'));
      final gesture = await tester.startGesture(tester.getCenter(canvas));
      await gesture.moveBy(const Offset(30, 40));
      await gesture.up();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('action_save')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('project_name')),
        'Integration artwork',
      );
      await tester.tap(find.byKey(const ValueKey('confirm_save')));
      await tester.pumpAndSettle();
      final another = ProjectRepository(await createStore());
      final saved = (await another.list()).singleWhere((d) => d.id == id);
      c.clear();
      c.open(saved);
      await tester.pumpAndSettle();
      expect(c.engine.strokes, isNotEmpty);
      expect(c.engine.settings.mode, ArtMode.neonFlow);
      final bytes = await renderPng(c.engine, width: 640, height: 480);
      expect(bytes.take(4), [137, 80, 78, 71]);
    },
  );
}
