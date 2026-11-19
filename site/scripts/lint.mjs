import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const read = (name) => readFileSync(resolve(root, name), 'utf8');
const content = read('src/data/content.ts');
const shell = read('src/layouts/Shell.astro');
const page = read('src/components/Page.astro');
const css = read('src/styles/global.css');

for (const language of ['tr', 'az', 'en']) {
  if (!content.includes('  ' + language + ': {')) throw new Error('Missing translation: ' + language);
}
for (const name of ['Neon Flow', 'Particle Galaxy', 'Symmetry Lab', 'Liquid Light', 'Geometry Pulse']) {
  if (!content.includes(name)) throw new Error('Missing real engine description: ' + name);
}
for (const file of [content, shell, page, css]) {
  if (/reniz/i.test(file)) throw new Error('Old visible brand found');
  if (/https?:\/\/(fonts\.googleapis|fonts\.gstatic|cdn\.)/.test(file)) throw new Error('Remote presentation asset found');
}
if (!page.includes('data-src={studioHref}')) throw new Error('Expected real Flutter studio link is missing');
if (!css.includes('prefers-reduced-motion:reduce')) throw new Error('Reduced motion CSS missing');
console.log('DOKUNYA: locale/branding/accessible site source checks OK');
