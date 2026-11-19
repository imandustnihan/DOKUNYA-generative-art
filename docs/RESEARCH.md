# ARTPULSE research and engineering decisions

Research date: 2026-11-19. Scope: an offline, free Flutter/Dart studio, five interactive art modes, durable projects and PNG export. This document distinguishes upstream support from ARTPULSE validation; see PLATFORM_SUPPORT.md and TEST_REPORT.md for actual evidence.

## Technology baseline

The official installation and release pages currently identify Flutter **3.50.0** as stable. Use its bundled Dart, lock dependency versions, and record `flutter --version` with every validation run. Flutter's official platform matrix includes Android, iOS, Windows, macOS, Linux and web. TV operating systems must be evaluated separately. The current matrix lists Android 24+, iOS 15+, Windows 10/11 and macOS 12+; plugin requirements and the generated runner can impose further limits.

Sources: https://docs.flutter.dev/install/manual, https://docs.flutter.dev/install/archive, https://docs.flutter.dev/release/release-notes, https://docs.flutter.dev/reference/supported-platforms

## Rendering alternatives

| Approach | Benefits | Costs / constraints | Decision |
| --- | --- | --- | --- |
| Flutter Canvas / CustomPainter | Shared Dart renderer; predictable bounded geometry; headless image tests | Many paths and large blur layers can become expensive | Core renderer for all five modes |
| FragmentProgram / GLSL | Per-pixel liquid colour fields; compact GPU program | Runtime/backend compatibility, compilation and fill-rate costs | Optional Liquid Light enhancement with a Canvas fallback |
| Full fluid simulation | Physical-looking advection | Several textures and passes; higher memory/battery use; more complex export | Defer; do not call the lightweight liquid field a fluid solver |
| Flame / game engine | Scene/game abstractions | Unneeded dependency and lifecycle layer for five 2D modes | Do not add |
| Rust / C++ simulation | Potential native compute gains | FFI and six toolchains without measured need | Do not add without profiling evidence |
| WebGL-only application | Excellent browser shader control | Separate implementation for native targets | Do not replace Flutter |

CustomPainter's `repaint` Listenable skips widget build and layout on animation ticks. Separate controls from the drawing notifier, isolate the canvas with a RepaintBoundary, reuse Paint objects and particle storage, and avoid full-screen saveLayer blur. PNG export should render only the artwork at a bounded pixel size and dispose native images. High-DPI screens should not automatically multiply the particle budget.

Sources: https://api.flutter.dev/flutter/rendering/CustomPainter-class.html, https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html, https://docs.flutter.dev/perf/best-practices, https://docs.flutter.dev/ui/design/graphics/fragment-shaders

Impeller and Skia both expose Flutter fragment programs, but backend availability is not identical across platforms or Flutter versions. The current Impeller guide identifies iOS as Impeller-only; Android API 29+ defaults to Impeller with documented fallback behavior. Web uses Skia-based renderers. Desktop defaults have changed in recent Flutter releases. Do not infer which renderer a particular device used without logs. Load a shader defensively and keep the Canvas version usable after failure.

Sources: https://docs.flutter.dev/perf/impeller, https://docs.flutter.dev/platform-integration/web, https://docs.flutter.dev/ui/design/graphics/fragment-shaders

## Algorithms and reproducibility

Implement original bounded algorithms rather than importing unreviewed art code. Neon Flow uses smooth sampled curves and user strokes with speed/pressure widths. Particle Galaxy uses a fixed-capacity particle pool, bounded timesteps, softened attraction and damping. Symmetry Lab rotates each stroke about the normalized canvas centre (2/4/6/8/12 sectors). Liquid Light combines slowly varying analytic fields and gradient blobs, with gesture displacement; it is not a Navier–Stokes simulation. Geometry Pulse draws evolving polygons and radial waves centred on interactions.

A seeded integer generator makes initialization reproducible. Smooth lattice value noise is sufficient for flow direction; do not label it Perlin or Simplex noise. Bézier curves are useful for stroke smoothing; L-systems are better suited to later branching presets than the initial interaction model. Preserve seed, algorithm version, time, every accepted stroke sample, settings and particle state in versioned JSON. Reopening is a state restoration, not a lossy regeneration from a thumbnail. Floating point GPU output can differ slightly across backends.

Source for noise concepts: https://thebookofshaders.com/11/ . This book explains interpolation-based noise and explicitly distinguishes value noise from classic Perlin noise. No source code or artwork is copied.

## Input and adaptive layout

