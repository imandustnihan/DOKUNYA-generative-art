/* Optional browser QA: npm install --no-save playwright, then node tool/web_smoke.cjs.
   Uses an ephemeral test browser and fixture artwork only. */
const {chromium}=require('playwright');
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(process.argv[2]||'build/web');
const normalizedBase=(process.env.DOKUNYA_WEB_BASE || '/').replace(/^\/+|\/+$/g,'');
const basePath=normalizedBase ? '/'+normalizedBase+'/' : '/';
const evidence=path.resolve(process.env.ARTPULSE_EVIDENCE||'build/browser-evidence');
fs.mkdirSync(evidence,{recursive:true});
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.ttf':'font/ttf','.otf':'font/otf'};
const results=[];
(async()=>{
 const server=http.createServer((req,res)=>{
  let name=decodeURIComponent(new URL(req.url,'http://local').pathname);
  if(!name.startsWith(basePath)){res.writeHead(404);res.end();return;}
  name='/'+name.slice(basePath.length);
  if(name.endsWith('/'))name+='index.html';
  const file=path.resolve(root,'.'+name);
  if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return;}
  try{const bytes=fs.readFileSync(file);res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream'});res.end(bytes);}
  catch{res.writeHead(404);res.end();}
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const origin='http://127.0.0.1:'+server.address().port;
 const browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE||undefined,headless:true,
  args:['--no-sandbox','--no-zygote','--single-process','--in-process-gpu','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const errors=[],external=new Set();let page;
 try {
  const context=await browser.newContext({viewport:{width:1440,height:900},acceptDownloads:true});
  page=await context.newPage();page.setDefaultTimeout(15000);
  page.on('pageerror',error=>errors.push(String(error)));
  page.on('request',r=>{if(/^https?:/.test(r.url())&&!r.url().startsWith(origin+'/'))external.add(r.url());});
  async function semantics(){
   await page.locator('flutter-view').waitFor({state:'attached',timeout:45000});
   const placeholder=page.locator('flt-semantics-placeholder');
   if(await placeholder.count())await placeholder.evaluate(e=>e.click());
   await page.getByRole('button',{name:/Save project|Projeyi kaydet|Layihəni saxla/}).first().waitFor();
  }
  async function database(){return page.evaluate(()=>new Promise((resolve,reject)=>{
   const req=indexedDB.open('artpulse-studio',1);
   req.onerror=()=>reject(req.error);
   req.onsuccess=()=>{const db=req.result;const tx=db.transaction('documents','readonly');const read=tx.objectStore('documents').getAll();
    read.onsuccess=()=>{resolve(read.result.map(s=>JSON.parse(s)));db.close();};read.onerror=()=>reject(read.error);};
  }));}
  async function save(){
   await page.getByRole('button',{name:'Save project',exact:true}).click({force:true});
   const dialog=page.getByRole('alertdialog');await dialog.waitFor();
   await dialog.getByRole('textbox').fill('Browser verified');
   await dialog.getByRole('button',{name:'Save project',exact:true}).click({force:true});
   await dialog.waitFor({state:'hidden'});
   for(let i=0;i<50;i++){const docs=(await database()).filter(d=>d.name==='Browser verified');if(docs.length)return docs[0];await page.waitForTimeout(50);}
   throw Error('Project was not persisted');
  }
  // Another Studio scope may already have an offline cache on the same origin.
  await page.goto(origin + basePath + 'manifest.json');
  await page.evaluate(async () => {
    const other = await caches.open('artpulse-deadbeefdeadbeef');
    await other.put('/other-studio/index.html', new Response('other studio'));
  });
  await page.goto(origin+basePath,{waitUntil:'domcontentloaded'});await semantics();
  await page.getByRole('button',{name:'Pause',exact:true}).click({force:true});
  await page.getByRole('button',{name:'Resume',exact:true}).waitFor();
  const canvas=page.getByRole('img',{name:'Interactive artwork. Drag to draw; use two fingers to zoom.',exact:true});
  const box=await canvas.boundingBox();assert(box&&box.width>200&&box.width<1300);
  await page.mouse.move(box.x+box.width*.25,box.y+box.height*.4);await page.mouse.down();
  for(let i=0;i<20;i++)await page.mouse.move(box.x+box.width*(.25+i*.02),box.y+box.height*(.4+.1*Math.sin(i*.3)));
  await page.mouse.up();
  await page.getByRole('button',{name:/Borealis Palette Borealis/}).click({force:true});
  const saved=await save();assert(saved.strokes.length>0);assert.equal(saved.settings.palette,1);
  results.push({test:'pointer drawing, palette and IndexedDB save',status:'passed',samples:saved.strokes[0].points.length});
  for(const mode of ['Particle Galaxy','Symmetry Lab','Liquid Light','Geometry Pulse','Neon Flow']){
   await page.getByRole('button',{name:mode,exact:true}).click({force:true});
   await page.getByRole('button',{name:'ART ENGINES '+mode,exact:true}).waitFor();
  }
  results.push({test:'all five engine controls',status:'passed'});
  await page.screenshot({path:path.join(evidence,'studio-desktop.png')});
  await page.setViewportSize({width:390,height:844});await page.waitForTimeout(300);
  await page.screenshot({path:path.join(evidence,'studio-phone.png')});
  await page.setViewportSize({width:1440,height:900});
  const pngPromise=page.waitForEvent('download',{timeout:30000});pngPromise.catch(()=>{});await page.getByRole('button',{name:'Export PNG',exact:true}).first().click({force:true});
  const png=await pngPromise;const pngPath=path.join(evidence,'browser-export.png');await png.saveAs(pngPath);
  assert.deepEqual([...fs.readFileSync(pngPath).subarray(0,8)],[137,80,78,71,13,10,26,10]);
  results.push({test:'PNG browser download',status:'passed',bytes:fs.statSync(pngPath).size});
  for(let i=0;i<50&&!await page.getByRole('button',{name:'Save project',exact:true}).isEnabled();i++)await page.waitForTimeout(50);
  await page.getByRole('button',{name:'Tools',exact:true}).click({force:true});
  fs.writeFileSync(path.join(evidence,'menu-aria.txt'),await page.locator('body').ariaSnapshot());
  const jsonOption=page.getByRole('menuitem',{name:'Export project file',exact:true});await jsonOption.waitFor();
  const jsonPromise=page.waitForEvent('download',{timeout:30000});jsonPromise.catch(()=>{});await jsonOption.click({force:true});
  const jsonFile=await jsonPromise;const jsonPath=path.join(evidence,'browser-project.artpulse.json');await jsonFile.saveAs(jsonPath);
  const exported=JSON.parse(fs.readFileSync(jsonPath,'utf8'));assert.equal(exported.seed,saved.seed);assert(exported.strokes.length>0);
  results.push({test:'editable JSON browser download',status:'passed'});
  await page.reload({waitUntil:'domcontentloaded'});await semantics();
  await page.getByRole('button',{name:/^My collection/}).click({force:true});
  await page.getByRole('group',{name:/^Browser verified /}).click({force:true});
  await page.getByRole('button',{name:'ART ENGINES Neon Flow',exact:true}).waitFor();
  assert((await database()).some(d=>d.name==='Browser verified'&&d.strokes.length>0));
  results.push({test:'reload, collection and reopen',status:'passed'});
  await page.getByRole('button',{name:'Tools',exact:true}).click({force:true});
  const chooserPromise=page.waitForEvent('filechooser');await page.getByRole('menuitem',{name:'Open project file',exact:true}).click({force:true});
  const chooser=await chooserPromise;await chooser.setFiles({name:'broken.artpulse.json',mimeType:'application/json',buffer:Buffer.from('{"schemaVersion":999}')});
  await page.getByText('This project file is damaged, too large or uses an unsupported version.',{exact:true}).first().waitFor();
  results.push({test:'corrupt file import error',status:'passed'});
  await page.getByRole('button',{name:'Tools',exact:true}).click({force:true});
  const validChooser = page.waitForEvent('filechooser');
  await page.getByRole('menuitem',{name:'Open project file',exact:true}).click({force:true});
  await (await validChooser).setFiles(jsonPath);
  await page.getByText('Project opened. Save it to keep a local copy.',{exact:true}).first().waitFor();
  for (let attempt = 0; attempt < 80; attempt++) {
    if ((await database()).some(doc => doc.id === 'autosave_draft' && doc.strokes.length)) break;
    await page.waitForTimeout(100);
  }
  assert((await database()).some(doc => doc.id === 'autosave_draft' && doc.strokes.length));
  await page.reload({waitUntil:'domcontentloaded'}); await semantics();
  await page.getByText('Recovered unfinished canvas',{exact:true}).first().waitFor();
  results.push({test:'JSON reimport and debounced IndexedDB draft recovery after reload', status:'passed'});
  await page.getByRole('button',{name:/^Settings/}).click({force:true});
  fs.writeFileSync(path.join(evidence,'language-aria.txt'),await page.locator('body').ariaSnapshot());
  await page.getByRole('checkbox',{name:'Türkçe',exact:true}).click({force:true});
  await page.getByRole('switch',{name:/^Hareketi azalt/}).waitFor();
  await page.getByRole('checkbox',{name:'Azərbaycanca',exact:true}).click({force:true});
  await page.getByRole('switch',{name:/^Hərəkəti azalt/}).waitFor();
  assert((await database()).some(d=>d.locale==='az'));
  results.push({test:'Turkish and Azerbaijani preferences',status:'passed'});
  await page.getByRole('button',{name:/^Studiya/}).click({force:true});
  await page.evaluate(async()=>{
   await navigator.serviceWorker.ready;
   if(!navigator.serviceWorker.controller)await new Promise(resolve=>navigator.serviceWorker.addEventListener('controllerchange',resolve,{once:true}));
  });
  const cache=await page.evaluate(async()=>({keys:await caches.keys(),count:(await(await caches.open((await caches.keys()).find(k=>k.startsWith('artpulse-scope-')))).keys()).length}));
  assert(cache.count>40);
  assert(cache.keys.includes('artpulse-deadbeefdeadbeef'), 'Another Studio scope lost its offline cache');
  await context.setOffline(true);await page.reload({waitUntil:'domcontentloaded'});await semantics();
  await page.getByRole('button',{name:'Layihəni saxla',exact:true}).waitFor();
  assert((await database()).some(d=>d.name==='Browser verified'));
  results.push({test:'PWA offline reload with saved data and locale',status:'passed',cachedResources:cache.count});
  assert.equal(external.size,0,'Unexpected external requests: '+[...external].join(', '));assert.deepEqual(errors,[]);
  results.push({test:'no external runtime HTTP requests or uncaught page errors',status:'passed'});
  fs.writeFileSync(path.join(evidence,'browser-results.json'),JSON.stringify({browser:await browser.version(),renderer:'CanvasKit / software SwiftShader in an isolated headless test',results,externalRequests:[...external],uncaughtErrors:errors},null,2));
  console.log(JSON.stringify({passed:results.length,browser:await browser.version(),results},null,2));
 } catch(error) {
  if(page){fs.writeFileSync(path.join(evidence,'failure-aria.txt'),await page.locator('body').ariaSnapshot().catch(()=>''));await page.screenshot({path:path.join(evidence,'failure.png')}).catch(()=>{});}
  console.error(JSON.stringify({completed:results,external:[...external],errors},null,2));throw error;
 } finally {await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exit(1);});
