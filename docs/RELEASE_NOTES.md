# DOKUNYA 0.1.3+4

This candidate adds recovery-safe instrument switching, a searchable gallery, view-aware PNGs and an interactive web instrument directory. The public source and the downloadable builds are tracked in [PR 8](https://github.com/imandustnihan/DOKUNYA-generative-art/pull/8).

Android uses the runner's development signing identity. Export important projects to JSON first. An existing installation accepts the APK as an update only when the signing identities match. On Windows extract the complete x64 ZIP before opening DOKUNYA.exe. The Linux archive includes the native executable and libraries. macOS uses an unsigned app bundle. The iOS debug build targets Simulator and requires a matching Xcode simulator on macOS. Device QA and signing status are recorded separately in the [support matrix](PLATFORM_SUPPORT.md).

## DOKUNYA 0.1.2+3 — source rename, pending build and tests

The previous ARTPULSE v0.1.0 packages are historical. This version includes a new display name and does not claim new tested packages yet. See `docs/DOKUNYA_RENAME_TR.md`.

# ARTPULSE 0.1.0 (historical release candidate)

An offline generative art studio with five interactive modes, local editable projects, PNG export, six palettes, ten presets, three interface languages and adaptive controls.

This is the first development release. Android APKs use a development signing certificate. Linux/Windows bundles require their matching desktop runtime libraries. macOS packages are unsigned; iOS simulator builds are for Simulator only, not installable iPhone IPAs. TV interfaces are experimental and do not establish hardware/store compatibility.

Release assets must be produced by a successful build workflow for the tagged source. See PLATFORM_SUPPORT.md and TEST_REPORT.md for the precise validation history. Physical-device and sustained GPU/battery tests remain a separate release qualification step.
