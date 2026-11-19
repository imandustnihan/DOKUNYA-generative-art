"""Generate an exact cache manifest from an already successful Flutter web build."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]/'build/web'
# Keep the SDK fallback font's complete licence with the distributable.
licence=root/'licenses/Roboto.txt'
licence.parent.mkdir(exist_ok=True)
licence.write_bytes((Path(__file__).resolve().parents[1]/'assets/fonts/Roboto_LICENSE.txt').read_bytes())
files=sorted(p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.name!='artpulse_sw.js' and not p.name.endswith('.map'))
if 'main.dart.js' not in files:
    raise SystemExit('Run flutter build web --release first')
hash_=hashlib.sha256()
for name in files:
    hash_.update(name.encode());hash_.update((root/name).read_bytes())
version=hash_.hexdigest()[:16]
worker='''// Built by tool/prepare_web.py. Only same-origin application resources are cached.
const CACHE='artpulse-VERSION';
const RESOURCES=FILES;
self.addEventListener('install',event=>event.waitUntil((async()=>{
  const cache=await caches.open(CACHE);
  await cache.addAll(RESOURCES.map(p=>new Request(new URL(p,self.registration.scope),{cache:'reload'})));
  await self.skipWaiting();
})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  for(const key of await caches.keys()) if(key.startsWith('artpulse-')&&key!==CACHE)await caches.delete(key);
  await self.clients.claim();
})()));
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET'||new URL(event.request.url).origin!==self.location.origin)return;
  event.respondWith((async()=>{
    const cached=await caches.match(event.request,{ignoreSearch:true});
    if(cached)return cached;
    try{return await fetch(event.request);}
    catch(error){if(event.request.mode==='navigate')return await caches.match(new URL('index.html',self.registration.scope));throw error;}
  })());
});
'''.replace('VERSION',version).replace('FILES',json.dumps(['./']+files))
(root/'artpulse_sw.js').write_text(worker)
print(json.dumps({'cache_version':version,'resources':len(files)+1,'bytes':sum((root/p).stat().st_size for p in files)}))
