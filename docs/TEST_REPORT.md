# Validation report — 2026-11-19

Application: ARTPULSE 0.1.0+1. Core source revision: `b13efda` (later documentation commits do not change runtime code).

## Automated evidence

| Check | Result | Scope |
| --- | --- | --- |
| `flutter pub get` | Passed | Locked Flutter/Dart dependencies |
| `dart format --output=none --set-exit-if-changed .` | Passed | Dart source, tests and tools |
| `flutter analyze` | Passed, no issues | Application, tests and adapters |
| `flutter test` | 38 cases passed | 17 engine/format cases, 4 repository/file cases, 17 widget/render cases |
| Golden comparison | 7 layouts, included in the 38 cases | Small/large phones, landscape, tablet, desktop, TV-sized UI, 2× text |
| Actual shader and PNG | Passed, included in the 38 cases | Liquid GLSL load/render, Canvas fallback, PNG decoding for all five modes |
| Headless browser workflow | 9 flows passed | Chrome 158.0.8127.36, CanvasKit with software SwiftShader |
| OSV package query | 78 resolved hosted packages, 0 advisory matches | Exact locked Pub versions; not a guarantee of absence of vulnerabilities |
| Licence inventory | 86 package/SDK notices, no missing notice | Includes test/build dependencies; font notices retained separately |
| Android APK | Release-mode build succeeded | Development signing, universal APK, min API 24, target/compile API 36 |
| APK signature/archive | Verified | APK v2 signature and archive integrity; no dangerous/network/storage permission |
| Linux x64 | Release bundle built | Dynamic linkage checked; no missing libraries on the build host |
| Web | Release assets built | Local CanvasKit/default font, custom worker/cache manifest |

The browser flows cover real pointer drawing, palette/IndexedDB save, all mode controls, PNG download, editable JSON download, reload/collection/reopen, malformed import feedback, Turkish/Azerbaijani preferences, offline reload retaining data/locale, and no external HTTP requests or uncaught page errors. These are nine grouped flows rather than inflating each assertion into a separate test count.

The offline run cached 47 application resources and then disabled the browser context's network before reload. Its exact result is in `docs/evidence/browser-results.json`. Actual browser screenshots are under `docs/screenshots`; the golden images are separate automated Flutter engine renders in `test/goldens`.

## Important regression checks

- Snapshot restoration preserves strokes, parameters, RNG/particle state and the next simulation step.
- Corrupt schema/algorithm versions, oversized/deep input, invalid IDs/colours/numbers and excess samples are rejected.
- Concurrent repository writes are serialized; a failed write does not poison later writes.
- Native file replacement and interrupted-rename recovery are exercised with actual temporary files.
- Long simulated input sessions remain within particle/sample budgets and finite numeric state.
- Backgrounding and reduced motion stop the real ticker; resuming restarts advancement.
- The painter retains its identity while animation advances, avoiding a widget replacement every tick.
- Rotating during an active stroke preserves its samples, releases transient pointers, and keeps a useful landscape canvas with save/file controls.

## Hardware and toolchain boundaries

The host is Linux x64. Flutter 3.50.0, bundled Dart 3.14.0, Gradle 9.5.0, full JDK 21, Android SDK/NDK/CMake and an isolated Clang/GTK toolchain were used. A JRE-only installation and build-download configuration were corrected before the successful Android build. Tool analytics were suppressed and CI mode avoided Flutter's cloud metadata probe.

No physical Android, iOS, TV, stylus, high-refresh or multi-monitor device was tested. The Linux native window/fullscreen flow has not been driven in a real desktop session. Windows, macOS and iOS were not compiled on this Linux host. GitHub Actions are supplied but have not run until the repository is actually published. `integration_test/studio_flow_test.dart` is supplied for a real platform store/device run; it is not counted as a passed native-device test here.

CPU simulation timings are in PERFORMANCE.md. There is no fabricated DevTools trace, GPU FPS result, battery measurement, thermal test, multi-hour physical soak result, signed iPhone IPA or TV-certified package.
