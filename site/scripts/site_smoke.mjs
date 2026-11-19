import { chromium } from 'playwright';
import { createServer } from 'node:http';
import { readFileSync, statSync, existsSync, mkdirSync } from 'node:fs';
import { resolve, join, extname, sep } from 'node:path';
import assert from 'node:assert/strict';

const dist = resolve(import.meta.dirname, '..', 'dist');
const base = '/' + (process.env.DOKUNYA_BASE || '/DOKUNYA-generative-art/').replace(/^\/+|\/+$/g, '') + '/';
const types = { '.html':'text/html; charset=utf-8', '.js':'text/javascript', '.css':'text/css', '.json':'application/json', '.png':'image/png', '.webp':'image/webp', '.svg':'image/svg+xml', '.woff2':'font/woff2', '.ttf':'font/ttf', '.wasm':'application/wasm', '.xml':'application/xml', '.txt':'text/plain' };
const server = createServer((request, response) => {
  const uri = new URL(request.url || '/', 'http://localhost');
  if (!uri.pathname.startsWith(base)) { response.writeHead(404);response.end();return; }
  let relative = uri.pathname.slice(base.length);
  if (relative.endsWith('/') || relative === '') relative += 'index.html';
  const target = resolve(dist, relative);
  if (!target.startsWith(dist + sep)) { response.writeHead(403);response.end();return; }
  if (!existsSync(target) || !statSync(target).isFile()) { response.writeHead(404);response.end();return; }
  response.writeHead(200, { 'Content-Type':types[extname(target)] || 'application/octet-stream', 'Cache-Control':'no-cache' });
  response.end(readFileSync(target));
});
await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
const origin = 'http://127.0.0.1:' + server.address().port;
const browser = await chromium.launch({ headless:true, args:['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'] });
const errors=[];
const evidence = resolve(import.meta.dirname, '..', '..', 'build', 'browser-evidence');
mkdirSync(evidence, { recursive: true });
try {
  const page = await browser.newPage({ viewport:{width:1400,height:880} });
  page.on('pageerror', (error) => errors.push(String(error)));
  await page.goto(origin + base, {waitUntil:'domcontentloaded'});
  assert((await page.locator('h1').innerText()).length > 15, 'Homepage has no real heading');
  assert.equal(await page.locator('.engine-card').count(),5);
  await page.screenshot({path:join(evidence,'premium-home-desktop.png'),fullPage:true});
  const navigation = [
    ['discover/', '.discovery-item', 5],
    ['guide/', '.info-panel', 6],
    ['about/', '.editorial', 1],
    ['privacy/', '.info-panel', 5],
    ['az/', 'h1', 1],
    ['en/discover/', '.discovery-item', 5],
    ['en/guide/', '.info-panel', 6],
  ];
  for (const [path,selector,count] of navigation) {
    const response = await page.goto(origin + base + path, {waitUntil:'domcontentloaded'});
    assert.equal(response.status(),200,'Page does not support direct URL: '+path);
    assert.equal(await page.locator(selector).count(),count, 'Missing content '+path);
  }
  await page.goto(origin + base);
  assert.equal(await page.locator('#live-preview').isHidden(),true);
  await page.locator('[data-preview-open]').click();
  assert.equal(await page.locator('#live-preview').isVisible(),true);
  await page.frameLocator('#live-preview iframe').locator('flutter-view').waitFor({timeout:90000});
  await page.locator('[data-preview-close]').click();
  assert.equal(await page.locator('#live-preview').isHidden(),true);
  await page.setViewportSize({width:390,height:844});
  await page.reload();
  assert.equal(await page.locator('h1').isVisible(),true);
  await page.screenshot({path:join(evidence,'premium-home-mobile.png'),fullPage:true});
  await page.locator('.mobile-nav summary').click();
  assert.equal(await page.locator('.mobile-nav nav').isVisible(),true);
  await page.locator('.mobile-nav a[data-language-choice="az"]').click();
  assert((new URL(page.url())).pathname.endsWith(base+'az/'), 'Mobile locale switch failed');
  const lang=await page.evaluate(()=>localStorage.getItem('dokunya-site-language'));
  assert.equal(lang,'az');
  assert.deepEqual(errors,[], 'Uncaught browser errors');
  console.log(JSON.stringify({status:'passed',type:'real Chromium browser',pages:navigation.length+1,engine:'actual Flutter iframe',mobile:true,locales:true,errors:0}));
} finally {
  await browser.close();
  await new Promise(ok=>server.close(ok));
}
