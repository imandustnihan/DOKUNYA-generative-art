"""Generate the offline cache manifest for an existing Flutter web build."""
import hashlib
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
root = repo / 'build/web'
if not (root / 'main.dart.js').is_file():
    raise SystemExit('Run flutter build web --release first')
licence = root / 'licenses/Roboto.txt'
licence.parent.mkdir(exist_ok=True)
licence.write_bytes((repo / 'assets/fonts/Roboto_LICENSE.txt').read_bytes())

files = sorted(path.relative_to(root).as_posix() for path in root.rglob('*')
               if path.is_file() and path.name != 'artpulse_sw.js' and path.suffix != '.map')
template = (repo / 'tool/studio_worker.js').read_text()
digest = hashlib.sha256(template.encode())
for file in files:
    digest.update(file.encode())
    digest.update((root / file).read_bytes())
version = digest.hexdigest()[:16]
worker = template.replace('__BUILD_HASH__', version).replace('__STUDIO_FILES__', json.dumps(['./', *files]))
(root / 'artpulse_sw.js').write_text(worker)
print(json.dumps({'cache_version': version, 'resources': len(files) + 1,
                  'bytes': sum((root / file).stat().st_size for file in files)}))
