const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const root=path.join(__dirname,'..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const ctx={window:{}};vm.runInNewContext(read('phase11-art-v205.js'),ctx);const art=ctx.window.IntervalCosmosArt;
assert.equal(art.avatars.length,25);assert.equal(new Set(art.avatars).size,25);assert.equal(art.courses.length,11);
for(const id of art.avatars){const svg=read(`assets/art/v1/avatars/${id}.svg`);assert(svg.includes('viewBox="0 0 100 100"'));assert(!/<script|<image|https?:\/\/(?!www.w3.org)/.test(svg));assert(art.avatarHTML(id).includes(`${id}.svg`));assert(read('sql/avatar-catalog-v2.0.5.sql').includes(`'${id}'`))}
for(const id of art.courses)assert(read(`assets/art/v1/courses/${id}.svg`).includes('<svg'));
assert(art.avatarHTML('\"><script>alert(1)</script>').includes('/nova.svg'));assert.equal(art.courseHTML('../anything'),'');
const sw=read('sw.js');for(const family of ['avatars','courses','frames'])for(const f of fs.readdirSync(path.join(root,'assets/art/v1',family)))assert(sw.includes(`assets/art/v1/${family}/${f}`),`uncached: ${family}/${f}`);
assert(read('phase3-v205.js').includes("avatar.dataset.artAvatar !== (row.avatar_id || 'nova')"));
assert(read('phase11-frames-v205.css').includes('prefers-reduced-motion:reduce'));
console.log('PASS 25 safe avatar identities, 11 course assets, catalog coverage, offline cache, repeated ranking render guard, reduced motion');
