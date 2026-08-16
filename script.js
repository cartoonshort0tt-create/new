const choices=['rock','paper','scissors'];
const emoji={rock:'✊',paper:'🖐️',scissors:'✌️'};
const label={rock:'🪨 ROCK',paper:'📄 PAPER',scissors:'✂️ SCISSORS'};
let playerScore=3,cpuScore=2,games=5,wins=3,losses=2,draws=0,sound=true,music=false;
let audioCtx=null, musicTimer=null, musicStep=0, roundBusy=false, roundTimer=null;

function audio(){
  if(!audioCtx) audioCtx=new (window.AudioContext||window.webkitAudioContext)();
  if(audioCtx.state==='suspended') audioCtx.resume();
}
function tone(freq,duration=.1,type='sine',gain=.04,delay=0,slideTo=null){
  if(!sound)return;
  audio();
  const now=audioCtx.currentTime+delay;
  const o=audioCtx.createOscillator(), g=audioCtx.createGain();
  o.type=type; o.frequency.setValueAtTime(freq,now);
  if(slideTo) o.frequency.exponentialRampToValueAtTime(slideTo,now+duration);
  g.gain.setValueAtTime(.0001,now);
  g.gain.exponentialRampToValueAtTime(gain,now+.012);
  g.gain.exponentialRampToValueAtTime(.0001,now+duration);
  o.connect(g).connect(audioCtx.destination); o.start(now); o.stop(now+duration+.02);
}
function noise(duration=.12,gain=.025,delay=0){
  if(!sound)return; audio();
  const now=audioCtx.currentTime+delay;
  const buffer=audioCtx.createBuffer(1,audioCtx.sampleRate*duration,audioCtx.sampleRate);
  const data=buffer.getChannelData(0);
  for(let i=0;i<data.length;i++) data[i]=(Math.random()*2-1)*(1-i/data.length);
  const src=audioCtx.createBufferSource(), filter=audioCtx.createBiquadFilter(), g=audioCtx.createGain();
  filter.type='highpass'; filter.frequency.value=900;
  g.gain.setValueAtTime(gain,now); g.gain.exponentialRampToValueAtTime(.0001,now+duration);
  src.buffer=buffer; src.connect(filter).connect(g).connect(audioCtx.destination); src.start(now);
}
function clickSound(){tone(520,.055,'square',.025);tone(780,.08,'sine',.018,.045)}
function chooseSound(){tone(220,.07,'triangle',.035);tone(330,.08,'triangle',.04,.07);tone(520,.12,'sine',.035,.14);noise(.07,.018,.18)}
function winSound(){[523,659,784,1047,1319].forEach((f,i)=>tone(f,.19,'triangle',.055,i*.075));tone(1568,.3,'sine',.035,.38);noise(.22,.03,.25)}
function loseSound(){tone(330,.2,'sawtooth',.04);tone(277,.2,'sawtooth',.035,.12);tone(196,.3,'sawtooth',.03,.25)}
function drawSound(){tone(440,.12,'triangle',.04);tone(440,.12,'triangle',.04,.16);tone(494,.18,'triangle',.035,.32)}
function resetSound(){[330,440,554,659].forEach((f,i)=>tone(f,.12,'square',.03,i*.055));}
function toggleSound(){tone(700,.07,'sine',.03);tone(950,.09,'sine',.025,.06)}
function musicTick(){
  if(!music || !sound)return;
  const notes=[261.63,329.63,392,523.25,392,329.63,293.66,349.23];
  const f=notes[musicStep++%notes.length];
  tone(f,.22,'sine',.008);
  tone(f*2,.16,'triangle',.004,.05);
}
function startMusic(){
  if(musicTimer)clearInterval(musicTimer);
  if(music){musicTick();musicTimer=setInterval(musicTick,420)}
}
function stopMusic(){if(musicTimer){clearInterval(musicTimer);musicTimer=null}}

const playerScoreEl=document.getElementById('playerScore'),cpuScoreEl=document.getElementById('cpuScore'),gamesEl=document.getElementById('games'),winsEl=document.getElementById('wins'),lossesEl=document.getElementById('losses'),drawsEl=document.getElementById('draws');
function update(){playerScoreEl.textContent=playerScore;cpuScoreEl.textContent=cpuScore;gamesEl.textContent=games;winsEl.textContent=wins;lossesEl.textContent=losses;drawsEl.textContent=draws}
function outcome(p,c){if(p===c)return'draw';if((p==='rock'&&c==='scissors')||(p==='paper'&&c==='rock')||(p==='scissors'&&c==='paper'))return'win';return'loss'}
function showToast(text){const t=document.getElementById('toast');t.textContent=text;t.classList.add('show');clearTimeout(showToast.timer);showToast.timer=setTimeout(()=>t.classList.remove('show'),1400)}
function shuffleTickSound(){
  if(!sound)return;
  tone(180,.045,'square',.018);
  tone(360,.055,'triangle',.012,.025);
}

