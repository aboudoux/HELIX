from pathlib import Path
import numpy as np,wave
rng=np.random.default_rng(90)
for name,duration in [('elevator_motor',8.5),('elevator_bell',1.0)]:
 t=np.arange(int(48000*duration))/48000
 if name.endswith('motor'):
  env=np.minimum(t/.35,1)*np.minimum((duration-t)/.4,1)
  s=(np.sin(2*np.pi*54*t)+.3*np.sin(2*np.pi*109*t)+.12*np.sin(2*np.pi*(300*t+5*np.sin(t*3))))*env*.15
  s+=rng.normal(0,.012,t.size)*env
 else:s=(np.sin(2*np.pi*740*t)+.5*np.sin(2*np.pi*1110*t))*np.exp(-t*5)*.22
 p=Path('DroneArena/audio')/(name+'.wav')
 with wave.open(str(p),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(48000);f.writeframes((np.clip(s,-1,1)*32767).astype('<i2').tobytes())
