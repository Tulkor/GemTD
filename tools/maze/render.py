# Schema-Bild: Steine/Tower als 2x2-Blöcke, Weg als Linie, Checkpoints, optional Cluster-Kreis
import sys, json, heapq, math
from PIL import Image, ImageDraw, ImageFont
mapf, blocks, out = sys.argv[1], sys.argv[2], sys.argv[3]
cx = cy = rr = None
if len(sys.argv) > 6: cx, cy, rr = map(float, sys.argv[4:7])
d = json.load(open(mapf)); W, H = d['width'], d['height']
wps = [d['spawn']] + d['checkpoints'] + [d['goal']]
solid = [[d['tiles'][y][x] != '.' for x in range(W)] for y in range(H)]
rocks, towers = [], []
for line in open(blocks):
    p = line.split()
    if len(p) == 2: rocks.append((int(p[0]), int(p[1])))
    elif len(p) == 4 and p[0] == 'T': towers.append((int(p[1]), int(p[2])))
for x, y in rocks + towers:
    for dy in (0, 1):
        for dx in (0, 1): solid[y+dy][x+dx] = True
def seg(s, t):
    dist = {s: 0}; prev = {}; pq = [(0, s)]
    while pq:
        k, u = heapq.heappop(pq)
        if u == t: break
        if k > dist[u]: continue
        x, y = u
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)):
            nx, ny = x+dx, y+dy
            if not (0 <= nx < W and 0 <= ny < H) or solid[ny][nx]: continue
            c = 1.0
            if dx and dy:
                if solid[y][nx] or solid[ny][x]: continue
                c = math.sqrt(2)
            if k + c < dist.get((nx, ny), 1e9):
                dist[(nx, ny)] = k + c; prev[(nx, ny)] = u; heapq.heappush(pq, (k + c, (nx, ny)))
    p = [t]
    while p[-1] != s: p.append(prev[p[-1]])
    return p[::-1], dist[t]
path, L = [tuple(wps[0])], 0
for a, b in zip(wps, wps[1:]):
    p, l = seg(tuple(a), tuple(b)); path += p[1:]; L += l
S = 16; M = 30
img = Image.new('RGB', (W*S + 2*M, H*S + 2*M + 70), (24, 18, 36))
dr = ImageDraw.Draw(img)
try: font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 18)
except: font = ImageFont.load_default()
for y in range(H):
    for x in range(W):
        if d['tiles'][y][x] != '.':
            dr.rectangle([M+x*S, M+y*S, M+x*S+S-1, M+y*S+S-1], fill=(10, 8, 16))
for i in range(0, W+1, 2):
    dr.line([M+i*S, M, M+i*S, M+H*S], fill=(40, 32, 56))
    dr.line([M, M+i*S, M+W*S, M+i*S], fill=(40, 32, 56))
inside = 0.0
passes = 0
was_in = False
if cx is not None:
    dr.ellipse([M+(cx-rr)*S, M+(cy-rr)*S, M+(cx+rr)*S, M+(cy+rr)*S], fill=(40, 70, 40), outline=(110, 200, 110), width=3)
for x, y in rocks:
    dr.rectangle([M+x*S+1, M+y*S+1, M+(x+2)*S-2, M+(y+2)*S-2], fill=(150, 120, 200))
for x, y in towers:
    dr.rectangle([M+x*S+1, M+y*S+1, M+(x+2)*S-2, M+(y+2)*S-2], fill=(240, 190, 60))
pts = [(M+(x+0.5)*S, M+(y+0.5)*S) for x, y in path]
for i in range(1, len(path)):
    a, b = path[i-1], path[i]
    col = (90, 220, 255)
    if cx is not None:
        mx, my = (a[0]+b[0])/2+0.5, (a[1]+b[1])/2+0.5
        now_in = (mx-cx)**2 + (my-cy)**2 <= rr*rr
        if now_in:
            col = (255, 120, 90); inside += math.hypot(b[0]-a[0], b[1]-a[1])
        if now_in and not was_in: passes += 1
        was_in = now_in
    dr.line([pts[i-1], pts[i]], fill=col, width=3)
labels = ['S'] + [str(i+1) for i in range(len(wps)-2)] + ['Z']
for (x, y), lab in zip(wps, labels):
    dr.rectangle([M+(x-1)*S, M+(y-1)*S, M+(x+2)*S-1, M+(y+2)*S-1], fill=(200, 40, 90))
    dr.text((M+(x+0.5)*S, M+(y+0.5)*S), lab, fill='white', font=font, anchor='mm')
txt = 'Weglänge %.0f Felder = %.0f Towerbreiten · %d Blöcke' % (L, L/2, len(rocks)+len(towers))
if cx is not None: txt += '\nim Cluster-Radius %.0f Felder, %d Durchgänge' % (inside, passes)
dr.multiline_text((M, H*S + M + 8), txt, fill='white', font=font, spacing=6)
img.save(out)
print(txt)
