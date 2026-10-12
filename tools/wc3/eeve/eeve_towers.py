import json, re, sys
o = json.load(open(sys.argv[1]))
U = {u['id']: u['mods'] for u in o['w3u']}
EL = {'R000': 'Magic', 'R001': 'Water', 'R002': 'Storm', 'R003': 'Earth', 'R004': 'Fire', 'R005': 'Nature'}

def clean(s):
    s = re.sub(r'\|c[0-9a-fA-F]{8}', '', s or '')
    return s.replace('|r', '').replace('|n', '\n').replace('\r', '')

def tip(m):
    t = clean(m.get('utub', ''))
    f = {}
    for k in ('Level', 'DPS', 'Speed', 'Range', 'Damage Type'):
        mm = re.search(k + r':\s*([^\n]*)', t)
        if mm:
            f[k] = mm.group(1).strip()
    mm = re.search(r'Abilities:\s*\n(.*)', t, re.S)
    f['Abilities'] = '; '.join(x.strip(' -') for x in (mm.group(1).split('\n') if mm else []) if x.strip(' -'))
    f['text'] = t
    return f

def elems(m):
    return [EL[r] for r in str(m.get('ureq', '')).split(',') if r in EL]

rows = []
seen = set()
def walk(uid, depth, parent, el):
    if uid in seen or uid not in U:
        return
    seen.add(uid)
    m = U[uid]
    f = tip(m)
    rows.append({'id': uid, 'name': m.get('unam'), 'element': '+'.join(elems(m)) or el, 'depth': depth, 'from': parent,
                 'cost': m.get('ugol'), 'lumber': m.get('ulum'), 'req_level': m.get('urqa'), 'tip': f,
                 'dmg_base': m.get('ua1b'), 'dmg_sides': m.get('ua1s'), 'cooldown': m.get('ua1c'),
                 'range': m.get('ua1r'), 'atype': m.get('ua1t'), 'targets': m.get('ua1g'), 'abil': m.get('uabi'),
                 'upgrades': m.get('uupt', '')})
    for nxt in [x for x in str(m.get('uupt', '') or '').split(',') if x]:
        walk(nxt, depth + 1, uid, el)

builder = U['u000']['ubui'].split(',') + ['h01D']
for b in builder:
    walk(b, 0, None, '+'.join(elems(U[b])) if b in U else '')
json.dump(rows, open(sys.argv[2], 'w'), ensure_ascii=False, indent=1)
for r in rows:
    t = r['tip']
    print('  ' * r['depth'] + '%s %s [%s] cost=%s+%sL lvl=%s dps=%s spd=%s rng=%s typ=%s | %s' % (
        r['id'], r['name'], r['element'], r['cost'], r['lumber'], r['req_level'], t.get('DPS'), t.get('Speed'),
        t.get('Range'), t.get('Damage Type'), t.get('Abilities')[:150]))
