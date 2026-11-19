"""Copy licences from the exact resolved Dart packages; fail on missing notices."""
import json,re,urllib.parse
from pathlib import Path
root=Path(__file__).resolve().parents[1]
config=root/'.dart_tool/package_config.json'
packages=json.loads(config.read_text())['packages']
out=root/'docs/licenses';out.mkdir(parents=True,exist_ok=True)
rows=[];missing=[]
for p in sorted(packages,key=lambda p:p['name']):
 if p['name']=='dokunya':continue
 uri=urllib.parse.urljoin(config.as_uri(),p['rootUri'])
 directory=Path(urllib.parse.unquote(urllib.parse.urlsplit(uri).path))
 candidates=[]
 for base in [directory,*list(directory.parents)[:4]]:
  for name in ['LICENSE','LICENSE.md','LICENSE.txt','COPYING']:
   if (base/name).is_file():candidates.append(base/name)
  if candidates:break
 if not candidates:missing.append(p['name']);continue
 text=candidates[0].read_text(errors='replace')
 if 'MIT License' in text or 'Permission is hereby granted, free of charge' in text:kind='MIT'
 elif 'Apache License' in text:kind='Apache-2.0'
 elif 'Redistribution and use in source and binary forms' in text:kind='BSD (see complete notice)'
 elif 'GNU' in text:kind='Review full notice'
 else:kind='See complete notice'
 (out/(p['name']+'.txt')).write_text(text)
 rows.append((p['name'],directory.name,kind))
body='''# Third-party notices\n\nGenerated from the resolved package set, including SDK and test/build dependencies. Original DOKUNYA code is MIT. Complete dependency notices are preserved in [docs/licenses](docs/licenses). The Flutter engine may include further notices; release bundles include Flutter's generated NOTICES and the app's licence page. No art from comparison repositories was copied.\n\nNoto Sans font files are distributed under the SIL Open Font License; see [the bundled font notice](assets/fonts/LICENSE.txt). The SDK-bundled Roboto web fallback is Apache-2.0; its full notice is in assets/fonts/Roboto_LICENSE.txt. Material icons come from the Flutter SDK's licensed assets.\n\n| Package | Resolved package directory | Licence family |\n| --- | --- | --- |\n'''
body+='\n'.join('| '+ ' | '.join(row) +' |' for row in rows)+'\n'
if missing:body+='\nUnresolved licences: '+', '.join(missing)+'\n'
(root/'THIRD_PARTY_NOTICES.md').write_text(body)
print(json.dumps({'reviewed':len(rows),'missing':missing}))
if missing:raise SystemExit(1)
