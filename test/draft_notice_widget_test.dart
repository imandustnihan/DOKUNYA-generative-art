import 'package:dokunya/app/dokunya_app.dart';
import 'package:dokunya/app/studio_controller.dart';
import 'package:dokunya/core/storage/key_value_store.dart';
import 'package:dokunya/core/storage/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pumpMobile(
  WidgetTester tester,
  StudioController controller,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    controller.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(DokunyaApp(controller: controller));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recovered artwork is announced on a compact mobile display', (
    tester,
  ) async {
    final repo = ProjectRepository(MemoryStore());
    final first = StudioController(repo, animate: false);
    await first.load();
    first.begin(1, .1, .2, .7);
    first.end(1);
    expect(await first.flushDraft(), isTrue);
    first.dispose();

    final recovered = StudioController(repo, animate: false);
    await recovered.load();
    await recovered.preferences(language: 'tr');
    await pumpMobile(tester, recovered);
    expect(find.text('Tamamlanmamış çizim kurtarıldı'), findsOneWidget);
  });

  testWidgets('damaged drafts warn users but stay on disk', (tester) async {
    final store = MemoryStore();
    await store.write('workspace_draft', '{corrupt');
    final repo = ProjectRepository(store);
    final controller = StudioController(repo, animate: false);
    await controller.load();
    await controller.preferences(language: 'az');
    await pumpMobile(tester, controller);
    expect(
      find.text('Qaralama açılmadı. İlkin məlumatlar silinmədən saxlanıldı.'),
      findsOneWidget,
    );
    expect(await store.read('workspace_draft'), '{corrupt');
  });
}
