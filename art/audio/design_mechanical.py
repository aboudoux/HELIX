"""Sons originaux HELIX : hélices, porte motorisée et interactions.
Python + NumPy uniquement. WAV mono PCM16 / 48 kHz, graines fixes.
"""
from pathlib import Path
import json
import math
import re
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'DroneArena/audio'
RATE = 48000
manifest = {}


def noise(n, seed, low, high):
    rng = np.random.default_rng(seed)
    freq = np.fft.rfftfreq(n, 1/RATE)
    spectrum = np.fft.rfft(rng.normal(size=n))
    # Le filtrage fréquentiel est aussi périodique : pas de couture de bruit.
    mask = (1-np.exp(-(freq/max(low,1))**4))*np.exp(-(freq/high)**6)
    result = np.fft.irfft(spectrum*mask, n=n)
    return result / max(float(np.std(result)), 1e-9)


def save(name, samples, peak=.8, loop=False):
    samples = np.asarray(samples,dtype=np.float64)
    samples -= np.mean(samples)
    if not loop:
        fade = min(int(.008*RATE),len(samples)//4)
        samples[:fade] *= np.linspace(0,1,fade)
        samples[-fade:] *= np.linspace(1,0,fade)
    samples *= peak/max(float(np.max(np.abs(samples))),1e-9)
    pcm = np.round(samples*32767).astype('<i2')
    with wave.open(str(DEST/(name+'.wav')),'wb') as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(RATE)
        out.writeframes(pcm.tobytes())
    # Préserver les détails et la couture des boucles, sans compression QOA.
    settings = DEST/(name+'.wav.import')
    if settings.exists():
        source = settings.read_text(encoding='utf-8')
        settings.write_text(re.sub(r'compress/mode=\d+', 'compress/mode=0',source),encoding='utf-8',newline='\n')
    manifest[name] = {'seconds':len(samples)/RATE,'sample_rate':RATE,
                      'peak_dbfs':round(20*math.log10(max(np.max(np.abs(samples)),1e-9)),2),
                      'rms_dbfs':round(20*math.log10(max(np.sqrt(np.mean(samples*samples)),1e-9)),2),
                      'loop':loop}
    if loop:
        manifest[name]['wrap_step'] = round(float(abs(samples[-1]-samples[0])),6)
    return samples


def rotor(heavy=False):
    n = RATE*4
    t = np.arange(n)/RATE
    signal = np.zeros(n)
    frequencies = (72,78.5,83,88.25) if heavy else (126,132.5,139,146.25)
    for index,frequency in enumerate(frequencies):
        phase = .71*index
        # Passage des pales et harmoniques de charge des quatre turbines.
        modulation = .86+.09*np.sin(2*np.pi*(.5+index*.25)*t+phase)
        for harmonic in range(1,8):
            signal += modulation*np.sin(2*np.pi*frequency*harmonic*t+phase*harmonic)/(harmonic**1.6*4)
    air = noise(n,461 if heavy else 460,140 if heavy else 310,2200 if heavy else 3500)
    signal += air*(.055 if heavy else .045)*(.8+.2*np.sin(2*np.pi*24*t))
    signal += .045*np.sin(2*np.pi*(39 if heavy else 62)*t)
    signal += .019*np.sin(2*np.pi*(410 if heavy else 960)*t)
    if heavy:
        signal *= .82+.18*np.sin(2*np.pi*12*t)
    return signal


def knock(t,at,strength=1):
    age = np.maximum(t-at,0)
    gate = t>=at
    return strength*gate*(np.sin(2*np.pi*92*age)+.45*np.sin(2*np.pi*237*age))*np.exp(-age*42)


def door():
    t = np.arange(int(RATE*1.5))/RATE
    air = noise(len(t),470,65,1800)
    motor_window = np.clip((t-.075)/.11,0,1)*np.clip((1.2-t)/.12,0,1)
    phase = 2*np.pi*(91*t+11*np.sin(np.pi*np.clip(t/1.2,0,1))/np.pi)
    mechanism = (np.sin(phase)+.3*np.sin(phase*2)+.18*np.sin(phase*4))*.22
    rails = air*.085*(.72+.28*np.sin(2*np.pi*27*t)**2)
    result = motor_window*(mechanism+rails)
    result += knock(t,.016,.9)+knock(t,.09,.3)+knock(t,1.2,.75)
    result += (t>=1.2)*noise(len(t),471,300,3300)*np.exp(-np.maximum(t-1.2,0)*24)*.1
    return result


def relay():
    t = np.arange(int(RATE*.62))/RATE
    result = knock(t,.012,.15)
    for at,frequency in [(0.04,440),(.17,660),(.3,880)]:
        age = np.maximum(t-at,0)
        env = (t>=at)*(1-np.exp(-age*200))*np.exp(-age*15)
        result += env*(np.sin(2*np.pi*frequency*age)+.15*np.sin(2*np.pi*frequency*2*age))*.4
    return result


def denied():
    t = np.arange(int(RATE*.24))/RATE
    env = np.sin(np.pi*np.clip(t/.24,0,1))**2
    return env*(np.sin(2*np.pi*165*t)+.2*np.sin(2*np.pi*330*t))


def repair():
    t = np.arange(int(RATE*.48))/RATE
    env = (1-np.exp(-t*100))*np.exp(-t*9)
    return env*(np.sin(2*np.pi*(540*t+310*t*t))+.2*np.sin(2*np.pi*1080*t))


def crash(heavy=False):
    t = np.arange(int(RATE*(1.2 if heavy else .85)))/RATE
    grit = noise(len(t),482 if heavy else 481,110,6800)
    age = np.maximum(t-.008,0)
    env = (t>=.008)*(1-np.exp(-age*2200))*np.exp(-age*(27 if heavy else 40))
    result = grit*env*.65
    # Choc de coque et résonances métalliques, sans souffle d'explosion.
    for i,frequency in enumerate((66,147,319,701,1327) if heavy else (117,293,617,1283,2519)):
        result += np.sin(2*np.pi*frequency*t)*np.exp(-t*(7+i*3))*(1-np.exp(-t*1400))*(.3-i*.037)
    for at,gain in [(.065,.2),(.14,.13),(.23,.07)]:
        age = np.maximum(t-at,0)
        result += grit*(t>=at)*np.exp(-age*55)*gain
    return result


if __name__ == '__main__':
    DEST.mkdir(parents=True,exist_ok=True)
    save('drone_rotor',rotor(),loop=True)
    save('boss_rotor',rotor(True),loop=True)
    save('door_open',door(),peak=.87)
    save('relay_activate',relay(),peak=.7)
    save('interaction_denied',denied(),peak=.45)
    save('repair_pickup',repair(),peak=.6)
    save('drone_crash',crash(),peak=.8)
    save('boss_crash',crash(True),peak=.85)
    manifest['door_open']['latch_seconds'] = 1.2
    (Path(__file__).parent/'mechanical_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print(json.dumps(manifest,indent=2))
