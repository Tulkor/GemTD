# Boss-Modell "Little Man" (Don Carson, CC-BY 3.0, siehe assets/models/CREDITS.md): Skelett,
# Gewichte nach Körperregion und Animationen walk, idle, hit, death. Das Original ist ein starres Mesh.
# Aufruf (Blender als Python-Modul bpy, siehe tools/modelle/README.md):
#   <python mit bpy> -I tools/modelle/boss_rig.py -- <Little Man.glb> assets/models/enemies/little_man.glb
import bpy, sys, math
from mathutils import Vector, Quaternion, Matrix
argv = sys.argv[sys.argv.index('--') + 1:]
src, dst = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
mesh = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
# Transformationen anwenden, Mitte auf (0,0), Füße auf z=0
bpy.context.view_layer.objects.active = mesh
for o in bpy.context.scene.objects: o.select_set(o == mesh)
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
vs = [v.co.copy() for v in mesh.data.vertices]
legs = [v for v in vs if v.z < -0.3]
cx = sum(v.x for v in legs) / len(legs); cy = sum(v.y for v in legs) / len(legs)
zmin = min(v.z for v in vs)
off = Vector((-cx, -cy, -zmin))
for v in mesh.data.vertices: v.co += off
for o in list(bpy.context.scene.objects):
    if o != mesh: bpy.data.objects.remove(o)
H = max(v.co.z for v in mesh.data.vertices)
print('Höhe', H, 'Mitte', cx, cy)
# Höhen (vom Boden): Hüfte ~0.28, Arme 0.45..0.62, Hals ~0.62
HIP, SH_Z, NECK = 0.29, 0.53, 0.64
ELBOW = 0.26  # Abstand des Ellbogens von der Mitte
ARM_DOWN = 62  # Arme hängen so viele Grad unter der Waagrechten (das Original steht in T-Pose)

# Die Arme zeigen im Original schräg (links nach vorn, rechts nach hinten): Richtung je Seite aus den Händen
ARM_DIR = {}
for side, sg in (('L', 1), ('R', -1)):
    pts = [v.co for v in mesh.data.vertices if math.hypot(v.co.x, v.co.y) > 0.3
           and abs(v.co.z - SH_Z) < 0.13 and v.co.x * sg > 0]
    c = sum(pts, Vector()) / len(pts)
    ARM_DIR[side] = Vector((c.x, c.y, 0)).normalized()
print('Armrichtung', ARM_DIR)