function play(p){
  if(roundBusy)return;
  roundBusy=true;
  audio(); chooseSound();

  const c=choices[Math.floor(Math.random()*3)];
  const playerHand=document.getElementById('playerHand');
  const cpuHand=document.getElementById('cpuHand');
  const playerLabel=document.getElementById('playerLabel');
  const cpuLabel=document.getElementById('cpuLabel');
  const result=document.getElementById('result');
  const battle=document.querySelector('.battle');
  const buttons=document.querySelectorAll('.choice-btn');

  buttons.forEach(b=>b.classList.remove('selected'));
  const active=document.querySelector(`[data-choice="${p}"]`);
  if(active)active.classList.add('selected');

  // Suspense phase: rapidly cycle both hands before revealing the real choices.
  result.textContent='GET READY...';
  result.className='shuffleResult';
  battle.classList.remove('shake','flash');
  battle.classList.add('shuffling');
  playerLabel.textContent='???';
  cpuLabel.textContent='???';

  let ticks=0;
  const totalTicks=12;
  roundTimer=setInterval(()=>{
    const playerFake=choices[Math.floor(Math.random()*3)];
    const cpuFake=choices[Math.floor(Math.random()*3)];
    playerHand.textContent=emoji[playerFake];
    cpuHand.textContent=emoji[cpuFake];
    playerLabel.textContent=label[playerFake];
    cpuLabel.textContent=label[cpuFake];
    shuffleTickSound();
    ticks++;
    if(ticks>=totalTicks){
      clearInterval(roundTimer);
      roundTimer=null;
      revealRound(p,c);
    }
  },90);
}

function revealRound(p,c){
  const r=outcome(p,c);
  games++;
  if(r==='win'){playerScore++;wins++;winSound()}
  else if(r==='loss'){cpuScore++;losses++;loseSound()}
  else{draws++;drawSound()}

  document.getElementById('playerHand').textContent=emoji[p];
  document.getElementById('cpuHand').textContent=emoji[c];
  document.getElementById('playerLabel').textContent=label[p];
  document.getElementById('cpuLabel').textContent=label[c];

  const result=document.getElementById('result');
  result.textContent=r==='win'?'YOU WIN!':r==='loss'?'YOU LOSE!':'DRAW!';
  result.className='';
  void result.offsetWidth;
  result.classList.add(r==='win'?'winPulse':'flash');

  const battle=document.querySelector('.battle');
  battle.classList.remove('shuffling','shake','flash');
  void battle.offsetWidth;
  battle.classList.add(r==='loss'?'shake':'flash');

  update();
  showToast(r==='win'?'🔥 Great move!':r==='loss'?'💥 Computer wins!':'🤝 It’s a draw!');
  setTimeout(()=>{roundBusy=false},350);
}
function reset(){if(roundTimer){clearInterval(roundTimer);roundTimer=null}roundBusy=false;audio();resetSound();playerScore=0;cpuScore=0;games=0;wins=0;losses=0;draws=0;document.getElementById('result').textContent='MAKE YOUR MOVE!';document.getElementById('result').className='';document.getElementById('playerHand').textContent='✊';document.getElementById('cpuHand').textContent='✌️';document.getElementById('playerLabel').textContent='🪨 ROCK';document.getElementById('cpuLabel').textContent='✂️ SCISSORS';document.querySelectorAll('.choice-btn').forEach(b=>b.classList.remove('selected'));update();showToast('Score reset!')}

document.querySelectorAll('.choice-btn').forEach(b=>b.addEventListener('click',()=>play(b.dataset.choice)));
document.getElementById('playAgain').addEventListener('click',()=>{clickSound();play(choices[Math.floor(Math.random()*3)])});
document.getElementById('quickPlay').addEventListener('click',()=>{clickSound();play(choices[Math.floor(Math.random()*3)])});
document.getElementById('reset').addEventListener('click',reset);
document.getElementById('soundBtn').addEventListener('click',()=>{sound=!sound;document.getElementById('soundBtn').textContent=sound?'🔊':'🔇';if(sound){audio();toggleSound();if(music)startMusic()}else stopMusic();showToast(sound?'Sound enabled':'Sound muted')});
document.getElementById('musicBtn').addEventListener('click',()=>{audio();music=!music;document.getElementById('musicBtn').textContent=music?'🎶':'🎵';if(music){startMusic();showToast('Arcade music enabled')}else{stopMusic();showToast('Music muted')}});
document.getElementById('settings').addEventListener('click',()=>{audio();clickSound();showToast('Neon Arena settings coming soon')});
update();
