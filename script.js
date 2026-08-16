const choices=['rock','paper','scissors'];
const emoji={rock:'✊',paper:'🖐️',scissors:'✌️'};
const label={rock:'🪨 ROCK',paper:'📄 PAPER',scissors:'✂️ SCISSORS'};
let playerScore=3,cpuScore=2,games=5,wins=3,losses=2,draws=0,sound=true,music=true;
let audioCtx;
function audio(){audioCtx ||= new (window.AudioContext||window.webkitAudioContext)(); if(audioCtx.state==='suspended')audioCtx.resume();}
function tone(freq,duration=.1,type='sine',gain=.04,delay=0){if(!sound)return;audio();const o=audioCtx.createOscillator(),g=audioCtx.createGain();o.type=type;o.frequency.value=freq;g.gain.setValueAtTime(0,audioCtx.currentTime+delay);g.gain.exponentialRampToValueAtTime(.0001,audioCtx.currentTime+delay+duration);o.connect(g).connect(audioCtx.destination);o.start(audioCtx.currentTime+delay);o.stop(audioCtx.currentTime+delay+duration)}
function clickSound(){tone(480,.07,'square',.025);tone(720,.08,'sine',.018,.05)}
function winSound(){[523,659,784,1047].forEach((f,i)=>tone(f,.16,'triangle',.055,i*.09))}
function loseSound(){[330,277,220].forEach((f,i)=>tone(f,.18,'sawtooth',.035,i*.1))}
function drawSound(){tone(440,.13,'triangle',.04);tone(440,.13,'triangle',.04,.16)}
function update(){playerScoreEl.textContent=playerScore;cpuScoreEl.textContent=cpuScore;gamesEl.textContent=games;winsEl.textContent=wins;lossesEl.textContent=losses;drawsEl.textContent=draws}
const playerScoreEl=document.getElementById('playerScore'),cpuScoreEl=document.getElementById('cpuScore'),gamesEl=document.getElementById('games'),winsEl=document.getElementById('wins'),lossesEl=document.getElementById('losses'),drawsEl=document.getElementById('draws');
function outcome(p,c){if(p===c)return'draw';if((p==='rock'&&c==='scissors')||(p==='paper'&&c==='rock')||(p==='scissors'&&c==='paper'))return'win';return'loss'}
function showToast(text){const t=document.getElementById('toast');t.textContent=text;t.classList.add('show');clearTimeout(showToast.timer);showToast.timer=setTimeout(()=>t.classList.remove('show'),1400)}
function play(p){audio();clickSound();const c=choices[Math.floor(Math.random()*3)],r=outcome(p,c);games++;if(r==='win'){playerScore++;wins++;winSound()}else if(r==='loss'){cpuScore++;losses++;loseSound()}else{draws++;drawSound()}
 document.getElementById('playerHand').textContent=emoji[p];document.getElementById('cpuHand').textContent=emoji[c];document.getElementById('playerLabel').textContent=label[p];document.getElementById('cpuLabel').textContent=label[c];
 const result=document.getElementById('result');result.textContent=r==='win'?'YOU WIN!':r==='loss'?'YOU LOSE!':'DRAW!';result.className='';void result.offsetWidth;result.classList.add(r==='win'?'winPulse':'flash');
 document.querySelector('.battle').classList.remove('shake','flash');void document.querySelector('.battle').offsetWidth;document.querySelector('.battle').classList.add(r==='loss'?'shake':'flash');update();showToast(r==='win'?'🔥 Great move!':r==='loss'?'💥 Computer wins!':'🤝 It’s a draw!')}
function reset(){audio();clickSound();playerScore=0;cpuScore=0;games=0;wins=0;losses=0;draws=0;document.getElementById('result').textContent='MAKE YOUR MOVE!';document.getElementById('playerHand').textContent='✊';document.getElementById('cpuHand').textContent='✌️';document.getElementById('playerLabel').textContent='🪨 ROCK';document.getElementById('cpuLabel').textContent='✂️ SCISSORS';update();showToast('Score reset!')}
document.querySelectorAll('.choice-btn').forEach(b=>b.addEventListener('click',()=>play(b.dataset.choice)));
document.getElementById('playAgain').addEventListener('click',()=>play(choices[Math.floor(Math.random()*3)]));
document.getElementById('quickPlay').addEventListener('click',()=>play(choices[Math.floor(Math.random()*3)]));
document.getElementById('reset').addEventListener('click',reset);
document.getElementById('soundBtn').addEventListener('click',()=>{sound=!sound;document.getElementById('soundBtn').textContent=sound?'🔊':'🔇';if(sound){audio();clickSound()} });
document.getElementById('musicBtn').addEventListener('click',()=>{music=!music;document.getElementById('musicBtn').textContent=music?'🎵':'🎵';showToast(music?'Music enabled':'Music muted')});
document.getElementById('settings').addEventListener('click',()=>showToast('Neon Arena settings coming soon'));
update();
