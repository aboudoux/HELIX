// Recorded firearm edits: Vincent Sevedge, CC BY 3.0 (see sources/README.md).
import {readFileSync,writeFileSync} from 'node:fs';
for(const [input,output,duration] of [['cz','recorded_pistol',0.55],['shotty','recorded_shotgun',0.62],['sks','recorded_rifle',0.26]]){
  const buffer=readFileSync(new URL(`sources/gunshots/sounds/${input}.wav`,import.meta.url));
  let data,channels,rate,bits;
  for(let offset=12;offset+8<buffer.length;){
    const length=buffer.readUInt32LE(offset+4),kind=buffer.toString('ascii',offset,offset+4);
    if(kind==='fmt '){channels=buffer.readUInt16LE(offset+10);rate=buffer.readUInt32LE(offset+12);bits=buffer.readUInt16LE(offset+22);}
    if(kind==='data')data=buffer.subarray(offset+8,offset+8+length);
    offset+=8+length+(length%2);
  }
  if(bits!==16)throw Error('Expected PCM16');
  const samples=Array.from({length:Math.floor(data.length/(2*channels))},(_,i)=>{
    let value=0;for(let c=0;c<channels;c++)value+=data.readInt16LE((i*channels+c)*2)/32768;return value/channels;
  });
  const onset=Math.max(0,samples.findIndex(v=>Math.abs(v)>0.12)-Math.round(rate*0.001));
  const clip=samples.slice(onset,onset+Math.round(rate*duration));
  let previous=0,filtered=0;
  const signal=clip.map((v,i)=>{filtered=0.994*(filtered+v-previous);previous=v;return filtered*Math.min(1,i/18,(clip.length-1-i)/(rate*0.07));});
  const maximum=signal.reduce((m,v)=>Math.max(m,Math.abs(v)),0);
  const wav=Buffer.alloc(44+signal.length*2);
  wav.write('RIFF');wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);
  wav.writeUInt32LE(rate,24);wav.writeUInt32LE(rate*2,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(signal.length*2,40);
  signal.forEach((v,i)=>wav.writeInt16LE(Math.round(v/maximum*0.88*32767),44+i*2));
  writeFileSync(new URL(`../../DroneArena/audio/${output}.wav`,import.meta.url),wav);
  console.log(output,`${(onset/rate).toFixed(3)}s onset`,`${signal.length/rate}s`, 'peak 0.88');
}
