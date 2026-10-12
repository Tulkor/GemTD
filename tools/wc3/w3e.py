import struct,sys,collections
d=open(sys.argv[1],'rb').read()
p=4; ver,=struct.unpack_from('<i',d,p);p+=4
main=d[p:p+1];p+=1; cust,=struct.unpack_from('<i',d,p);p+=4
n,=struct.unpack_from('<i',d,p);p+=4; tiles=[d[p+4*i:p+4*i+4].decode() for i in range(n)];p+=4*n
n2,=struct.unpack_from('<i',d,p);p+=4; cl=[d[p+4*i:p+4*i+4].decode() for i in range(n2)];p+=4*n2
w,h=struct.unpack_from('<ii',d,p);p+=8; ox,oy=struct.unpack_from('<ff',d,p);p+=8
print('tiles',tiles,'cliffs',cl,'size',w,h,'origin',ox,oy)
pts=[]
for i in range(w*h):
    gh,wl,b1,b2,b3=struct.unpack_from('<hhBBB',d,p+7*i)
    pts.append((b1&15,(b3&15),b1>>4))
x0,y0,x1,y1=[float(v) for v in sys.argv[2:6]]
ch='.#~^=+*o%@ABCDEF'
cnt=collections.Counter()
for ty in range(int((y1-oy)/128),int((y0-oy)/128)-1,-1):
    row=''
    for tx in range(int((x0-ox)/128),int((x1-ox)/128)+1):
        t,lay,fl=pts[ty*w+tx]; cnt[t]+=1
        row+=ch[t] if lay<=2 else str(lay)
    print(row)
print({tiles[k]:v for k,v in cnt.items()})
