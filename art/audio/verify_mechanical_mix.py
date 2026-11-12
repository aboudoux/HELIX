"""Contrôle du mix natif : présence, marge et panoramique gauche/droite."""
from pathlib import Path
import json
import wave
import numpy as np

ART = Path(__file__).resolve().parent
with wave.open(str(ART/'preview_mechanical.wav'),'rb') as source:
    rate, channels, width = source.getframerate(), source.getnchannels(), source.getsampwidth()
    assert channels == 2 and width == 2 and rate == 48000
    samples = np.frombuffer(source.readframes(source.getnframes()),'<i2').reshape(-1,2)/32768
events = json.loads((ART/'preview_mechanical.json').read_text())['events']
times = {event['name']:event['seconds'] for event in events}


def db(value):
    return 20*np.log10(max(float(value),1e-9))


def segment(start,end):
    return samples[int(start*rate):int(end*rate)]


def rms(block):
    return np.sqrt(np.mean(block*block,axis=0))


right = rms(segment(times['drone_right']+.25,times['drone_left']-.1))
left = rms(segment(times['drone_left']+.25,times['drone_front_loop']-.1))
peak = float(np.abs(samples).max())
assert peak < .9, 'Le mix dépasse la marge attendue sous -1 dBFS'
assert right[1] > right[0]*1.3, 'Le drone à droite doit être plus présent à droite'
assert left[0] > left[1]*1.3, 'Le drone à gauche doit être plus présent à gauche'
levels = {}
for name,duration in [('drone_front',.7),('relay_activation',.5),('door_near',1.4),('repair_pickup',.45),('boss_rotor',1.4)]:
    level = db(np.sqrt(np.mean(segment(times[name]+.05,times[name]+duration)**2)))
    levels[name] = round(level,2)
    assert level > -52, f'{name} est absent ou trop faible dans le mix enregistré'
silence = db(np.sqrt(np.mean(segment(times['silence']+.15,times['relay_activation']-.2)**2)))
assert silence < -70, 'Les hélices doivent disparaître après leur arrêt'
result = {'seconds':len(samples)/rate,'peak_dbfs':round(db(peak),2),
          'right_channel_advantage_db':round(db(right[1]/right[0]),2),
          'left_channel_advantage_db':round(db(left[0]/left[1]),2),
          'silence_dbfs':round(silence,2),'segment_rms_dbfs':levels}
(ART/'mechanical_mix_check.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
