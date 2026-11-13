// Render complete French utterances with Microsoft Vivienne; package offline WAVs.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {spawnSync} from 'node:child_process';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const require=createRequire(path.join(root,'.tools/voice/package.json'));
const {MsEdgeTTS,OUTPUT_FORMAT}=require('msedge-tts');
const ffmpeg=require('ffmpeg-static');
const voice='fr-FR-VivienneMultilingualNeural';
const source=await fs.readFile(path.join(root,'DroneArena/missions/lunar_escape/briefing_voice.gd'),'utf8');
const lines=[...source.matchAll(/"([a-z_]+)":"([^"]+)"/g)];
if(lines.length!==8) throw new Error('Expected eight campaign lines; review before replacing audio.');
const stamp=new Date().toISOString().replaceAll(/[:.]/g,'-');
const staging=path.join(root,'.tools/voice/vivienne',stamp);
const out=path.join(root,'DroneArena/audio/voice');
const backup=path.join(staging,'previous');
await fs.mkdir(backup,{recursive:true});
const report=[];
const escapeXml=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
async function render(dir,spoken){
  for(let attempt=0;attempt<3;attempt++){
    const tts=new MsEdgeTTS({connectionTimeoutMs:15000,synthesisTimeoutMs:45000});
    try{
      await tts.setMetadata(voice,OUTPUT_FORMAT.AUDIO_24KHZ_96KBITRATE_MONO_MP3);
      return await tts.toFile(dir,escapeXml(spoken),{rate:'-2%',pitch:'+0Hz'});
    }catch(error){if(attempt===2)throw error;}
    finally{tts.close();}
  }
}
{
  for(const [,key,subtitle] of lines){
    const spoken=subtitle.split(' · ').at(-1).replace('avec R.','avec la touche R.');
    const dir=path.join(staging,key);await fs.mkdir(dir,{recursive:true});
    // Whole utterance: keep natural phrasing instead of joining isolated sentences.
    const {audioFilePath}=await render(dir,spoken);
    const decoded=spawnSync(ffmpeg,['-hide_banner','-loglevel','error','-i',audioFilePath,
      '-af','loudnorm=I=-18:TP=-2:LRA=9','-ar','24000','-ac','1','-f','s16le','pipe:1'],
      {maxBuffer:20*1024*1024,windowsHide:true});
    if(decoded.status!==0) throw new Error(`Audio conversion failed for ${key}: ${decoded.stderr}`);
    const pcm=decoded.stdout;
    let energy=0,peak=0;for(let i=0;i<pcm.length;i+=2){const v=pcm.readInt16LE(i)/32768;energy+=v*v;peak=Math.max(peak,Math.abs(v));}
    const seconds=pcm.length/48000,rms=Math.sqrt(energy/(pcm.length/2));
    if(seconds<2||seconds>30||rms<.015||peak>=.999) throw new Error(`Invalid voice recording: ${key}`);
    const wav=Buffer.alloc(44+pcm.length);wav.write('RIFF');wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);
    wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(24000,24);
    wav.writeUInt32LE(48000,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(pcm.length,40);pcm.copy(wav,44);
    await fs.writeFile(path.join(staging,`${key}.wav`),wav);
    report.push({key,seconds,peak,rms,spoken});console.log(`${key}: ${seconds.toFixed(2)} s`);
  }
}
const names=[...report.map(c=>`${c.key}.wav`),'synthesis.json'];
for(const name of names) await fs.copyFile(path.join(out,name),path.join(backup,name));
try {
  for(const clip of report) await fs.copyFile(path.join(staging,`${clip.key}.wav`),path.join(out,`${clip.key}.wav`));
  await fs.writeFile(path.join(out,'synthesis.json'),JSON.stringify({provider:'Microsoft Read Aloud',voice,language:'fr-FR',sampleRate:24000,
    renderedAt:new Date().toISOString(),rate:'-2%',pitch:'+0Hz',normalization:'-18 LUFS / -2 dBTP',clips:report},null,2)+'\n');
} catch(error){
  for(const name of names) await fs.copyFile(path.join(backup,name),path.join(out,name));
  throw error;
}
console.log(`Replaced ${report.length} lines with ${voice}; previous files preserved in ${backup}`);
