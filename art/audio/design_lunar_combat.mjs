// Original mono combat cues for the lunar campaign. Regenerate with Node.js.
import { writeFileSync } from 'node:fs';

const sampleRate = 48000;

function design(name, duration, seed, peak, draw) {
  const size = Math.round(sampleRate * duration);
  function band(low, high) {
    const signal = new Float32Array(size);
    const upperRate = 1 - Math.exp(-2 * Math.PI * high / sampleRate);
    const lowerRate = 1 - Math.exp(-2 * Math.PI * low / sampleRate);
    let upper = 0;
    let lower = 0;
    let energy = 0;
    for (let i = 0; i < size; i++) {
      seed = (Math.imul(1664525, seed) + 1013904223) >>> 0;
      upper += upperRate * (seed / 2147483648 - 1 - upper);
      lower += lowerRate * (upper - lower);
      signal[i] = upper - lower;
      energy += signal[i] ** 2;
    }
    const rms = Math.sqrt(energy / size);
    return signal.map(value => value * 0.27 / rms);
  }
  const bass = band(48, 680);
  const mid = band(460, 3300);
  const treble = band(2200, 9800);
  const dry = new Float32Array(size);
  for (let i = 0; i < size; i++) {
    dry[i] = draw(i / sampleRate, bass[i], mid[i], treble[i]);
  }
  let maximum = 0;
  const samples = dry.map((value, i) => {
    const near = dry[i - 1488] ?? 0;
    const far = dry[i - 3504] ?? 0;
    const faded = Math.tanh(value + near * 0.13 + far * 0.055) * Math.min(1, (size - 1 - i) / 672);
    maximum = Math.max(maximum, Math.abs(faded));
    return faded;
  });
  const wav = Buffer.alloc(44 + size * 2);
  wav.write('RIFF', 0);
  wav.writeUInt32LE(wav.length - 8, 4);
  wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(sampleRate, 24);
  wav.writeUInt32LE(sampleRate * 2, 28);
  wav.writeUInt16LE(2, 32);
  wav.writeUInt16LE(16, 34);
  wav.write('data', 36);
  wav.writeUInt32LE(size * 2, 40);
  samples.forEach((value, i) => wav.writeInt16LE(Math.round(value * peak * 32767 / maximum), 44 + i * 2));
  writeFileSync(new URL(`../../DroneArena/audio/${name}.wav`, import.meta.url), wav);
}

function envelope(t, decay, attack = 0.00055) {
  return t < 0 ? 0 : (1 - Math.exp(-t / attack)) * Math.exp(-t / decay);
}

function sweep(t, start, end, curve, decay, attack) {
  const phase = 2 * Math.PI * (end * t + (start - end) * curve * (1 - Math.exp(-Math.max(t, 0) / curve)));
  return Math.sin(phase) * envelope(t, decay, attack);
}

design('impact_metal',0.24,901,0.76,(t,b,m,h)=>h*envelope(t,0.009)+0.4*sweep(t,2200,1900,0.02,0.08)+0.25*m*envelope(t,0.025));
design('impact_glass',0.35,902,0.65,(t,b,m,h)=>h*(envelope(t,0.014)+0.4*envelope(t-0.045,0.04))+0.22*sweep(t,5400,4300,0.03,0.08));
design('impact_dust',0.3,903,0.65,(t,b,m,h)=>(b+0.5*m)*envelope(t,0.055,0.002));
design('suit_breath',3.2,904,0.40,(t,b,m,h)=>m*(Math.pow(Math.max(0,Math.sin(Math.PI*t/1.35)),2)*0.18+Math.pow(Math.max(0,Math.sin(Math.PI*(t-1.65)/1.4)),2)*0.13));
design('suit_alarm',0.8,905,0.6,(t,b,m,h)=>sweep(t,900,870,0.03,0.09,0.01)+sweep(t-0.24,660,640,0.03,0.09,0.01));
design('airlock_pressure',3.5,1931,0.65,(t,b,m,h)=>(0.2*b+0.8*m+0.1*h)*Math.min(1,t/0.3,(3.5-t)/0.55)*(0.7+Math.sin(t*4)*0.08));

