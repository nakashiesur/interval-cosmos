// Render the reviewed, staging-verified catalog. No player data belongs here.
const fs=require('node:fs'),path=require('node:path');
const root=path.join(__dirname,'..');
const achievements=JSON.parse(fs.readFileSync(path.join(root,'docs/reward-review-catalog.json')));
const progression=JSON.parse(fs.readFileSync(path.join(root,'docs/reward-review-progression.json')));
const names=Object.fromEntries(achievements.map(a=>[a.id,a.display_name]));
const esc=s=>String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
function description(a){
 if(!a.hidden)return a.description;
 const r=a.requirement;
 let t=r.type==='perfect_session'?`${r.mode.replaceAll('_',' ')}で${r.min_answers}問以上・全問正解を${r.repeat_count}回。`:r.type==='combo'?`${r.value}コンボ以上を${r.repeat_count}回。`:r.type==='all_modes_perfect'?`主要5モードそれぞれで${r.min_answers}問以上・全問正解（EAR LINKは${r.mode_min_answers.EAR_LINK}問以上）。`:r.ids.map(id=>names[id]).join('・')+'を獲得。';
 if(r.min_sessions)t+=`累計${r.min_sessions}プレイ・通算${r.min_active_days}日以上。`;return t;
}
const sections=[];
function table(title,heads,rows){sections.push({title,heads,rows});}
table('毎日のポイント', ['項目','条件','PT'],[
 ['TEXT / KEYS','各モード1日1回。1プレイ10問以上・正答率50%以上','各20'],
 ['HD TEXT / HD KEYS','各モード1日1回。1プレイ10問以上・正答率50%以上','各25'],
 ['EAR LINK','1日1回。1プレイ5問以上・正答率50%以上','30'],
 ['デイリー3ミッション','達成したミッションごと。抽選内容により変動','各30〜40'],
 ['1日の上限','モードクリア120 ＋ デイリー最大120。実績報酬は別','最大240']]);
table('通算日数の緩和',['以前の案','今回の案'],[['3日','2日'],['5日','3日'],['7日','5日'],['10日','7日'],['14〜15日','10日'],['20日','14日'],['25日','18日'],['30日','20日'],['通算日数専用の実績：15日 / 30日','10日 / 20日'],['連続3・7・10日','変更なし']]);
const frameNames=Object.fromEntries(progression.frames.map(f=>[f.id,f.name]));
table('フレームの必要条件',['フレーム','累計PT','追加条件'],progression.frames.map(f=>[f.name,f.points.toLocaleString('ja-JP'),f.id==='normal'?'初期状態':`${frameNames[f.rule.requires_frame]}を所持`+(f.rule.ids?` ＋ ${f.id==='omega'?'全39実績':f.rule.ids.map(id=>names[id]).join('・')}`:'')]));
table('練習量別の試算（実績PTを含まない保守的な目安）',['練習例 / 1日PT','BRONZE','SILVER','GOLD','PLATINUM','COSMIC'],[
 ['基礎：1モード20＋デイリー2件60＝80 PT',2,7,15,28,44],
 ['慣れてきた段階：2モード40＋デイリー3件90＝130 PT',2,4,10,17,27],
 ['幅広く練習：4〜5モード＋デイリー＝平均200 PT',1,3,6,11,18]
].map(row=>row.map((v,i)=>i?`${v}日`:v)));
const labels={basic:'プレイ回数',accuracy:'正確さ',combo:'コンボ',mode:'モード',interval:'音程の習熟',streak:'継続・通算日数',ranking:'ランキング',hidden:'シークレット（確認用に条件を表示）'};
for(const [key,label]of Object.entries(labels))table(label,['実績','条件','PT'],achievements.filter(a=>a.category===key).map(a=>[a.display_name,description(a),a.points]));
table('デイリーミッション詳細',['ミッション','条件','PT'],progression.daily.map(d=>[d.name,d.description,d.points]));
const intro='公開前の確認案です。獲得済みの実績・フレーム・ポイントは保持します。通算日は日本時間で数え、休んでも減りません。PTは消費せず、累計値で判定します。新しいモードクリアPTは適用後の通常ゲームが対象で、課題・PRACTICEは対象外です。オフラインの記録は同期後にプレイした日付へ加算します。';
const assumptions='試算は学生の実測値や上達予測ではありません。毎回、記載したモード条件と抽選されたデイリーを達成するという仮定です。日数は遊んだ日の累計で、週2回なら暦では約3.5倍かかります。実績PTが加わると早まりますが、上位フレームはPTだけでは解放されません。全実績にはランキング1位も含まれるため、全員が同じ時期に最上位へ到達する設計ではありません。';
let html=`<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>実績とポイントの調整案</title><style>body{background:#080e1e;color:#edf5ff;font:16px/1.7 system-ui;margin:auto;padding:28px;max-width:1150px}a{color:#76e5ff}h1{font-size:28px}h2{margin-top:38px;color:#76e5ff;font-size:21px}p{color:#adbed9}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:12px;border-bottom:1px solid #2a3852;overflow-wrap:anywhere}th{color:#94adc9;background:#14223a}.scroll{overflow:auto}nav{display:flex;gap:20px;flex-wrap:wrap}@media(max-width:650px){body{padding:12px;font-size:13px}td,th{padding:8px}h1{font-size:23px}}</style><nav><a href="mastery-frames-preview.html">動くフレームを見る</a><a href="practice-rewards-browser.html">ゲーム内の表示を見る</a></nav><h1>実績とポイントの調整案</h1><p>${intro}</p><p>実績は全39件・合計4,775 PT。モードクリアとデイリーは別枠です。短い練習にも報酬を用意し、上位は正確さ・幅広いモード・積み重ねで目指します。</p><p>${assumptions}</p>`;
let md='# 実績とポイントの調整案\n\n'+intro+'\n\n'+assumptions+'\n';
for(const s of sections){html+=`<h2>${s.title}</h2><div class="scroll"><table><thead><tr>${s.heads.map(x=>`<th>${esc(x)}</th>`).join('')}</tr></thead><tbody>${s.rows.map(row=>`<tr>${row.map(x=>`<td>${esc(x)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;md+=`\n## ${s.title}\n\n| ${s.heads.join(' | ')} |\n| ${s.heads.map(()=>'---').join(' | ')} |\n`+s.rows.map(row=>'| '+row.join(' | ')+' |').join('\n')+'\n';}
fs.writeFileSync(path.join(root,'tests/reward-review.html'),html+'</html>');
fs.writeFileSync(path.join(root,'docs/V2.0.5_REWARD_REVIEW.md'),md);
console.log('Rendered review: 39 achievements, daily/mode rewards, frame PT, explicitly hypothetical pacing.');
