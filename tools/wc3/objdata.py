"""Liest WC3-Objektdaten (w3u/w3t/w3b/w3d/w3a/w3h/w3q) und Stringtabelle (wts) als JSON."""
import struct, sys, json, re, os

def read_wts(path):
    if not os.path.exists(path):
        return {}
    t = open(path, 'rb').read().decode('utf-8', 'replace')
    out = {}
    for m in re.finditer(r'STRING (\d+)\s*(?://[^\n]*\n\s*)?\{\r?\n(.*?)\r?\n\}', t, re.S):
        out[int(m.group(1))] = m.group(2)
    return out

def resolve(v, wts):
    if isinstance(v, str):
        m = re.fullmatch(r'TRIGSTR_(\d+)', v)
        if m:
            return wts.get(int(m.group(1)), v)
    return v

def parse(path, levels, wts):
    d = open(path, 'rb').read()
    p = 0
    def i32():
        nonlocal p
        v = struct.unpack_from('<i', d, p)[0]; p += 4; return v
    def f32():
        nonlocal p
        v = struct.unpack_from('<f', d, p)[0]; p += 4; return v
    def raw4():
        nonlocal p
        v = d[p:p + 4]; p += 4; return v.decode('latin1')
    def cstr():
        nonlocal p
        e = d.index(b'\0', p); v = d[p:e].decode('utf-8', 'replace'); p = e + 1; return v
    ver = i32()
    objs = []
    for table in ('orig', 'custom'):
        n = i32()
        for _ in range(n):
            oid, nid = raw4(), raw4()
            if ver >= 3:
                sets = i32()
                # version 3 (Reforged): mehrere Sets; nur Grundset lesen
            else:
                sets = 1
            mods = {}
            for s in range(sets):
                if ver >= 3:
                    i32()  # set flag
                mc = i32()
                for _ in range(mc):
                    mid = raw4()
                    typ = i32()
                    lvl = None
                    if levels:
                        lvl = i32(); i32()
                    if typ == 0:
                        v = i32()
                    elif typ in (1, 2):
                        v = round(f32(), 4)
                    else:
                        v = resolve(cstr(), wts)
                    i32()  # end marker
                    key = mid if not lvl else '%s@%d' % (mid, lvl)
                    mods[key] = v
            objs.append({'table': table, 'base': oid, 'id': nid if nid != '\0\0\0\0' else oid, 'mods': mods})
    return objs

if __name__ == '__main__':
    x = sys.argv[1]
    wts = read_wts(os.path.join(x, 'war3map.wts'))
    res = {}
    for ext, lv in (('w3u', 0), ('w3t', 0), ('w3b', 0), ('w3h', 0), ('w3d', 1), ('w3a', 1), ('w3q', 1)):
        f = os.path.join(x, 'war3map.' + ext)
        if os.path.exists(f):
            try:
                res[ext] = parse(f, lv, wts)
                print(ext, len(res[ext]))
            except Exception as e:
                print('ERR', ext, e)
    json.dump(res, open(os.path.join(x, 'objects.json'), 'w'), ensure_ascii=False, indent=1)
    json.dump(wts, open(os.path.join(x, 'wts.json'), 'w'), ensure_ascii=False, indent=1)
