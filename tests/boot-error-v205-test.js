const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const source=fs.readFileSync(path.join(__dirname,'..','account-gate.js'),'utf8');
const fn=source.slice(source.indexOf('function showDatabaseRequired('),source.indexOf('async function startApp('));
let html='';
const ctx={panel:value=>{html=value;},header:(k,t,m)=>`${t} ${m}`,esc:value=>String(value)};
vm.createContext(ctx);vm.runInContext(fn,ctx);
for(const [error,expected] of [[{message:'Failed to fetch'},'CONNECTION ERROR'],[{code:'PGRST202'},'DATABASE UPDATE REQUIRED'],[{code:'42P01'},'DATABASE UPDATE REQUIRED'],[{code:'42501'},'CONNECTION ERROR']]){
 ctx.showDatabaseRequired(error);assert(html.includes(expected));assert(html.includes('retry-boot'));assert(html.includes('offline-start'));
 console.log('PASS boot error '+(error.code||'network'));
}