design('lunar_pistol', 0.39, 2909, 0.92, (t, bass, mid, treble) =>
  (2.3 * treble + 2.05 * mid) * envelope(t, 0.012) +
  2.25 * bass * envelope(t, 0.047) + 0.62 * sweep(t, 180, 73, 0.010, 0.058) +
  (0.48 * treble + 0.20 * mid) * envelope(t - 0.042, 0.009) +
  0.22 * mid * envelope(t, 0.095));

design('lunar_drone_pulse', 0.33, 7612, 0.86, (t, bass, mid, treble) =>
  1.05 * (treble + mid) * envelope(t, 0.017) + 0.56 * bass * envelope(t, 0.06) +
  0.59 * sweep(t, 1710, 247, 0.034, 0.081, 0.0013) +
  0.25 * sweep(t - 0.012, 2510, 810, 0.016, 0.055));

design('lunar_armor_hit', 0.26, 409, 0.83, (t, bass, mid, treble) =>
  (1.60 * treble + 0.83 * mid) * envelope(t, 0.012) +
  0.39 * sweep(t, 330, 160, 0.012, 0.030) +
  0.34 * sweep(t, 1270, 1160, 0.010, 0.048) + 0.27 * sweep(t, 2635, 2350, 0.009, 0.034) +
  treble * (0.50 * envelope(t - 0.026, 0.009) + 0.28 * envelope(t - 0.051, 0.013)));

design('lunar_hound_pulse', 0.37, 1921, 0.89, (t, bass, mid, treble) =>
  (1.30 * mid + 1.05 * treble) * envelope(t, 0.013) + 1.05 * bass * envelope(t, 0.060) +
  0.71 * sweep(t, 710, 92, 0.037, 0.105) + 0.32 * sweep(t, 1540, 333, 0.020, 0.070) +
  mid * 0.30 * Math.cos(2 * Math.PI * 39 * t) * envelope(t, 0.095));

design('lunar_servo_step', 0.22, 5044, 0.79, (t, bass, mid, treble) =>
  1.34 * bass * envelope(t, 0.019) + 0.63 * sweep(t, 240, 103, 0.013, 0.037) +
  (0.86 * mid + 0.49 * treble) * envelope(t, 0.008) +
  (0.37 * mid + 0.44 * treble) * envelope(t - 0.034, 0.015) +
  0.27 * sweep(t - 0.035, 1080, 440, 0.019, 0.032));

design('lunar_spider_click', 0.17, 5255, 0.75, (t, bass, mid, treble) =>
  (1.38 * treble + 0.88 * mid) * (envelope(t, 0.007) + 0.64 * envelope(t - 0.032, 0.008)) +
  0.44 * sweep(t, 2340, 890, 0.012, 0.021));

design('lunar_spider_pulse', 0.28, 1519, 0.84, (t, bass, mid, treble) =>
  (1.24 * treble + 0.97 * mid) * envelope(t, 0.016) +
  0.52 * sweep(t, 2860, 440, 0.024, 0.065) +
  0.31 * sweep(t - 0.020, 1120, 2980, 0.041, 0.047) + 0.31 * bass * envelope(t, 0.042));

// Distinct firearm signatures: a broad low shotgun report with a delayed pump,
// and a short dry automatic burst that does not mask the next round.
design('lunar_shotgun', 0.58, 7181, 0.88, (t, bass, mid, treble) =>
  (1.45 * treble + 2.25 * mid) * envelope(t, 0.017) +
  2.9 * bass * envelope(t, 0.065) + 1.1 * sweep(t, 170, 49, 0.035, 0.10) +
  (mid * 0.65 + treble * 0.3) * envelope(t - 0.15, 0.035) +
  (mid * 0.7 + treble * 0.35) * envelope(t - 0.34, 0.014));

design('lunar_rifle', 0.19, 4832, 0.79, (t, bass, mid, treble) =>
  (1.6 * treble + 1.75 * mid) * envelope(t, 0.007) +
  1.05 * bass * envelope(t, 0.024) + 0.44 * sweep(t, 420, 130, 0.012, 0.027) +
  (treble * 0.32 + mid * 0.18) * envelope(t - 0.038, 0.008));
