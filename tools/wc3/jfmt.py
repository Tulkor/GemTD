import re,sys
t=open(sys.argv[1],encoding='latin1').read()
parts=re.split(r'("(?:[^"\\]|\\.)*")',t)
kw=r'(endfunction|function |call |set |elseif|else(?!if)|endif|if(?=\(| )|loop|exitwhen |endloop|local |return|globals|endglobals)'
out=[]
for i,p in enumerate(parts):
    if i%2: out.append(p)
    else: out.append(re.sub(kw,r'\n\1',p))
s=''.join(out)
s=re.sub(r'\n(endif|else)(?=\w)',r'\n\1',s)
open(sys.argv[2],'w',encoding='latin1').write(s)
