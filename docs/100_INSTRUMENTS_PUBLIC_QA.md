# DOKUNYA — proposed 100 procedural instruments

This proposal preserves the original five legacy art modes and adds a catalog of 100 named procedural variations across ten drawing families. These are **100 mathematical variants across ten families**, not 100 distinct GPU shaders.

- Legacy projects lacking an `instrument` property keep the original rendering behavior (`instrument: -1`).
- New creations use stable IDs 0–99 in version-one JSON exports.
- Search, live previews and local-only favorites are included.
- Turkish, Azerbaijani and English UI strings are included.
- No source encryption password or secret is committed.

## Release gates
Run formatting, `flutter analyze`, all Flutter unit/widget tests, 100 unique PNG render tests, the existing build matrix and web-browser smoke tests. **Do not merge into main until passing.**

This is a public source proposal, not a deployed release.
