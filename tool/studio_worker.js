// Generated for the exact files in a Flutter release.
const prefix = 'artpulse-scope-' + encodeURIComponent(self.registration.scope) + ':';
const cacheName = prefix + '__BUILD_HASH__';
const resources = __STUDIO_FILES__;
const inScope = url => url.startsWith(self.registration.scope);

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(cacheName);
    await cache.addAll(resources.map(file =>
      new Request(new URL(file, self.registration.scope), {cache: 'reload'})
    ));
    // Existing tabs finish using their own engine and assets before activation.
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key === cacheName) continue;
      if (key.startsWith(prefix)) {
        await caches.delete(key);
      } else if (/^artpulse-[a-f0-9]{16}$/.test(key)) {
        const old = await caches.open(key);
        const entries = await old.keys();
        const ownIndex = new URL('index.html', self.registration.scope).href;
        if (entries.some(entry => entry.url === ownIndex) && entries.every(entry => inScope(entry.url))) {
          await caches.delete(key);
        }
      }
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET' || !inScope(request.url)) return;
  event.respondWith((async () => {
    const cache = await caches.open(cacheName);
    const asset = await cache.match(request, {ignoreSearch: true});
    if (asset) return asset;
    try {
      return await fetch(request);
    } catch (error) {
      if (request.mode === 'navigate') {
        const shell = await cache.match(new URL('index.html', self.registration.scope));
        if (shell) return shell;
      }
      throw error;
    }
  })());
});
