# Architecture

One Flutter/Dart application supplies the six official platform runners. Android has a small TV-device detector; desktop runners have minimal fullscreen method-channel handlers. No native code performs the art simulation.

| Component | Responsibility |
| --- | --- |
| `lib/core/graphics/art_model.dart` | Versioned document, settings, bounded JSON validation |
| `art_math.dart` | Seeded xorshift generator, value noise, rotations and softened attraction |
| `art_engine.dart` | Normalized input, bounded strokes, fixed-capacity particle pool, snapshots |
| `art_painter.dart` | Five Canvas renderers and artwork-only PNG output |
| `shaders/liquid.frag` | Optional original liquid colour field |
| `lib/core/performance` | Concrete work budgets and sustained frame-time adaptation |
| `lib/core/storage` | Serialized writes, native recoverable files, browser IndexedDB and platform export |
| `lib/app/studio_controller.dart` | UI-independent studio state, separate repaint clock, lifecycle handling |
| `lib/features/studio` | Pointer/stylus/pinch/wheel interaction and isolated canvas |
| `lib/app/artpulse_app.dart` | Workspace, navigation, inspector, gallery, presets, settings and export flows |
| `lib/localization` | Complete action/error labels in English, Turkish and Azerbaijani |

The simulation and renderer do not rebuild the control tree on every frame. A repaint Listenable updates the retained painter directly; its Paint and palette are reused. Global state changes use the controller notifier. Static thumbnails use a low work budget and do not run their own tickers.

Projects use normalized [0,1] input coordinates and store schema/algorithm version 1, seed, RNG state, time, settings, stroke pressure/velocity/time and live particle state. Aspect ratio changes reframe the normalized piece; pixel-perfect screenshots across different viewports/GPUs are not promised. Quality profiles change visual detail as well as work. Active pointer positions are transient and are released when a project is reopened or the app backgrounds.

Native storage writes a flushed temporary file, keeps the previous file as a recovery backup, renames the replacement and then removes the backup. Startup recovers a missing target from its backup. This protects an interrupted replacement; it is not a promise of survival after filesystem/device failure. Browser writes use IndexedDB transaction completion. Small preferences use the same adapter. Exports provide portable backups.

Import accepts at most 4 MiB, 16 nesting levels, 96 strokes, 12,000 samples, 1,024 samples per stroke and 1,600 particle rows. IDs cannot contain path separators. Future schema/algorithm versions are rejected with a clear error until a deliberate migration exists. The repository retains unreadable local files and reports their presence.

Native mobile exports use the OS share sheet. Desktop uses a native save chooser. Web creates a typed Blob download. No broad storage permission is requested. PWA resources and CanvasKit are served from the same origin; `tool/prepare_web.py` derives the exact cache manifest after a successful build.
