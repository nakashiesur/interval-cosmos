// Editable vector masters based on the approved flat art direction.
const fs=require('fs'),path=require('path');
const root=path.join(__dirname,'..');
const C='#65e7f3',W='#eef6ff',V='#b7a0f4',P='#e49eae',M='#99edcd';
const p=(d,c=W)=>`<path d="${d}" fill="${c}"/>`;
const line=(d,c=C,w=5)=>`<path d="${d}" fill="none" stroke="${c}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
const circle=(x,y,r,c=W)=>`<circle cx="${x}" cy="${y}" r="${r}" fill="${c}"/>`;
const star=(x,y,r=12,c=C)=>p(`M${x} ${y-r}L${x+3} ${y-3}L${x+r} ${y}L${x+3} ${y+3}L${x} ${y+r}L${x-3} ${y+3}L${x-r} ${y}L${x-3} ${y-3}Z`,c);
const note=p('M42 24V69C27 63 18 72 23 80C28 90 48 84 49 74V38L66 49V38Z');
const phones=line('M23 62V48A27 27 0 0 1 54 23A27 27 0 0 1 77 48V62',V,7)+p('M19 49Q12 49 12 59V70Q12 81 23 81H29V49Z',C)+p('M71 49V81H77Q88 81 88 70V59Q88 49 81 49Z',V);
const avatars={
nova:p('M51 7L57 42L91 50L57 57L49 92L42 57L8 50L42 42Z',W)+p('M51 7L49 47L8 50L42 42Z',C)+p('M91 50L52 52L49 92L57 57Z',C),
orbit:circle(50,50,29)+circle(50,50,12,'#091624')+circle(50,50,3)+line('M26 30Q49 14 69 31M25 36Q42 21 63 31',V,2)+line('M20 51C-1 76 66 73 88 41C98 25 83 25 76 29',C,6),
pulse:p('M64 8L17 57H44L34 93L83 40H55Z')+p('M77 57L58 78H69L65 91L87 68H75Z',V),
prism:line('M48 15L12 83H85Z',W,4)+p('M48 22V75L80 80Z',C)+line('M48 75L18 80',W,3)+p('M59 32L92 18V33Z',C)+p('M67 45L94 43V52Z',V)+p('M72 59L94 68V79Z',V),
comet:p('M13 66L32 56L44 70L23 87Z')+p('M34 46L93 12L51 57Z',C)+p('M45 66L88 29L62 72Z',V)+p('M30 86L89 50L57 88Z',C),
nebula:[0,72,144,216,288].map((a,i)=>`<g transform="rotate(${a} 50 50)">${p('M50 11C18 12 9 53 37 67C25 45 41 31 64 34C63 24 57 17 50 11Z',[C,V,W][i%3])}</g>`).join(''),
vector:p('M9 45L92 14L59 90L44 58Z')+p('M44 58L92 14L51 66L47 88Z',C)+p('M59 69L92 14L66 80Z','#d8f88a'),
echo:p('M12 22H88V78H12Z')+p('M18 29H82V62H18Z',V)+circle(33,45,10)+circle(67,45,10)+circle(33,45,6,'#091624')+circle(67,45,6,'#091624')+p('M43 38H57V52H43Z','#091624')+line('M30 77L36 65H64L70 77','#091624',3),
quasar:circle(50,50,23,'#091624')+line('M27 46C-1 68 18 82 63 57S104 17 72 34',W,5)+line('M24 50C1 77 46 69 74 45',V,2)+p('M47 8H54L52 28H49Z',C)+p('M49 72H52L54 92H47Z',C),
lumen:p('M28 36H74L68 87H35Z')+p('M24 28H78V39H24Z',C)+p('M29 20H73L78 27H24Z',C)+line('M58 21L64 7',C,5)+circle(51,60,12,'#091624')+line('M37 65L67 54',C,4),
wave:line('M10 57C23 15 28 89 42 47S61 10 65 51S82 76 91 47',C,9)+line('M42 47C54 10 61 10 65 51',W,9)+line('M65 51C73 87 82 76 91 47','#f3999d',9),
aster:line('M31 17V54Q31 73 49 73Q67 73 67 54V17',W,7)+line('M49 73V87',W,5)+circle(49,90,5)+star(83,21,10),
luna:p('M64 13A37 37 0 1 0 85 70A33 33 0 0 1 64 13Z')+star(70,38,16,V),
flora:[0,72,144,216,288].map(a=>`<g transform="rotate(${a} 50 50)">${p('M50 10Q27 30 46 49Q66 34 50 10Z',P)}</g>`).join('')+star(50,50,19,C),
lyra:line('M23 20Q8 18 21 43L26 68Q50 89 74 68L79 43Q92 18 77 20',W,7)+[40,50,60].map(x=>line(`M${x} 25V74`,V,3)+circle(x,24,4,V)).join('')+p('M30 80H70L75 88H25Z'),
ribbon:line('M50 49C-10 1 12 86 50 49S103 9 82 26S34 57 20 76',M,8)+line('M50 49C66 69 72 81 89 74',W,7)+star(81,53,8),
aria:note+p('M48 35Q82 28 85 10Q91 40 58 45Z',C)+p('M56 49Q77 44 80 35Q80 56 59 60Z',C),
gem:p('M50 12L20 53L50 90L78 51Z',V)+p('M50 12L40 51L20 53Z')+p('M40 51L50 90L50 57Z')+p('M50 12V57L78 51Z',C)+star(82,23,10),
charm:line('M50 8V16','#ead7b1',3)+`<circle cx="50" cy="28" r="16" fill="none" stroke="#ead7b1" stroke-width="3"/>`+line('M50 44V56','#ead7b1',3)+p('M58 57A16 16 0 1 0 65 78A14 14 0 0 1 58 57Z','#ead7b1')+star(53,91,7),
bloom:line('M45 88C35 56 40 8 61 20Q72 23 74 34',M,4)+line('M42 48Q60 27 71 51',M,4)+p('M40 84Q15 77 17 47Q38 54 40 84Z',M)+p('M65 28Q82 21 84 39L91 43Q83 51 76 44Q67 52 62 43Z')+p('M62 49Q78 43 80 61L87 66Q78 73 72 65Q63 73 58 64Z'),
sonata:p('M17 47H74V84H17Z')+line('M20 42L31 15H78L68 42Z',W,5)+star(49,30,10,C)+line('M76 62H86',V,4)+circle(88,55,5,V)+circle(88,70,5,V)+circle(27,89,3)+circle(65,89,3),
parfait:p('M23 44H77L58 72V83L73 89H27L42 83V72Z')+p('M32 43A20 20 0 0 1 72 43Z',V)+line('M67 35L78 17',W,4)+star(49,16,9,C)+p('M32 49H69L54 65H46Z','#091624'),
letter:p('M12 37H88V83H12Z')+line('M13 39L50 64L87 39','#091624',3)+line('M13 82L37 59M87 82L63 59','#091624',3)+star(50,56,11,P)+star(50,19,11,P),
auris:p('M65 13L71 24L85 20L79 34L88 47L72 45L65 58L61 43L46 42L57 31L55 16Z',V)+p('M64 27L70 31L68 38L62 38L60 32Z','#091624')+line('M60 45L22 85',V,7)+p('M30 71L39 80L46 73L38 66Z')+p('M40 60L49 69L55 62L48 55Z')+line('M48 88Q61 65 85 58',C,3),
teacher:line('M25 79L77 19',W,5)+line('M18 40Q21 19 41 13M69 61Q79 60 84 45',V,4)
};
for(const [id,body] of Object.entries(avatars)){fs.writeFileSync(path.join(root,'assets/art/v1/avatars',id+'.svg'),`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">${body}</svg>\n`)}
console.log('Wrote '+Object.keys(avatars).length+' avatar vectors');
const keys=(y=20)=>p(`M14 ${y}H86V${y+28}H14Z`)+[28,44,67].map(x=>p(`M${x} ${y}H${x+6}V${y+17}H${x}Z`,'#091624')).join('');
const courses={
piano:p('M14 22H86V80H14Z')+[28,44,67].map(x=>p(`M${x} 22H${x+7}V58H${x}Z`,'#091624')).join('')+line('M38 59V80M60 59V80','#091624',2),
orchestral:p('M43 28C22 24 20 46 34 49C13 61 23 86 43 80C65 86 75 61 54 49C68 46 66 24 47 28Z',V)+line('M45 15V68',W,4)+line('M37 17H53M38 24H52',V,3)+line('M72 17L61 85',W,4),
vocal_musical:p('M29 19Q16 19 16 33V51Q16 66 29 66Q42 66 42 51V33Q42 19 29 19Z')+line('M9 49V56Q9 76 29 76Q49 76 49 56V49',W,4)+line('M29 76V88M18 89H40',W,4)+`<g transform="translate(42 -7) scale(.65)">${note}</g>`,
composition:p('M23 67L64 16L77 27L36 79L17 86Z')+line('M30 61L44 72',C,5)+line('M14 89H55',W,3)+`<g transform="translate(55 38) scale(.5)">${note}</g>`,
rock_pops:p('M22 55Q10 62 19 78Q29 95 44 77L52 65L43 57L71 27L65 21L37 50Q25 39 22 55Z',C)+line('M27 72L73 22',W,4)+p('M64 22L74 10L84 16L77 28Z',C),
electronic_organ:keys(20)+keys(56),
sound_design:phones,
music_education:p('M10 22Q30 14 48 24Q70 14 90 22V80Q68 71 50 81Q29 71 10 80Z')+line('M50 26V74','#091624',3)+`<g transform="translate(43 17) scale(.6)">${p('M42 24V69C27 63 18 72 23 80C28 90 48 84 49 74V38L66 49V38Z','#091624')}</g>`,
music_therapy:p('M50 85C-5 47 12 8 37 24L50 35L63 24C88 8 105 47 50 85Z',C)+line('M15 53H32L40 40L50 67L61 43L68 53H84',W,4),
child_culture:star(31,48,25,V)+`<g transform="translate(45 15) scale(.7)">${note}</g>`,
voice_actor:line('M17 71C-8 36 18 13 50 16C96 14 99 71 64 78H33L13 88Z',W,5)+p('M49 29Q39 29 39 39V51Q39 63 49 63Q59 63 59 51V39Q59 29 49 29Z',C)+line('M32 49Q32 70 49 70Q66 70 66 49M49 70V77',C,4)
};
for(const [id,body] of Object.entries(courses)){fs.writeFileSync(path.join(root,'assets/art/v1/courses',id+'.svg'),`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">${body}</svg>\n`)}
console.log('Wrote '+Object.keys(courses).length+' course vectors');
