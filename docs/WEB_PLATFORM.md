# DOKUNYA premium web — development notes

This development branch adds an **Astro static website** while preserving the
original Flutter/Dart art engines. The public website is meant to be deployed
at the repository subpath on GitHub Pages.

- Static pages: '/', '/discover/', '/guide/', '/about/', '/privacy/'.
- Azerbaijani and English localized routes: '/az/...' and '/en/...'.
- **Real Flutter Web** is built as '/studio/' and is never replaced by an
  HTML simulation. The home page loads a screenshot sourced from the Flutter
  golden test; the live iframe loads the real engine only on request.
- The art project library remains in the original IndexedDB database and
  browser origin. Existing JSON schema and native app identifiers remain unchanged.
- Studio PWA files and service worker stay under '/studio/' scope. The service
  worker's original technical name is retained for compatibility.
- The website itself uses no hosted database, analytics, or API keys.
- Domain changes **do not** migrate browser storage automatically. Back up
  important projects as editable JSON before changing origin.
- Brand changes do not migrate Android signing keys or native bundle IDs.

## Local web integration

Use Node 22+ and Flutter 3.50.0:

    cd site
    npm install
    npm run check
    npm run lint
    npm run build

From the repository root, set DOKUNYA_BASE to the exact Pages repository path,
then build Flutter using the same base with '/studio/' appended:

    flutter pub get
    flutter test
    flutter build web --release --no-web-resources-cdn --base-href "/DOKUNYA-generative-art/studio/"
    python3 tool/prepare_web.py

Copy 'build/web/.' to 'site/dist/studio/', and copy
'test/goldens/desktop.png' to 'site/dist/media/studio-preview.png'.
Finally run 'node site/scripts/post_build.mjs' and
'node site/scripts/verify.mjs --with-studio'.

The GitHub Actions workflow automates the above with a base path derived from
the actual repository name. It packages a single Pages artifact.

## GitHub Pages manual prerequisite

The earlier deploy failed with 404 even though Flutter tests, web build,
and upload completed. The repository administrator must configure
**Settings → Pages → Build and deployment → Source → GitHub Actions**.
Without that setting, the deployment has not been verified as live.

## Validation levels

Static source checks and CI building are different from real-browser and
physical-device tests. CI must publish its actual status. Screenshots are
automated Flutter renders; they are not hardware device screenshots.
The website does not host a shared public gallery. Performance targets
such as 60 FPS must be measured per device; they are not guarantees.
