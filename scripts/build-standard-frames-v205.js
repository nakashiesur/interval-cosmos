const fs=require('fs'),path=require('path');
const circle=(r,color,extra='')=>`<circle cx="90" cy="90" r="${r}" fill="none" stroke="${color}" ${extra}/>`;
const star=(x,y,c,size=7)=>`<path d="M${x} ${y-size} L${x+2} ${y-2} L${x+size} ${y} L${x+2} ${y+2} L${x} ${y+size} L${x-2} ${y+2} L${x-size} ${y} L${x-2} ${y-2}Z" fill="${c}" stroke="none"/>`;
const designs=[
['ノーマル','NORMAL','すっきりした白い一重の輪。',circle(76,'#dfeaf7')],
['ブロンズ','BRONZE','落ち着いた銅色。下に小さな印。',circle(76,'#d69773')+'<path d="M90 159l7 7-7 7-7-7Z" fill="#d69773" stroke="none"/>'],
['シルバー','SILVER','左右のアクセントで引き締める。',circle(76,'#c8d5e5')+circle(76,'#eef4ff','stroke-dasharray="35 204" transform="rotate(-13 90 90)" stroke-width="6"')],
['ゴールド','GOLD','控えめな金色と頂点のダイヤ。',circle(76,'#e5c378')+'<path d="M90 4l6 10-6 10-6-10Z" fill="#e5c378" stroke="none"/>'],
['プラチナ','PLATINUM','白とアイスブルーの二重の輪。',circle(76,'#eff6ff','stroke-dasharray="225 14"')+circle(81,'#a6d3e2','stroke-dasharray="240 14"')],
['コズミック','COSMIC','3つの衛星がゆっくり周回。',circle(76,'#64deef')+'<g class="spin">'+[0,120,240].map(a=>`<circle cx="90" cy="14" r="4" fill="#a9f5ff" stroke="none" transform="rotate(${a} 90 90)"/>`).join('')+'</g>'],
['オーロラ','AURORA','シアンと紫の弧がゆっくり巡る。','<g class="spin">'+circle(77,'#70e6f3','stroke-dasharray="90 31"')+'</g><g class="spin reverse">'+circle(82,'#c3adfc','stroke-dasharray="55 74"')+'</g>']];

const ids=['normal','bronze','silver','gold','platinum','cosmic','aurora'];
const out=path.join(__dirname,'../assets/art/v1/frames');
const motion='@keyframes spin{to{transform:rotate(360deg)}}.spin{transform-origin:90px 90px;animation:spin 18s linear infinite}.reverse{animation-direction:reverse;animation-duration:24s}@media(prefers-reduced-motion:reduce){*{animation:none!important}}';
for(let i=0;i<ids.length;i++)for(const still of [false,true])fs.writeFileSync(path.join(out,ids[i]+(still?'-still':'')+'.svg'),`<svg xmlns="http://www.w3.org/2000/svg" viewBox="-5 -5 190 190" fill="none" stroke-width="3"><style>${still?'*{animation:none!important}':motion}</style>${designs[i][3]}</svg>`);
