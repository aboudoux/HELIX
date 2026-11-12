"""Ciel original et plafonds HELIX, sans pack externe ni changement de physique.

python art/environment/build_environment.py
Puis python art/mission/build_scenes.py pour réassembler la mission.
Les éléments du plafond sont de vrais nœuds éditables dans Godot.
"""
from pathlib import Path
import json
import math
import re
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "DroneArena"
DEST = PROJECT / "environment"
DEST.mkdir(exist_ok=True)


def write(name, source):
    if name.endswith((".tscn", ".tres")):
        source = re.sub(r'(?<![\w\d])(-?)\.(\d)', r'\g<1>0.\2', source)
    (DEST / name).write_text(source, encoding="utf-8", newline="\n")


def galaxy():
    """Panorama équirectangulaire 4K : poussières, nébuleuses et étoiles fixes."""
    rng = np.random.default_rng(41004)
    w, h = 4096, 2048
    longitude = (np.arange(w, dtype=np.float32) / w * 2 * np.pi)[None, :]
    latitude = ((.5 - np.arange(h, dtype=np.float32) / h) * np.pi)[:, None]
    x = np.cos(latitude) * np.sin(longitude)
    y = np.broadcast_to(np.sin(latitude), (h, w))
    z = np.cos(latitude) * np.cos(longitude)
    # La Voie lactée traverse la voûte, à environ 55 degrés d'élévation.
    d = .55 * y + .835 * z
    waves = .018 * np.sin(longitude * 7 + latitude * 3)
    clouds = np.zeros((h, w), dtype=np.float32)
    fine = np.zeros_like(clouds)
    for n, weight in [(32, .45), (64, .27), (128, .16), (256, .08), (512, .04)]:
        noise = Image.fromarray(rng.integers(0, 256, (n//2, n), dtype=np.uint8))
        layer = np.asarray(noise.resize((w, h), Image.Resampling.BICUBIC), dtype=np.float32) / 255
        clouds += layer * weight
        if n >= 128:
            fine += layer * weight
    band = np.exp(-((d + waves) / .115)**2) * np.clip((clouds - .24) * 3.4, 0, 1.7)
    halo = np.exp(-(d / .25)**2)
    bulge = np.exp(-((x - .20)**2 + (y - .82)**2 + (z + .54)**2) / .24)
    dust = np.exp(-((d + (clouds - .5) * .19) / .025)**2) * .80
    filaments = np.clip((fine - .105) * 18, 0, 1)
    glow = band * (1 - dust) * (.55 + filaments * .45)
    rgb = np.zeros((h, w, 3), dtype=np.float32)
    rgb[:] = [.0009, .0013, .0028]
    # Bleu ardoise et mauve discret ; le noir demeure dominant hors de la galaxie.
    for channel, (a, b, c) in enumerate(zip([.085, .082, .14], [.006, .008, .018], [.11, .077, .055])):
        rgb[:, :, channel] += glow * a + halo * b + bulge * glow * c
    image = Image.fromarray(np.uint8(np.clip(rgb, 0, 1) * 255))
    stars = Image.new("RGB", (w, h))
    draw = ImageDraw.Draw(stars)
    colors = [(190, 216, 255), (235, 240, 255), (255, 229, 191), (177, 199, 255)]
    for i in range(22000):
        sx = int(rng.integers(w))
        sy = int(np.arccos(rng.uniform(-1, 1)) / np.pi * h)
        brightness = float(rng.power(.65))
        color = tuple(int(c * (.23 + .77 * brightness)) for c in colors[i % len(colors)])
        if i < 21600:
            draw.point((sx, sy), fill=color)
        else:
            radius = float(rng.uniform(.65, 1.65))
            draw.ellipse((sx-radius, sy-radius, sx+radius, sy+radius), fill=color)
            if i % 11 == 0:
                draw.line((sx-4, sy, sx+4, sy), fill=tuple(int(c*.30) for c in color))
                draw.line((sx, sy-4, sx, sy+4), fill=tuple(int(c*.30) for c in color))
    # Petits halos seulement autour des étoiles les plus lumineuses.
    base = np.asarray(image, dtype=np.float32)
    light = np.asarray(stars, dtype=np.float32)
    halo_image = np.asarray(stars.filter(ImageFilter.GaussianBlur(2)), dtype=np.float32)
    image = Image.fromarray(np.uint8(np.clip(base + light + halo_image * .65, 0, 255)))
    image.save(DEST / "helix_galaxy.png", optimize=True)
    print("Panorama original : 4096 x 2048, 22 000 étoiles")


write("space.tres", '''[gd_resource type="Environment" load_steps=5 format=3]

[ext_resource type="Texture2D" path="res://environment/helix_galaxy.png" id="stars"]

[sub_resource type="PanoramaSkyMaterial" id="panorama"]
panorama = ExtResource("stars")
energy_multiplier = 1.2

[sub_resource type="Sky" id="space"]
radiance_size = 4
sky_material = SubResource("panorama")

[resource]
resource_name = "HELIX / nuit orbitale"
background_mode = 2
sky = SubResource("space")
sky_rotation = Vector3(0, 3.35, 0)
ambient_light_source = 2
ambient_light_color = Color(0.48, 0.6, 0.76, 1)
ambient_light_energy = 0.42
reflected_light_source = 2
tonemap_mode = 2
tonemap_exposure = 1.1
glow_enabled = true
glow_intensity = 0.38
glow_hdr_threshold = 1.5
fog_enabled = false
ssao_enabled = true
ssao_radius = 1.5
ssao_intensity = 1.1
'''.replace('load_steps=5', 'load_steps=4'))

write("ceiling_panels.gdshader", '''shader_type spatial;
// Habillage des tôles, en mètres : joints, nervures et petites diodes.
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
    vec2 p = local_position.xz;
    vec2 cell = abs(fract((p + vec2(0.0, 0.1)) / vec2(3.0, 4.0)) - 0.5);
    float seam = max(step(0.489, cell.x), step(0.490, cell.y));
    float inset = step(0.40, cell.x) * step(cell.x, 0.44);
    float grille = step(0.18, cell.x) * step(cell.x, 0.34) * step(0.31, cell.y) * step(cell.y, 0.40);
    float fin = step(0.60, fract(p.y * 14.0));
    ALBEDO = mix(vec3(0.13, 0.165, 0.20), vec3(0.017, 0.025, 0.036), seam);
    ALBEDO *= 1.0 - inset * 0.30 - grille * fin * 0.60;
    METALLIC = 0.64;
    ROUGHNESS = 0.58;
    float diode = step(0.445, cell.x) * step(cell.x, 0.46) * step(0.25, cell.y) * step(cell.y, 0.34);
    EMISSION = vec3(0.04, 0.9, 1.0) * diode * 1.7;
}
''')


def v(x, y, z):
    return f"Vector3({x:.5f}, {y:.5f}, {z:.5f})"


class Roof:
    def __init__(self, name):
        self.ext = ['[ext_resource type="Shader" path="res://environment/ceiling_panels.gdshader" id="panel_shader"]']
        self.sub = []
        self.nodes = [f'[node name="{name}" type="Node3D" groups=["station_roofs"]]\n']
        self.meshes = {}
        self.materials = {}
        self.current = "."
        self.count = 0
        for name, color, metal, rough, emission in [
            ("frame", (.065, .09, .12), .78, .37, 0),
            ("trim", (.35, .42, .46), .75, .35, 0),
            ("ceramic", (.56, .61, .63), .25, .46, 0),
            ("orange", (.9, .27, .055), .42, .48, 0),
            ("cyan", (.10, .8, 1), .25, .24, 3.5),
            ("white", (.74, .88, 1), .15, .32, 2.8),
            ("amber", (1, .43, .10), .25, .28, 2.5),
        ]:
            ident = "mat_" + name
            self.materials[name] = f'SubResource("{ident}")'
            props = f'albedo_color = Color({color[0]}, {color[1]}, {color[2]}, 1)\nmetallic = {metal}\nroughness = {rough}\n'
            if emission:
                props += f'emission_enabled = true\nemission = Color({color[0]}, {color[1]}, {color[2]}, 1)\nemission_energy_multiplier = {emission}\n'
            self.sub.append(f'[sub_resource type="StandardMaterial3D" id="{ident}"]\n{props}')
        self.materials["panel"] = 'SubResource("mat_panel")'
        self.sub.append('[sub_resource type="ShaderMaterial" id="mat_panel"]\nshader = ExtResource("panel_shader")\n')
        self.materials["glass"] = 'SubResource("mat_glass")'
        self.sub.append('''[sub_resource type="StandardMaterial3D" id="mat_glass"]
resource_name = "Verre orbital / légèrement bleuté"
transparency = 1
cull_mode = 2
albedo_color = Color(0.12, 0.20, 0.28, 0.028)
metallic = 0.18
roughness = 0.12
''')

    def node(self, name, kind, props, group=None):
        groups = f' groups=["{group}"]' if group else ''
        self.nodes.append(f'[node name="{name}" type="{kind}" parent="{self.current}"{groups}]\n{props}\n')

    def box(self, name, center, size, mat, rotation=None):
        self.count += 1
        key = tuple(size)
        if key not in self.meshes:
            ident = "mesh" + str(len(self.meshes))
            self.meshes[key] = f'SubResource("{ident}")'
            self.sub.append(f'[sub_resource type="BoxMesh" id="{ident}"]\nsize = {v(*size)}\n')
        props = f'position = {v(*center)}\nmesh = {self.meshes[key]}\nmaterial_override = {self.materials[mat]}\n'
        if rotation:
            props += f'rotation = {v(*rotation)}\n'
        if mat in ["glass", "cyan", "white", "amber"]:
            props += 'cast_shadow = 0\n'
        self.node(name + str(self.count), "MeshInstance3D", props, "orbital_glass" if mat == "glass" else None)

    def room(self, name, rect, window, height=9.4, accent="cyan"):
        x, z, w, d = rect
        cx, cz = x + w/2, z + d/2
        self.current = "."
        self.node(name, "Node3D", f'position = {v(cx, height, cz)}', "roof_sector")
        self.current = name
        ww, wd = window
        # Quatre bandes opaques autour de la verrière centrale.
        for sign in [-1, 1]:
            self.box("ServiceLateral", (sign*(w+ww)/4, 0, 0), ((w-ww)/2, .26, d), "panel")
            self.box("ServiceTransversal", (0, 0, sign*(d+wd)/4), (ww, .26, (d-wd)/2), "panel")
            self.box("BandeauPerimetre", (sign*w/2, -.22, 0), (.48, .72, d), "frame")
            self.box("BandeauPerimetre", (0, -.22, sign*d/2), (w, .72, .48), "frame")
            # Jonction vitrée entre les anciens murs (7 m) et la nouvelle toiture.
            skirt = height - 7
            self.box("Clerestory", (sign*w/2, -skirt/2, 0), (.035, skirt, d), "glass")
            self.box("Clerestory", (0, -skirt/2, sign*d/2), (w, skirt, .035), "glass")
            for i in range(max(1, math.ceil(d/8))):
                zz = -d/2 + (i+.5)*d/math.ceil(d/8)
                self.box("ConsoleMurale", (sign*w/2, -skirt/2, zz), (.50, skirt, .42), "frame")
            # Goulottes en céramique, sous-face graphite et deux lignes lumineuses.
            xx = sign*(ww/2+.55)
            self.box("Goulotte", (xx, -.32, 0), (.72, .52, d-.8), "ceramic")
            self.box("Rail", (xx, -.59, 0), (.47, .08, d-.8), "frame")
            for offset in [-.16, .16]:
                self.box("NeonContinu", (xx+offset, -.64, 0), (.065, .025, d-1.2), accent)
        # Vitrage en panneaux indépendants, montants et joints étanches.
        nx, nz = max(2, math.ceil(ww/7)), max(2, math.ceil(wd/8))
        for ix in range(nx):
            for iz in range(nz):
                self.box("Vitre", (-ww/2+(ix+.5)*ww/nx, .14, -wd/2+(iz+.5)*wd/nz), (ww/nx-.14, .035, wd/nz-.14), "glass")
        for ix in range(nx+1):
            xx = -ww/2 + ix*ww/nx
            self.box("NervureLongitudinale", (xx, .03, 0), (.18, .38, wd+.38), "frame")
            self.box("JointClair", (xx, -.17, 0), (.05, .025, wd), "trim")
        for iz in range(nz+1):
            zz = -wd/2 + iz*wd/nz
            # Grandes fermes transversales sur toute la largeur de la pièce.
            self.box("PoutreTransversale", (0, -.18, zz), (w, .44, .24), "frame")
            self.box("InsertMetal", (0, -.415, zz), (w-.8, .035, .10), "trim")
            for sign in [-1, 1]:
                self.box("Renfort", (sign*(ww/2+1), -.55, zz), (2.5, .34, .45), "ceramic", (0, 0, sign*.28))
                self.box("RepereSecurite", (sign*(ww/2+1), -.74, zz), (.7, .04, .48), "orange")
        # Luminaires segmentés : vraies sources, sans ombres multiples coûteuses.
        rows = max(2, math.ceil(d/13))
        for iz in range(rows):
            zz = -d/2+(iz+.5)*d/rows
            for sign in [-1, 1]:
                xx = sign*(w+ww)/4
                self.box("LuminaireSocle", (xx, -.28, zz), (2.4, .27, 1), "frame")
                self.box("LuminaireDiffusant", (xx, -.425, zz), (2.1, .025, .62), "white")
                self.node(f"Lumiere_{iz}_{sign+1}", "OmniLight3D", f'position = {v(xx, -1.1, zz)}\nlight_color = Color(.64, .80, 1, 1)\nlight_energy = 2.1\nomni_range = 18.0\nlight_bake_mode = 0', "ceiling_lights")
        # Un éclairage d'appoint chaud signale les panneaux techniques aux extrémités.
        for sign in [-1, 1]:
            zz = sign*(d+wd)/4
            for xx in [-ww*.28, ww*.28]:
                self.box("RampeAmbre", (xx, -.18, zz), (min(5,ww*.35), .035, .12), "amber")

    def save(self, name):
        write(name, '[gd_scene format=3]\n\n' + '\n'.join(self.ext + self.sub + self.nodes))
        print(name, ":", self.count, "éléments visuels, aucun collider")


if __name__ == "__main__":
    galaxy()
    layout = json.loads((PROJECT / "missions/relay_run/layout.json").read_text(encoding="utf-8"))
    roof = Roof("PlafondsStation")
    for name, rect, window, height, accent in zip(
        ["QuaiCargo", "Refroidissement", "ObservatoireReacteur", "Extraction", "Logistique", "Maintenance", "Centrale"],
        layout["floors"],
        [(30,30), (42,28), (52,40), (12,10), (12,18), (10,18), (10,18)],
        [9.4, 10.4, 11.4, 9.4, 8.6, 8.6, 8.6],
        ["cyan", "cyan", "cyan", "amber", "amber", "cyan", "amber"]):
        roof.room(name, rect, window, height, accent)
    roof.save("mission_roofs.tscn")
    roof = Roof("PlafondsEntrainement")
    roof.room("StandHelix", (-20,-24,40,48), (26,30))
    roof.save("training_roofs.tscn")
