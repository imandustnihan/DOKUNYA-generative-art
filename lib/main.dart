import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app/artpulse_app.dart';
import 'app/studio_controller.dart';
import 'app/theme.dart';
import 'core/storage/store.dart';
import 'core/storage/platform_files.dart';
import 'core/storage/project_repository.dart';
import 'localization/strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/LICENSE.txt');
    yield LicenseEntryWithLineBreaks(['Noto Sans'], text);
    final roboto = await rootBundle.loadString(
      'assets/fonts/Roboto_LICENSE.txt',
    );
    yield LicenseEntryWithLineBreaks(['Roboto (Flutter web fallback)'], roboto);
  });
  try {
    await initializeWindow();
  } catch (_) {
    /* A normal OS window is still usable. */
  }
  await launchArtPulse();
}

Future<void> launchArtPulse() async {
  try {
    final store = await createStore();
    final controller = StudioController(ProjectRepository(store));
    const forceTv = bool.fromEnvironment('ARTPULSE_TV');
    await controller.load(
      television: forceTv || await detectTv(),
      deviceLanguage:
          WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
    runApp(ArtPulseApp(controller: controller));
    await controller.loadShader();
  } catch (_) {
    final language =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final t = ArtStrings(language);
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: artTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ArtMark(size: 56),
                    const SizedBox(height: 24),
                    Text(t('startupError'), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: launchArtPulse,
                      child: Text(t('retry')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
