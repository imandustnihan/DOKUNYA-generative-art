# Platform support and validation

## DOKUNYA 0.1.3+4

The [PR 8 check suite](https://github.com/imandustnihan/DOKUNYA-generative-art/pull/8/checks) records quality, native builds and the browser run separately. Download the artifacts from the exact run in the PR. CI retains native archives for 14 days.

| Target | Build and automated coverage | Additional device qualification |
| --- | --- | --- |
| Android | Release-mode development-signed APK, package ID, signing and merged permissions | Physical update, share sheet and Play Protect |
| Windows x64 / Linux x64 | Native runner with engine, plugins and data | End-user display, export dialog and keyboard |
| macOS / iOS | Release app on macOS, debug app for iOS Simulator | macOS signing/notarization and physical iPhone/iPad signing |
| Astro + Flutter Web/PWA | Chromium, IndexedDB, PNG and JSON, actual reimport, recovery, offline reload, repository subpath | Safari/iOS and real low-memory phone |
| Adaptive UI | Seven golden sizes, narrow viewport with keyboard, 3840 × 2160 logical-pixel gallery, remote-style focus | Physical foldable, stylus pressure, Google TV remote, hardware frame rates |
| Tizen / webOS / tvOS | No native build | Separate port and hardware required |

## Historical ARTPULSE coverage

Date: 2026-11-19. Upstream Flutter support is not the same as a tested ARTPULSE release. A generated runner is source support, not a successful build or device result.

| Platform / device group | Source | Local build evidence | Actual validation / limitation |
| --- | --- | --- | --- |
| Android phones / tablets | Yes, minimum API 24 | See TEST_REPORT.md for APK outcome | No physical Android phone/emulator session in this run; share/save sheet behavior still needs device qualification |
| iPhone / iPad | Yes, iOS runner | Not built here | macOS, Xcode and Apple toolchain required; no IPA or iOS test claim |
| Windows 10/11 | Yes, C++ runner | Not built here | Windows compiler required; source fullscreen handler not executed on Windows |
| Linux x64 | Yes, GTK runner | Release bundle built | Headless Flutter engine tests pass; native desktop window/device session has not been qualified |
| macOS | Yes, Swift runner | Not built here | macOS/Xcode required; unsigned source configuration only |
| Web / PWA | Yes | Release static assets built | See TEST_REPORT.md for actual browser smoke/offline results; Chrome does not establish Safari/Firefox support |
| Small/large phones, landscape | Shared adaptive UI | Widget/golden renders | 320×568, 430×932 and 740×360; viewport tests are not hardware tests |
| Tablets / split-screen / desktop | Shared adaptive UI | Widget/golden renders | 900×1100 and 1440×900; state survives layout changes; no folding hinge/physical multi-monitor test |
| TV-sized UI | Experimental | 1920×1080 widget render | Large text, presets and focus traversal; no real remote/OLED/4K performance verification |
| Android TV / Google TV | Android manifest + device detection | Same Android target when built | Leanback launcher/banner and optional touchscreen; no TV-certified APK claim |
| Fire TV | Android source candidate | No separate verified build | API 24+ and plugins must be checked per model; no Google service dependency |
| Samsung Tizen | Port plan | None | Separate flutter-tizen SDK and device/plugin validation required |
| LG webOS | Port plan | None | Separate Flutter-webOS SDK/NDK and device/plugin validation required |
| Apple tvOS | Port plan | None | Community toolchain; no official Flutter tvOS target or tested package |

Browsers other than the explicitly tested one, 90/120+ Hz displays, thermal response, battery consumption, 4K TVs and low-RAM hardware are unqualified. High frame rates are targets governed by display scheduling and hardware, not guarantees. OS live wallpapers and GIF/MP4 export are not implemented.

## TV port sequence

1. Qualify Android TV / Google TV first: launch from Leanback, D-pad traversal, OK/Back, preset selection, ambient control reveal, sleep/resume and storage/export behavior.
2. Use conservative quality on low-power devices. Respect system sleep and the screensaver; the application never requests an indefinite wake lock.
3. Validate the same Android path on each Fire TV family and SDK level.
4. Create Tizen/webOS/tvOS runner files only in their matching SDK environment. Replace unsupported file/share/window adapters while retaining the Dart engine and document format. Check each upstream licence and release compatibility again at port time.

Ambient mode hides controls after eight seconds and reveals them on tap/OK. It avoids permanently displaying the studio controls, but does not establish burn-in prevention or TV certification.