Select layouts using actual available width and height, not phone/desktop model names. Compact screens use a bottom tool area and modal inspector; wide screens use a persistent inspector and mode list. Controls scroll when text grows or a landscape phone loses vertical space. Keep normalized art state in a controller outside the layout so rotation, split-screen and fold transitions do not recreate it. Use safe areas, Flutter semantics and focus traversal. Mouse wheel/trackpad and two-finger gestures control the viewport; one finger/stylus creates strokes. Read pressure only when a nontrivial pressure range exists; mouse events receive a neutral pressure.

Sources: https://docs.flutter.dev/ui/adaptive-responsive, https://docs.flutter.dev/ui/adaptive-responsive/large-screens, https://docs.flutter.dev/ui/adaptive-responsive/user-input-accessibility

## Persistence, export and privacy

`file_selector` 1.1.0 is published by flutter.dev under BSD-3-Clause. Its platform table explicitly does **not** support choosing save locations on Android, iOS or web. Use its picker for imports, desktop save dialogs for desktop export, a browser download on web and a native share/save sheet on mobile. Do not wrap unsupported `getSaveLocation()` calls in a success message. `path_provider` supplies native app-private directories. `share_plus` supports file sharing on Android/iOS/macOS/Windows/web, but not Linux; Linux uses its file chooser instead. Review toolchain requirements before adopting share_plus.

Sources: https://pub.dev/packages/file_selector, https://pub.dev/packages/path_provider, https://pub.dev/packages/share_plus

`shared_preferences` warns that writes are asynchronous and not suitable for critical data. Therefore use flushed project files with recoverable replacement on native platforms and transactional IndexedDB on web. Preferences can share the small key-value adapter, but art must never be stored only in volatile widget state. Browser storage can be cleared or quota-limited; allow downloadable JSON backups. Apply import byte, nesting, numeric range, sample count and schema limits before accepting a project. Do not request broad storage, media, network, camera or microphone permissions. No backend, telemetry, advertising or accounts.

Source: https://pub.dev/packages/shared_preferences

## Web and offline delivery

Flutter compiles to JavaScript or Wasm; CanvasKit/Skwasm use browser graphics APIs. Wasm support and allow lists vary across browser versions, particularly Safari and Firefox. Start with the portable JavaScript release build; test Chromium locally and mark other browsers untested until actually exercised. Bundle CanvasKit assets with the build and configure local renderer URLs so an installed app does not depend on a CDN. Flutter no longer supplies a production caching worker by default: add a small versioned app-specific worker, precache the built asset list, use a relative scope for GitHub Pages, and test a reload with network access disabled. First installation still needs a network connection. PWA installation and file sharing differ on iOS; do not promise OS live wallpaper installation.

Sources: https://docs.flutter.dev/platform-integration/web, https://docs.flutter.dev/platform-integration/web/faq, https://docs.flutter.dev/platform-integration/web/initialization, https://docs.flutter.dev/reference/supported-platforms

## Desktop packaging

Use the generated native runners and normal OS windows. Window resizing and DPI changes preserve normalized artwork. A desktop fullscreen adapter is justified platform integration. The current window_manager 0.7.0 changed its API and introduces a general native FFI subsystem. After inspecting the resolved package, this project instead uses small OS-runner method handlers for fullscreen, avoiding an unnecessary window-management framework. All art and simulation stay in Dart. Windows requires a Windows compiler runner, macOS/iOS require macOS and Xcode, Linux requires GTK development tools, CMake, Ninja and Clang. A Linux environment cannot validate an EXE or IPA. Unsigned packages must be labelled, and Apple signing/notarization needs the owner's credentials. Never put signing credentials in the repository. Windows portable instructions must keep DLLs and the data folder together and explain removal under a standard user account.

Sources: https://pub.dev/packages/window_manager, https://docs.flutter.dev/deployment/windows, https://docs.flutter.dev/deployment/linux, https://docs.flutter.dev/deployment/macos, https://docs.flutter.dev/deployment/ios

## TVs: separate toolchains and validation

| Target | Feasible route | Required work before support can be claimed |
| --- | --- | --- |
| Android TV / Google TV | Android runner, dedicated focus-driven UI | Leanback launcher, banner, optional leanback feature, touchscreen not required; D-pad OK/Back tests on TV |
| Fire TV | Android runner without Google service dependency | Fire OS device filtering, remote key behavior, actual GPU and lifecycle tests |
| Samsung Tizen | Samsung Research's flutter-tizen extension | Tizen SDK, device certification, plugin substitutions and real TV validation |
| LG webOS | LG flutter-webos SDK + webOS NDK | Match SDK/engine/device version, replace unsupported plugins, validate on TV |
| Apple tvOS | Community flutter-tvos toolchain | Separate embedder, Xcode, Siri Remote, plugin and signing validation |
| TV browser | Existing web build when WebGL/browser permits | Model-specific memory, WebGL, remote focus and offline checks |