arm = bpy.data.armatures.new('rig'); rig = bpy.data.objects.new('LittleMan', arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
def bone(name, h, t, parent=None):
    b = arm.edit_bones.new(name); b.head = h; b.tail = t; b.roll = 0
    if parent: b.parent = arm.edit_bones[parent]
    return b
bone('root', (0, 0, 0), (0, 0, 0.2))
bone('body', (0, 0, HIP), (0, 0, NECK), 'root')
bone('head', (0, 0, NECK), (0, 0, H), 'body')
bone('leg.L', (0.045, 0, HIP), (0.045, 0, 0.02), 'root')
bone('leg.R', (-0.045, 0, HIP), (-0.045, 0, 0.02), 'root')
for side in 'LR':
    d = ARM_DIR[side]; up = Vector((0, 0, SH_Z))
    bone('arm.' + side, up + d * 0.17, up + d * ELBOW, 'body')
    bone('hand.' + side, up + d * ELBOW, up + d * 0.42, 'arm.' + side)
bpy.ops.object.mode_set(mode='OBJECT')

def ramp(x, a, b):
    return min(max((x - a) / (b - a), 0.0), 1.0)
groups = {n: mesh.vertex_groups.new(name=n) for n in ['body', 'head', 'leg.L', 'leg.R', 'arm.L', 'arm.R', 'hand.L', 'hand.R']}
for v in mesh.data.vertices:
    p = v.co; r = math.hypot(p.x, p.y)
    w = {}
    leg = 1.0 - ramp(p.z, HIP - 0.06, HIP + 0.02)
    armw = ramp(r, 0.19, 0.25) * (1.0 - ramp(abs(p.z - SH_Z), 0.09, 0.13))
    headw = ramp(p.z, NECK - 0.04, NECK + 0.03) * (1.0 - armw)
    rest = 1.0 - leg
    a = armw * rest; h = headw * rest * (1 - armw)
    b = max(rest - a - h, 0.0)
    side = 'L' if p.x >= 0 else 'R'
    if leg > 0: w['leg.' + side] = leg
    fore = ramp(r, ELBOW - 0.015, ELBOW + 0.02)
    if a * (1 - fore) > 0: w['arm.' + side] = a * (1 - fore)
    if a * fore > 0: w['hand.' + side] = a * fore
    if h > 0: w['head'] = h
    if b > 0: w['body'] = b
    for n, x in w.items(): groups[n].add([v.index], x, 'REPLACE')
mesh.parent = rig
mod = mesh.modifiers.new('rig', 'ARMATURE'); mod.object = rig

# --- Animationen ---------------------------------------------------------
FPS = 24
bpy.context.scene.render.fps = FPS
pb = rig.pose.bones
for p in pb: p.rotation_mode = 'QUATERNION'
rest = {b.name: b.matrix_local.to_quaternion() for b in arm.bones}
def setrot(name, axis, deg):
    """Drehung um eine Welt-Achse (Ruhelage), in den Knochenraum umgerechnet."""
    qw = Quaternion(Vector(axis), math.radians(deg))
    q = rest[name].inverted() @ qw @ rest[name]
    pb[name].rotation_quaternion = q
def key(frame, poses, loc=None):
    for p in pb:
        p.rotation_quaternion = Quaternion(); p.location = Vector()
    poses = dict(poses)
    poses['arm.L'] = [(Z, YAW['L']), (Y, ARM_DOWN)] + list(poses.get('arm.L', []))
    poses['arm.R'] = [(Z, YAW['R']), (Y, -ARM_DOWN)] + list(poses.get('arm.R', []))
    for name, rots in poses.items():
        q = Quaternion()
        for axis, deg in rots:
            q = Quaternion(Vector(axis), math.radians(deg)) @ q
        pb[name].rotation_quaternion = rest[name].inverted() @ q @ rest[name]
    if loc: pb['root'].location = rest['root'].inverted() @ Vector(loc)
    for p in pb:
        p.keyframe_insert('rotation_quaternion', frame=frame)
        p.keyframe_insert('location', frame=frame)
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
# Grundhaltung: Arm erst seitlich ausrichten (links +X, rechts -X), dann hängen lassen
YAW = {'L': -math.degrees(math.atan2(ARM_DIR['L'].y, ARM_DIR['L'].x)),
       'R': -math.degrees(math.atan2(-ARM_DIR['R'].y, -ARM_DIR['R'].x))}
rig.animation_data_create()
def action(name, frames, cyclic=False):
    act = bpy.data.actions.new(name); act.use_fake_user = True
    rig.animation_data.action = act
    for f, poses, loc in frames: key(f, poses, loc)
    track = rig.animation_data.nla_tracks.new(); track.name = name
    track.strips.new(name, int(frames[0][0]), act)
    rig.animation_data.action = None
    return act

# Laufen: 1 s pro Doppelschritt, Watschelgang mit Wippen. Die Arme pendeln gegengleich zu den Beinen
# (linker Arm hinten, wenn das linke Bein vorne ist), schwingen eine Spur nach und knicken im Ellbogen
# beim Vorschwingen stärker ein; die Schultern drehen leicht gegen die Hüfte.
S = 24
def walk_pose(t):
    w = t * 2 * math.pi
    s = math.sin(w); c = abs(math.cos(w))
    a = math.sin(w - 0.35)          # Arme schwingen etwas nach
    fwd_l = max(-a, 0.0); fwd_r = max(a, 0.0)
    return ({'leg.L': [(X, 32 * s)], 'leg.R': [(X, -32 * s)],
             'arm.L': [(X, -30 * a)], 'arm.R': [(X, 30 * a)],
             'hand.L': [(Z, 10 + 22 * fwd_l)], 'hand.R': [(Z, -(10 + 22 * fwd_r))],
             'body': [(Y, 5 * s), (Z, -5 * s), (X, -4)], 'head': [(Y, -4 * s), (Z, 4 * s)]},
            (0, 0, 0.035 * c))
N = 16
action('walk', [(1 + i * S / N, *walk_pose(i / N)) for i in range(N + 1)], True)
# Stehen (betäubt): leichtes Atmen
action('idle', [(1, {'body': [(X, 0)]}, None), (13, {'body': [(X, -3)], 'arm.L': [(Y, 6)], 'arm.R': [(Y, -6)], 'head': [(X, 3)]}, (0, 0, -0.01)), (25, {'body': [(X, 0)]}, None)], True)
# Treffer: kurz nach hinten kippen, Arme hoch
action('hit', [(1, {}, None),
               (4, {'body': [(X, 14)], 'head': [(X, 10)], 'arm.L': [(Y, -45)], 'arm.R': [(Y, 45)], 'hand.L': [(Z, 25)], 'hand.R': [(Z, -25)]}, (0, -0.03, 0)),
               (10, {}, None)])
# Tod: Arme hochreißen, nach hinten umfallen, liegen bleiben
action('death', [(1, {}, None),
                 (6, {'body': [(X, 10)], 'head': [(X, 15)], 'arm.L': [(Y, -120)], 'arm.R': [(Y, 120)], 'leg.L': [(X, 10)]}, (0, 0, 0.04)),
                 (16, {'root': [(X, 80)], 'arm.L': [(Y, -80)], 'arm.R': [(Y, 80)], 'leg.L': [(X, 25)], 'leg.R': [(X, 10)], 'head': [(X, 10)]}, (0, -0.05, 0)),
                 (20, {'root': [(X, 90)], 'arm.L': [(Y, -20)], 'arm.R': [(Y, 20)], 'leg.L': [(X, 15)], 'head': [(X, 20)]}, (0, -0.06, 0)),
                 (24, {'root': [(X, 88)], 'arm.L': [(Y, -15)], 'arm.R': [(Y, 15)], 'leg.L': [(X, 10)], 'head': [(X, 25)]}, (0, -0.06, 0))])
for a in bpy.data.actions:
    for fc in getattr(a, 'fcurves', []):
        for k in fc.keyframe_points: k.interpolation = 'BEZIER'

bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_animations=True,
                          export_animation_mode='NLA_TRACKS', export_skins=True, export_yup=True,
                          export_apply=False, export_nla_strips_merged_animation_name='x')
print('ok', dst)
