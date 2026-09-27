const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const source=fs.readFileSync(path.join(__dirname,'..','app.js'),'utf8');
const body=source.slice(source.indexOf('async function submitOnlineScore('),source.indexOf('function showRankBurst('));
(async()=>{
  for(const status of ['ready','offline','connecting','error']) {
    const calls=[];
    const ctx={state:{game:{responseTimes:[100],total:1,correct:1,maxCombo:1},profile:{id:'own-player'},cloudStatus:status,screen:'result'},
      cloud:{submitScore:async payload=>{calls.push(payload);return {queued:true}}},
      rankingKeyForMode:()=> 'TEXT',render(){},animateResultScore(){},showRankBurst(){},console,Math,Number};
    vm.createContext(ctx);vm.runInContext(body,ctx);
    await ctx.submitOnlineScore(80);
    assert.equal(calls.length,1,`registered result saved while ${status}`);
    assert.equal(ctx.state.rankingSubmit.status,'queued');
    await ctx.submitOnlineScore(80);
    assert.equal(calls.length,1,'same result is not submitted twice');
  }
  console.log('PASS result persists across reconnect/error states and repeated completion');
})().catch(error=>{console.error(error);process.exitCode=1});
