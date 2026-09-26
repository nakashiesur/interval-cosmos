(() => {
  'use strict';
  const avatars = 'nova orbit pulse prism comet nebula vector echo quasar lumen wave aster luna flora lyra ribbon aria gem charm bloom sonata parfait letter auris teacher'.split(' ');
  const courses = 'piano orchestral vocal_musical composition rock_pops electronic_organ sound_design music_education music_therapy child_culture voice_actor'.split(' ');
  const labels = ['新星','軌道レコード','稲妻','プリズム','流星','星雲','紙飛行機','カセット','ブラックホール','宇宙ドリンク','波形','音叉','三日月','星の花','小さなハープ','軌道リボン','翼の音符','星の宝石','月のチャーム','すずらん','星のオルゴール','星のパフェ','星の手紙','流星の鍵','教員'];
  const avatarLabel = id => labels[avatars.indexOf(id)] || labels[0];
  const avatarHTML = id => `<img class="v205-avatar-image" src="assets/art/v1/avatars/${avatars.includes(id) ? id : 'nova'}.svg" width="100" height="100" alt="" draggable="false">`;
  const courseHTML = id => courses.includes(id) ? `<img class="v205-course-image" src="assets/art/v1/courses/${id}.svg" width="32" height="32" alt="" draggable="false">` : '';
  window.IntervalCosmosArt = Object.freeze({avatarHTML, avatarLabel, courseHTML, avatars: Object.freeze(avatars), courses: Object.freeze(courses)});
})();
