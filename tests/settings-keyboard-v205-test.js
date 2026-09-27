const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync('phase10-ui-foundation-v205.js','utf8');
const context={animateSettingsCategory:id=>context.selected=id};vm.createContext(context);
vm.runInContext(source.slice(source.indexOf('  function handleSettingsTabKey('),source.indexOf('  function improveUnlockContrast(')),context);
let focused=null,prevented=false;
const tabs=['game','controls','ranking','account'].map(id=>({dataset:{v205SettingsCategory:id},classList:{contains:()=>false},focus(){focused=id;}}));
function key(index,key){prevented=false;context.handleSettingsTabKey({key,target:{closest:()=>tabs[index]},currentTarget:{querySelectorAll:()=>tabs},preventDefault(){prevented=true},stopPropagation(){}});}
key(0,'ArrowRight');assert.equal(focused,'controls');assert.equal(context.selected,'controls');assert(prevented);
key(0,'ArrowLeft');assert.equal(focused,'account');key(3,'ArrowRight');assert.equal(focused,'game');key(1,'End');assert.equal(focused,'account');key(2,'Home');assert.equal(focused,'game');
tabs[1].classList.contains=()=>true;key(0,'ArrowRight');assert.equal(focused,'ranking');key(0,'Tab');assert(!prevented);
console.log('PASS settings tab arrow wrapping, Home/End, empty category skipping and native Tab behavior');
