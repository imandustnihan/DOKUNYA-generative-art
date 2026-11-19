# Known limitations and next work

- First development release, not a universal device-certified product.
- No signed iPhone IPA, macOS notarization or locally built Windows EXE in this Linux environment.
- Android uses development signing until the owner supplies a permanent private release key.
- TV UI is experimental. Android TV/Fire TV hardware, Tizen, webOS and tvOS need their own validation; no special-TV package is claimed.
- Native mobile save/share sheets, Safari/Firefox, physical foldables, multi-monitor setups and stylus pressure hardware need validation.
- Auto quality observes frame work, not physical RAM, temperature or battery charge. Dynamic raster-resolution scaling and thermal API adapters are not implemented.
- Neon/Liquid modes are original visual algorithms; Liquid Light is not a physical fluid solver. Quality changes detail; aspect ratio and GPU backends may change pixels.
- Browser persistence is local and can be cleared. JSON export is the portable backup. Unsaved interaction since the last explicit save is not guaranteed after abrupt application termination.
- Undo/redo applies to stroke additions. It is not a full parameter/layer/timeline history, and clearing/new variations reset the stroke history.
- Layers, GIF/MP4 export, live wallpapers and a timeline are later work.
- The original architecture is intentionally small. The initial workspace UI is centralized; feature extraction is appropriate as the product grows.

Next priorities: qualify a development APK on a midrange Android phone and an entry-level Android TV box; obtain a Windows-runner build; measure real profile-mode build/raster times and sustained battery behavior; then refine preset interaction and export workflows from those results. These are proposed next targets, not completed tests.
