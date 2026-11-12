"""Manipulation de la cellule H-01 et clic à vide, originaux et reproductibles."""
from pathlib import Path
import json
import numpy as np
from design_mechanical import RATE, DEST, noise, knock, save, manifest


def reload():
    t = np.arange(int(RATE*1.8))/RATE
    air = noise(len(t), 510, 180, 6800)
    result = np.zeros_like(t)
    # Déverrouillage, retrait, insertion de la cellule et verrouillage de culasse.
    for at, gain in [(.025,.42), (.20,.24), (.29,.13), (1.10,.30), (1.35,.48), (1.63,.48)]:
        age = np.maximum(t-at, 0)
        env = (t>=at)*(1-np.exp(-age*2500))*np.exp(-age*70)
        result += knock(t, at, gain) + air*env*gain*.45
    movement = np.clip((t-.30)/.08, 0, 1)*np.clip((.96-t)/.10, 0, 1)
    result += movement*air*.025*(.5+.5*np.sin(2*np.pi*17*t)**2)
    age = np.maximum(t-1.37, 0)
    charge = (t>=1.37)*np.clip((1.63-t)/.06, 0, 1)*(1-np.exp(-age*60))
    result += charge*(np.sin(2*np.pi*(350*age+900*age*age))*.055 + air*.012)
    return result


def empty():
    t = np.arange(int(RATE*.16))/RATE
    return knock(t,.005,.6) + noise(len(t),511,850,7200)*np.exp(-t*95)*.06


if __name__ == '__main__':
    DEST.mkdir(parents=True, exist_ok=True)
    save('weapon_reload', reload(), peak=.72)
    save('weapon_empty', empty(), peak=.38)
    output = Path(__file__).parent / 'reload_manifest.json'
    output.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(json.dumps(manifest, indent=2))
