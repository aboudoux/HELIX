"""Sons originaux HELIX : synthèse déterministe, sans banque de sons externe.
Python + NumPy servent uniquement à la fabrication ; le jeu lit les WAV.
"""
from pathlib import Path
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "DroneArena/audio"
RATE = 48000


def filter_band(signal, low=0, high=None):
    count = 1 << int(np.ceil(np.log2(len(signal)*2)))
    frequency = np.fft.rfftfreq(count,1/RATE)
    gain = np.ones(len(frequency))
    if low:
        gain *= 1/np.sqrt(1+(low/np.maximum(frequency,.01))**8)
    if high:
        gain *= 1/np.sqrt(1+(frequency/high)**8)
    return np.fft.irfft(np.fft.rfft(signal,count)*gain,count)[:len(signal)]


def noise(rng, count, low, high):
    signal = filter_band(rng.normal(size=count),low,high)
    return signal * .32 / max(np.sqrt(np.mean(signal**2)), 1e-8)


def env(t, decay, attack=.0004):
    return (1-np.exp(-np.maximum(t, 0)/attack))*np.exp(-np.maximum(t, 0)/decay)*(t >= 0)


def sweep(t, start, end, decay):
    phase = 2*np.pi*(end*t+(start-end)*decay*(1-np.exp(-t/decay)))
    return np.sin(phase)


def reflections(signal, taps):
    result = signal.copy()
    room = filter_band(signal,high=3600)
    for delay, gain in taps:
        offset = int(delay*RATE)
        result[offset:] += gain*room[:-offset]
    return result


def finish(signal, peak):
    signal = filter_band(signal,low=38)
    signal = np.tanh(signal*1.45)
    fade_in = int(RATE*.0003)
    fade_out = int(RATE*.018)
    signal[:fade_in] *= np.linspace(0,1,fade_in)
    signal[-fade_out:] *= np.linspace(1,0,fade_out)
    signal -= np.mean(signal)
    signal *= peak/max(np.abs(signal).max(), 1e-8)
    signal[0] = signal[-1] = 0
    return signal


def rifle(seed, enemy=False):
    rng = np.random.default_rng(seed)
    t = np.arange(int(RATE*(.36 if enemy else .43)))/RATE
    shift = rng.uniform(.95,1.05)
    crack = noise(rng,len(t),1000,12500)*env(t,.008)*.95
    body = noise(rng,len(t),95,2100)*env(t,.031)*.85
    pressure = sweep(t, (210 if enemy else 165)*shift, (86 if enemy else 62)*shift,.018)*env(t,.061)*.60
    discharge = sweep(t,1350*shift,290*shift,.011)*env(t,.027)*.10
    tail = noise(rng,len(t),160,3800)*env(t,.105)*.15
    latch = (np.sin(2*np.pi*2350*t)+.4*np.sin(2*np.pi*3720*t))*env(t-.025,.013)*.075
    result = crack+body+pressure+discharge+tail+latch
    return finish(reflections(result,[(.029,.14),(.066,.08),(.115,.035)]),.84 if enemy else .88)


def armor(seed):
    rng = np.random.default_rng(seed)
    t = np.arange(int(RATE*.40))/RATE
    result = noise(rng,len(t),650,11500)*env(t,.009)*1.15
    result += noise(rng,len(t),100,1800)*env(t,.025)*.55
    result += sweep(t,190,95,.012)*env(t,.031)*.30
    # Modes non harmoniques d'une coque, puis petits éclats secondaires.
    for i,frequency in enumerate([430,775,1285,2190,3470,4930]):
        f = frequency*rng.uniform(.89,1.11)
        result += np.sin(2*np.pi*f*t+rng.uniform(0,1))*env(t,.11-i*.011)*(.12-i*.010)
    rattle = noise(rng,len(t),1100,8500)
    for delay,gain in [(.020,.25),(.037,.17),(.067,.12),(.097,.07)]:
        result += rattle*env(t-delay,.007)*gain
    return finish(reflections(result,[(.036,.12)]),.80)


def destruction(seed):
    rng = np.random.default_rng(seed)
    t = np.arange(int(RATE*.95))/RATE
    result = noise(rng,len(t),80,3200)*env(t,.115)*1.20
    result += noise(rng,len(t),1600,12500)*env(t,.009)*.95
    result += sweep(t,110,40,.055)*env(t,.17)*.78
    for delay in rng.uniform(.035,.48,13):
        result += noise(rng,len(t),1400,10000)*env(t-delay,rng.uniform(.006,.018))*.13
    for frequency in [560,1430,2860]:
        result += np.sin(2*np.pi*frequency*t)*env(t-.035,.15)*.035
    return finish(reflections(result,[(.039,.21),(.083,.12),(.14,.06)]),.85)


def confirmation():
    rng = np.random.default_rng(736)
    t = np.arange(int(RATE*.095))/RATE
    result = noise(rng,len(t),700,7500)*env(t,.008)*.70
    result += np.sin(2*np.pi*1650*t)*env(t,.013)*.07
    return finish(result,.36)


def write(path, signal):
    with wave.open(str(path),"wb") as output:
        output.setnchannels(1 if signal.ndim == 1 else signal.shape[1])
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(np.rint(np.clip(signal,-1,1)*32767).astype("<i2").tobytes())


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    sounds={"shot.wav":rifle(101),"shot_02.wav":rifle(102),"shot_03.wav":rifle(103),
            "enemy_shot.wav":rifle(201,True),"enemy_shot_02.wav":rifle(202,True),
            "drone_impact_01.wav":armor(301),"drone_impact_02.wav":armor(302),"drone_impact_03.wav":armor(303),
            "drone_destroyed.wav":destruction(401),"hit.wav":confirmation()}
    manifest={"author":"HELIX / sons originaux synthétisés pour ce projet","sample_rate":RATE,"format":"PCM 16 bits mono","sounds":[]}
    for name,signal in sounds.items():
        write(OUT/name,signal)
        info={"file":name,"seconds":round(len(signal)/RATE,3),
              "peak_dbfs":round(float(20*np.log10(np.max(np.abs(signal)))),2),
              "rms_dbfs":round(float(20*np.log10(np.sqrt(np.mean(signal**2)))),2)}
        manifest["sounds"].append(info)
        print(info)
    (Path(__file__).parent/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")


if __name__ == "__main__":
    main()
