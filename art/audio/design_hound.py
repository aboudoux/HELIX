"""Pas mécaniques, avertissement de charge et impulsion laser du LIMIER K-9."""
from pathlib import Path
import json
import numpy as np
from design_mechanical import RATE, noise, knock, save, manifest


def step():
    t=np.arange(int(RATE*.18))/RATE
    return knock(t,.004,.45)+noise(len(t),621,450,4200)*np.exp(-t*50)*.10


def charge():
    t=np.arange(int(RATE*.65))/RATE
    env=np.sin(np.pi*np.minimum(t/.65,1))**.7
    return env*(np.sin(2*np.pi*(320*t+700*t*t))*.25+np.sin(2*np.pi*1100*t)*.055)


def laser():
    t=np.arange(int(RATE*.4))/RATE
    phase=2*np.pi*(1000*t-700*t*t)
    env=(1-np.exp(-t*1800))*np.exp(-t*17)
    return env*(np.sin(phase)+.3*np.sin(phase*2))*.45+knock(t,.005,.18)+noise(len(t),622,600,8000)*env*.10


if __name__=='__main__':
    save('hound_step',step(),peak=.5)
    save('hound_charge',charge(),peak=.55)
    save('hound_laser',laser(),peak=.7)
    (Path(__file__).parent/'hound_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print(json.dumps(manifest,indent=2))
