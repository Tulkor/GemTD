# Schriftzug "TD HUB" fürs Hauptmenü (Logo-Variante 16 des WC3-Mockups) als .glb:
# kleines "TD" (Cinzel Black) über großem "HUB" (Cinzel Decorative Black), Messing, HUB mit dunklem Eisenrand.
# Die Rubine setzt das Spiel selbst dazu (scripts/ui/wc3_logo.gd), damit sie sich drehen.
# Aufruf (Python mit bpy, z. B. uv-venv mit "bpy"):
#   python -I tools/menu/td_hub_logo.py <repo> [ausgabe.glb]
import bpy, bmesh, sys, os, math
from mathutils import Vector

REPO = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(REPO, "assets/models/ui/td_hub_logo.glb")
FONTS = os.path.join(REPO, "assets/fonts")


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def metal(name, col, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = srgb(col)
    p.inputs["Metallic"].default_value = 1.0
    p.inputs["Roughness"].default_value = rough
    return m


def new_obj(name, data):
    o = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(o)
    return o


def letter(ch, font, size, mat, extrude, bevel):
    cu = bpy.data.curves.new(ch, "FONT")
    cu.body = ch
    cu.font = font
    cu.size = size
    cu.extrude = extrude
    cu.bevel_depth = bevel
    cu.bevel_resolution = 2
    cu.resolution_u = 8
    o = new_obj(ch, cu)
    o.data.materials.append(mat)
    return o


def advance(font, ch, size):
    a = bpy.data.curves.new("a", "FONT"); a.body = ch + ch; a.font = font; a.size = size
    b = bpy.data.curves.new("b", "FONT"); b.body = ch; b.font = font; b.size = size
    oa, ob = new_obj("a", a), new_obj("b", b)
    bpy.context.view_layer.update()
    d = oa.dimensions.x - ob.dimensions.x
    bpy.data.objects.remove(oa); bpy.data.objects.remove(ob)
    return d


def bounds(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def word(text, font, size, mats, z0, track=0.0, extrude=0.08, bevel=0.018, outline=0.0):
    """Buchstaben einzeln nach den Vorschubbreiten. outline > 0: zweite, dickere Schicht dahinter im zweiten Material."""
    xs, x = [], 0.0
    for ch in text:
        xs.append((ch, x))
        x += advance(font, ch, size) + track * size
    width = x - track * size
    out = []
    for ch, xi in xs:
        layers = [(mats[0], extrude, 0.0, 0.0)]
        if outline:
            layers.append((mats[1], extrude * 0.5, outline * size, 0.06))
        for mat, ex, bv, dy in layers:
            o = letter(ch, font, size, mat, ex, bv)
            o.rotation_euler.x = math.radians(90)
            o.location = (xi - width / 2, dy, z0)
            out.append(o)
    bpy.context.view_layer.update()
    main = [o for o in out if o.data.bevel_depth == 0]
    bpy.ops.object.select_all(action="DESELECT")
    for o in out:
        o.select_set(True)
    bpy.context.view_layer.objects.active = out[0]
    bpy.ops.object.convert(target="MESH")
    for o in out:
        for poly in o.data.polygons:
            poly.use_smooth = True
    # Randschicht: Stacheln an spitzen Ecken abschneiden
    if outline:
        for i in range(0, len(out) - 1, 2):
            front, back = out[i], out[i + 1]
            lo, hi = bounds([front])
            pad = outline * size * 2.5
            bm = bmesh.new(); bm.from_mesh(back.data)
            mw = back.matrix_world
            bad = [v for v in bm.verts if not (lo.x - pad <= (mw @ v.co).x <= hi.x + pad and lo.z - pad <= (mw @ v.co).z <= hi.z + pad)]
            bmesh.ops.delete(bm, geom=bad, context="VERTS")
            bm.to_mesh(back.data); bm.free()
    # Fase als Modifier mit Überlappungsschutz (Kurven-Fase macht an spitzen Ecken Stacheln)
    for o in main:
        m = o.modifiers.new("fase", "BEVEL"); m.width = bevel * 1.4; m.segments = 3
        m.limit_method = "ANGLE"; m.use_clamp_overlap = True
    return out


bpy.ops.wm.read_factory_settings(use_empty=True)
brass = metal("messing", "c9a36a", 0.5)
iron = metal("eisen", "2e2d31", 0.5)
cinzel = bpy.data.fonts.load(os.path.join(FONTS, "Cinzel-Black.ttf"))
deco = bpy.data.fonts.load(os.path.join(FONTS, "CinzelDecorative-Black.ttf"))
objs = word("TD", cinzel, 0.55, [brass], 1.0, track=0.25)
objs += word("HUB", deco, 1.25, [brass, iron], 0.0, track=-0.02, outline=0.025)
# Mitte des Schriftzugs in den Ursprung, damit das Spiel ihn einfach ausrichten kann
lo, hi = bounds(objs)
c = (lo + hi) / 2
for o in objs:
    o.location -= Vector((c.x, 0, c.z))
bpy.context.view_layer.update()
lo, hi = bounds(objs[:2])
print("TD-Grenzen", tuple(round(v, 3) for v in lo), tuple(round(v, 3) for v in hi))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
print("GESPEICHERT", OUT)
