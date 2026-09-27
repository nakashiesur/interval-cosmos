const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const root=path.join(__dirname,'..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const ctx={window:{}};vm.runInNewContext(read('phase11-art-v205.js'),ctx);const art=ctx.window.IntervalCosmosArt;
assert.equal(art.avatars.length,25);assert.equal(new Set(art.avatars).size,25);assert.equal(art.courses.length,11);
for(const id of art.avatars){const svg=read(`assets/art/v1/avatars/${id}.svg`);assert(svg.includes('viewBox="0 0 100 100"'));assert(!/<script|<image|https?:\/\/(?!www.w3.org)/.test(svg));assert(art.avatarHTML(id).includes(`${id}.svg`));assert(read('sql/avatar-catalog-v2.0.5.sql').includes(`'${id}'`))}
for(const id of art.courses)assert(read(`assets/art/v1/courses/${id}.svg`).includes('<svg'));
assert(art.avatarHTML('\"><script>alert(1)</script>').includes('/nova.svg'));assert.equal(art.courseHTML('../anything'),'');
const sw=read('sw.js');for(const family of ['avatars','courses','frames','achievements'])for(const f of fs.readdirSync(path.join(root,'assets/art/v1',family)))assert(sw.includes(`assets/art/v1/${family}/${f}`),`uncached: ${family}/${f}`);
assert(read('phase3-v205.js').includes("avatar.dataset.artAvatar !== (row.avatar_id || 'nova')"));
assert(read('phase11-frames-v205.css').includes('prefers-reduced-motion:reduce'));
console.log('PASS 25 safe avatar identities, 11 course assets, catalog coverage, offline cache, repeated ranking render guard, reduced motion');

assert.equal(art.achievements.length,31);
for(const id of art.achievements){
 const svg=read(`assets/art/v1/achievements/${id}.svg`);
 assert(!/<script|<image|https?:\/\/(?!www.w3.org)/.test(svg));
 assert(art.achievementHTML(id,{unlocked:true}).includes(`${id}.svg`));
 if(id.startsWith('hidden_'))assert.equal(art.achievementHTML(id),'?');
}
assert.equal(art.achievementHTML('first_signal',{hidden:true}),'?');
assert.equal(art.achievementHTML('../secret',{unlocked:true}),'✓');
const progression=read('phase5-progression-v205.js');
const renderer=progression.slice(progression.indexOf('function achievementHTML('),progression.indexOf('function ',progression.indexOf('function achievementHTML(')+10));
const renderContext={window:ctx.window,LABELS:{},esc:s=>s};vm.createContext(renderContext);vm.runInContext(renderer,renderContext);
const secret=renderContext.achievementHTML({achievements:[{id:'hidden_singularity',hidden:true,unlocked:false,name:'SECRET NAME',description:'SECRET CONDITION'}]});
assert(!secret.includes('SECRET NAME'));assert(!secret.includes('SECRET CONDITION'));assert(!secret.includes('.svg'));assert(secret.includes('CONDITION ???'));
const visible=renderContext.achievementHTML({achievements:[{id:'first_signal',unlocked:true,name:'FIRST SIGNAL'}]});assert(visible.includes('first_signal.svg'));assert(visible.includes('data-v205-feature'));
console.log('PASS 31 achievement badges, concealed secret artwork and text, unlocked feature control');
