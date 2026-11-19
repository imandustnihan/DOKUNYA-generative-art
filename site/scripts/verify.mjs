import { existsSync, readFileSync, statSync } from 'node:fs';
import { resolve, join } from 'node:path';

const root = resolve(import.meta.dirname, '..', 'dist');
const base = '/' + (process.env.DOKUNYA_BASE || '/DOKUNYA-generative-art/').replace(/^\/+|\/+$/g, '') + '/';
let count = 0;
for (const language of ['tr', 'az', 'en']) {
  for (const page of ['home', 'discover', 'guide', 'about', 'privacy']) {
    const parts = [language === 'tr' ? '' : language, page === 'home' ? '' : page].filter(Boolean);
    const path = join(root, ...parts, 'index.html');
    if (!existsSync(path)) throw new Error('Missing static HTML ' + path);
    const html = readFileSync(path, 'utf8');
    if (!html.includes('DOKUNYA')) throw new Error('Missing brand in ' + path);
    if (!html.includes('rel="canonical"')) throw new Error('Missing canonical URL in ' + path);
    if (!html.includes(base + 'studio/')) throw new Error('Wrong studio URL in ' + path);
    if (page === 'home' && !html.includes('studio-preview.png')) throw new Error('Missing authentic engine screenshot');
    count++;
  }
}
if (process.argv.includes('--with-studio')) {
  for (const name of ['index.html','main.dart.js','manifest.json','flutter_bootstrap.js','artpulse_sw.js']) {
    const path = join(root, 'studio', name);
    if (!existsSync(path) || statSync(path).size === 0) throw new Error('Missing Flutter studio file: ' + name);
  }
  const page = readFileSync(join(root,'studio','index.html'),'utf8');
  if (!page.includes(base + 'studio/')) throw new Error('Flutter base path differs from Astro site');
  if (!existsSync(join(root,'media','studio-preview.png'))) throw new Error('Missing real Flutter golden screenshot');
  for (const file of ['sitemap.xml', 'robots.txt', '404.html', '.nojekyll']) {
    if (!existsSync(join(root, file))) throw new Error('Missing publish metadata: ' + file);
  }
}
console.log('Verified ' + count + ' localized static HTML pages' + (process.argv.includes('--with-studio') ? ' and real Flutter build' : ''));