Android's official documentation recommends sharing one application while supplying a distinct TV experience. Declare LEANBACK_LAUNCHER, `android.software.leanback` as optional and `android.hardware.touchscreen` as not required. These declarations alone do not establish TV usability. Amazon documents the same touchscreen filtering requirement and D-pad-driven navigation. A low-power TV should start conservatively; 4K panel resolution is not evidence that the GPU can sustain 4K effects.

Sources: https://developer.android.com/training/tv/get-started/create, https://developer.amazon.com/docs/app-submission/device-filtering-and-compatibility.html, https://developer.amazon.com/docs/fire-tv/design-and-user-experience-guidelines.html

Samsung Research maintains flutter-tizen; its README lists Smart TVs with Tizen 6.0 (2021)+ and a separate CLI. LG announced Flutter for webOS TV on 2026-06-30; its repository requires Flutter-webOS CLI, SDK and webOS NDK. tvOS remains absent from Flutter's official platform matrix, despite the community flutter-tvos project advertising a current toolchain. Treat these as researched ports, not delivered builds.

Sources: https://github.com/flutter-tizen/flutter-tizen, https://developer.samsung.com/smarttv/develop, https://webostv.developer.lge.com/, https://github.com/lg-flutter-webos/flutter-webos, https://fluttertv.dev/

TV mode should favour presets, large controls and ambient generation instead of precision freehand drawing. Respect screen sleep, stop ticking in the background, and hide/move fixed controls in ambient mode. Do not disable the system screensaver or claim that shifting UI eliminates OLED burn-in risk.

## Existing products and open-source approaches

Magic Fluids' own store listing offers presets, configurable effects, pause and captures; it explicitly distinguishes its iOS application from a live wallpaper. Reviewed store listings contain individual complaints about frequent advertising and restricted settings. These are qualitative examples, not a representative user study. Product response: no ads/paywalls, visible export and quality controls, local reusable projects and honest platform labels.

Sources: https://apps.apple.com/us/app/magic-fluids-visual-art-fun/id1437510558, https://apps.apple.com/hu/app/magic-fluids-lite/id1437514764, https://play.google.com/store/apps/details?hl=en&id=fluids.simulation.wallpaper

PavelDoGreat/WebGL-Fluid-Simulation demonstrates a multipass, texture-based browser simulation and has a repository licence. It is an architectural comparison only: ARTPULSE does not incorporate its shaders. Flutter generative-art repositories such as Pierre-Monier/flutter_cool_visuals and rxlabz/algrafx illustrate Canvas-driven experiments, but an experimental repository is not a production dependency. funvas could not be retrieved during this research, so no licence or maintenance claim is made about it. Keep original renderer code and review all resolved package licences in THIRD_PARTY_NOTICES.md.

Sources: https://github.com/PavelDoGreat/WebGL-Fluid-Simulation, https://github.com/PavelDoGreat/WebGL-Fluid-Simulation/blob/master/LICENSE, https://github.com/Pierre-Monier/flutter_cool_visuals, https://github.com/rxlabz/algrafx

## Quality, power and evidence

Profiles must change actual work: pool capacity, curve samples, geometry count and glow passes. Auto begins conservatively and uses sustained frame timing with hysteresis; it cannot identify every low-RAM device or measure battery temperature without an OS adapter. Use bounded pools, a maximum event/sample count and capped export dimensions. Suspend animation on lifecycle changes, respect reduced motion and offer a 30-fps Eco profile. Avoid rapid brightness oscillation or flashes. Profile build/raster times, not only the ticker interval. Thermal APIs may inform a later native adapter; do not imply frame timing is a temperature measurement.

Sources: https://docs.flutter.dev/perf, https://docs.flutter.dev/tools/devtools/performance, https://developer.android.com/games/optimize/power, https://developer.android.com/games/optimize/adpf/thermal

## Naming and publication

A GitHub search found existing public repositories called ArtPulse belonging to other owners. ARTPULSE is therefore not a globally unique name and no trademark clearance is claimed. A scoped search found no existing ARTPULSE repository for the connected owner. Prefer `artpulse-generative-art` for discoverability. MIT applies to original application code; Flutter and dependency notices remain separate. Only publish release binaries after an actual successful build, and distinguish automated tests from physical-device validation.
