// Original tank report: pressure crack, low-frequency blast, recoil mechanism.
// Run with: node art/audio/design_tank_cannon.mjs
import { writeFileSync } from 'node:fs';
const rate=48000, seconds=2.25, count=Math.floor(rate*seconds);
const samples=new Float32Array(count);
let seed=84671, low=0, mid=0, peak=0;
for(let i=0;i<count;i++) {
  const t=i/rate;
  seed=(Math.imul(seed,1664525)+1013904223)>>>0;
  const noise=seed/2147483648-1;
  low+=.018*(noise-low); mid+=.2*(noise-mid);
  const attack=1-Math.exp(-t/.001);
  const blast=(low*11+Math.sin(2*Math.PI*(48*t+4*(1-Math.exp(-t*9))))*.65)*Math.exp(-t*3.7);
  const crack=(noise-mid)*1.8*Math.exp(-t*52)+mid*3.2*Math.exp(-t*12);
  const mechanical=t>.18?Math.sin(2*Math.PI*170*(t-.18))*.1*Math.exp(-(t-.18)*17):0;
  const tail=low*2.5*Math.exp(-t*2.9);
  samples[i]=Math.tanh((blast+crack+tail)*attack+mechanical)*Math.min(1,(seconds-t)/.15);
  peak=Math.max(peak,Math.abs(samples[i]));
}
const wav=Buffer.alloc(44+count*2);
wav.write('RIFF');wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);
wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);
wav.writeUInt32LE(rate,24);wav.writeUInt32LE(rate*2,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);
wav.write('data',36);wav.writeUInt32LE(count*2,40);
samples.forEach((v,i)=>wav.writeInt16LE(Math.round(v/peak*.87*32767),44+i*2));
writeFileSync(new URL('../../DroneArena/audio/tank_cannon.wav',import.meta.url),wav);
console.log(`tank_cannon.wav: ${seconds}s, 48 kHz, peak -1.2 dBFS`);
