const fs=require('fs'),vm=require('vm'),assert=require('assert');
const root=require('path').join(__dirname,'..');
const read=p=>fs.readFileSync(require('path').join(root,p),'utf8');
const rank=read('ranking-admin-v205.js');
const callbacks=new Map();let next=0,opened=0,enabled=true;
const ctx={allowed:()=>enabled,confirmRemoval:()=>opened++,setTimeout:f=>{callbacks.set(++next,f);return next},clearTimeout:id=>callbacks.delete(id)};
vm.createContext(ctx);vm.runInContext('let hold=null;'+rank.match(/  function cancel\(\)\{[^\n]+/)[0]+rank.match(/  function start\([^\n]+/)[0],ctx);
ctx.start({});ctx.cancel();assert.equal(callbacks.size,0,'release cancels hold');
ctx.start({});callbacks.get(next)();assert.equal(opened,1,'long hold opens confirmation');
enabled=false;ctx.start({});assert.equal(opened,1,'non-admin cannot begin deletion');
assert(rank.includes("input.value!=='Delete'"));assert(rank.includes('p_expected_updated_at'));assert(rank.includes("['pointerup','pointercancel','blur','scroll']"));
const install=read('install-app-v205.js');
for(const nav of [{userAgent:'iPhone',maxTouchPoints:5},{userAgent:'Macintosh',maxTouchPoints:5},{userAgent:'Android',maxTouchPoints:5},{userAgent:'Windows',maxTouchPoints:0}]){
 const c={navigator:nav};vm.createContext(c);vm.runInContext(install.slice(install.indexOf('  function instructions'),install.indexOf('  async function install')),c);const text=c.instructions();assert(text.includes(nav.userAgent==='Android'?'Chrome':nav.maxTouchPoints===5?'共有':'Edge'));
}
assert(read('app-update-v205.js').includes("'interval-cosmos-sync'"));
assert(read('app-update-v205.js').includes("addEventListener('cancel',e=>e.preventDefault())"));
assert(read('sw.js').includes("url.pathname.endsWith('/release.json')"));
const manifest=JSON.parse(read('manifest.webmanifest'));for(const n of [192,512])assert(manifest.icons.some(x=>x.sizes===`${n}x${n}`&&fs.existsSync(require('path').join(root,x.src.split('?')[0]))));
console.log('PASS long hold/cancel/authorization, confirmation contract, device install guidance, update gate and install icons');
