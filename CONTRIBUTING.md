# Contributing

Use Flutter 3.50.0 and its bundled Dart. Run `flutter pub get`, `dart format .`, `flutter analyze` and `flutter test` before proposing changes. Keep the checked-in lockfile. Linux golden images use bundled Noto Sans and Material Icons; review visible differences before updating a baseline with `flutter test --update-goldens`.

The art engine in `lib/core/graphics` intentionally has no platform dependencies. Add deterministic tests when changing simulation or file formats. Bump the algorithm/schema version when compatibility requires it; never silently reinterpret an existing project. Add a readable user-facing error for storage/import failures.

Use a small branch and pull request describing the concrete behavior, why it changes, and the checks actually run. Distinguish unit/widget tests, virtual devices and physical hardware. New presets and original mathematical art are welcome. Include attribution and a compatible licence for any new third-party asset or code. Do not add telemetry, ads, a backend or paid services to the core product.
