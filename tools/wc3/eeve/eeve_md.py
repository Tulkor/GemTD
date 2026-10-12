import json,sys,re
r=json.load(open(sys.argv[1])); o=json.load(open(sys.argv[2])); out=sys.argv[3]
U={u['id']:u['mods'] for u in o['w3u']}
dup={'h007','h008','h009','h00A','h00B','h00D','h06Z','h0AV','h006','h0AW'}
byid={x['id']:x for x in r}
def total(x):
    g=0;l=0;c=x
    while c:
        g+=c['cost'] or 0; l+=c['lumber'] or 0
        c=byid.get(c['from']) if c['from'] else None
    return g,l
EN={'Magic':'Magie','Water':'Wasser','Storm':'Sturm','Earth':'Erde','Fire':'Feuer','Nature':'Natur'}
TY={'Chaos':'Chaos','Elemental':'Elementar','Magic':'Magie','Physical':'Physisch','Electricity':'Elektrisch','Spell':'Zauber'}
def esc(s): return str(s).replace('|','/')
sections={}
for x in r:
    t=x['tip']
    if not t.get('DPS') or x['id'] in dup: continue
    el=x['element']; key=el if '+' not in el else 'Dual'
    g,l=total(x)
    name=x['name']
    par=byid.get(x['from'],{}).get('name','') if x['from'] else ''
    if par=='Barricade': par='Barrikade'
    if not par and '+' not in el: par='direkt (Falle)'
    sections.setdefault(key,[]).append('| %s | %s | %s | %d%s | %s | %s | %s | %s | %s |'%(
        esc(name), str(x['req_level'] or '').replace(',', ' + '), esc(par) if '+' not in el else ' + '.join(EN[e] for e in el.split('+')),
        g, (' + %d Holz'%l) if l else '', t.get('DPS'), t.get('Speed'), t.get('Range'), esc(t.get('Damage Type')), esc(t.get('Abilities'))))
md={}
hdr='| Tower | Elementstufe | Upgrade von | Kosten gesamt | DPS | Tempo (s) | Reichweite | Schadensart | Fähigkeiten (Originaltext) |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n'
for k,rows in sections.items():
    md[k]=hdr.replace('Upgrade von','Elemente' if k=='Dual' else 'Upgrade von')+'\n'.join(rows)
json.dump(md,open(out,'w'),ensure_ascii=False,indent=1)
for k,v in md.items(): print(k,v.count('\n')-1)
