# Performance evidence

Measured on 2026-11-19 in a shared Linux x64 virtual environment, Dart 3.14.0 AOT, 9 reported logical processors. This is **CPU simulation timing only**. It excludes Flutter painting, GPU submission, display scheduling, battery use and thermals, and must not be converted into a device FPS claim. Other build/test work shared the host, so scheduling outliers are visible.

Each profile has 1,200 warm-up steps and 3,600 measured Particle Galaxy steps at density 1. Reproduce with `dart compile exe tool/benchmark.dart -o build/artpulse-benchmark`, then run that executable. Raw values are in `docs/evidence/performance.json`.

| Profile | Live particles | Mean step, ms | p95 step, ms | Max step, ms |
| --- | --- | --- | --- | --- |
| Eco | 80 | 0.0123 | 0.0120 | 5.192 |
| Low | 180 | 0.0287 | 0.0280 | 1.104 |
| Medium | 400 | 0.0637 | 0.0990 | 0.686 |
| High | 800 | 0.1222 | 0.2040 | 3.352 |
| Ultra | 1400 | 0.3871 | 1.1760 | 36.137 |

## Actual work budgets

| Profile | Maximum particle budget | Curve samples | Base ribbons | Glow | Target tick rate | Optional liquid shader |
| --- | --- | --- | --- | --- | --- | --- |
| Eco | 80 | 40 | 4 | Off | 30 | Off |
| Low | 180 | 64 | 6 | Off | 60 | Off |
| Medium | 400 | 90 | 9 | On | 60 | Off |
| High | 800 | 130 | 12 | On | 60 | On if loaded |
| Ultra | 1,400 | 180 | 16 | On | Up to 120 | On if loaded |

Density scales the particle target and procedural detail. The storage pool is a fixed 1,600×8 Float64 buffer, approximately 100 KiB, and gesture storage has a 12,000-sample cap. Auto begins at Low for small screens/TVs and Medium otherwise, then adjusts from sustained `FrameTiming` build/raster work. 120 slow samples reduce detail; 900 fast samples allow a cautious increase. Profile changes affect real work even when motion is paused.

The retained painter repaints through a Listenable; the canvas widget/painter is not replaced every tick. A test verifies this identity while time advances. Paint and palette objects are reused. Animation stops on background/lifecycle suspension, explicit pause or reduced motion. Export uses a separate bounded image and disposes native resources.

The 12,000-step stability test exercises capped timesteps, particle budgets and finite state; it is a simulated session, not a multi-hour device soak test. Snapshot restoration checks the next simulation step, not just matching JSON text. The noise hash uses portable 32-bit multiplication to avoid JavaScript integer precision loss.

## What is not measured / implemented

No physical-phone/TV DevTools profile trace, battery drain, thermal throttling, 4K fill-rate, high-refresh display, GPU memory leak qualification or before/after device benchmark is claimed. Dynamic raster-resolution scaling is not implemented; profiles reduce geometry/particles/glow/shader use. The app displays measured frame work when the platform provides it, but this report does not invent a DevTools trace. Measure those targets in profile mode on representative devices before promoting a production release.
