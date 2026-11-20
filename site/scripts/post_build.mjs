import { writeFileSync, existsSync } from 'node:fs';
import { resolve, join } from 'node:path';

const root = resolve(import.meta.dirname, '..', 'dist');
const base = '/' + (process.env.DOKUNYA_BASE || '/DOKUNYA-generative-art/').replace(/^\/+|\/+$/g, '') + '/';
const origin = 'https://imandustnihan.github.io';
const locales = ['tr', 'az', 'en'];
const pages = ['home', 'discover', 'guide', 'about', 'privacy'];
if (!existsSync(join(root, 'index.html'))) throw new Error('Astro static site missing: dist/index.html');

const routes = locales.flatMap((lang) => pages.map((page) =>
  base + [lang === 'tr' ? '' : lang, page === 'home' ? '' : page].filter(Boolean).join('/') +
  (lang === 'tr' && page === 'home' ? '' : '/')
));
const urls = routes.map((p) => '  <url><loc>' + origin + p + '</loc></url>').join('\n');
writeFileSync(join(root, 'sitemap.xml'), '<?xml version="1.0" encoding="utf-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + urls + '\n</urlset>\n');
writeFileSync(join(root, 'robots.txt'), 'User-agent: *\nAllow: /\nSitemap: ' + origin + base + 'sitemap.xml\n');
writeFileSync(join(root, '.nojekyll'), '');
console.log(JSON.stringify({ pages: routes.length, base, sitemap: 'sitemap.xml' }));
