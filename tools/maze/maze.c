// SA-Maze-Optimierer (Kartengröße beim Kompilieren: -DW=56 -DH=56): N 2x2-Blöcke auf 56x56, Weg spawn->checkpoints->goal (Oktil, keine Ecken schneiden)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifndef W
#define W 56
#endif
#ifndef H
#define H 56
#endif
#define NC (W*H)
static int buildable[NC], walk[NC], solid[NC], occ[NC];
static int wp[16][2], nwp;
static int NB; static int bx[1000], by[1000];
static double CX=-1, CY=-1, R=12, ALPHA=0;
static unsigned long long rs=88172645463325252ULL;
static unsigned long long rnd(){ rs^=rs<<13; rs^=rs>>7; rs^=rs<<17; return rs; }
static double frand(){ return (rnd()>>11)*(1.0/9007199254740992.0); }
// Dijkstra
static int dist[NC], prv[NC], heap[NC*8], hk[NC*8], hn;
static void hpush(int k,int v){ int i=hn++; while(i>0){int p=(i-1)/2; if(hk[p]<=k)break; hk[i]=hk[p]; heap[i]=heap[p]; i=p;} hk[i]=k; heap[i]=v; }
static int hpop(int*k){ int v=heap[0]; *k=hk[0]; hn--; int lk=hk[hn], lv=heap[hn]; int i=0; for(;;){int c=2*i+1; if(c>=hn)break; if(c+1<hn&&hk[c+1]<hk[c])c++; if(hk[c]>=lk)break; hk[i]=hk[c]; heap[i]=heap[c]; i=c;} hk[i]=lk; heap[i]=lv; return v; }
static int DX[8]={1,-1,0,0,1,1,-1,-1}, DY[8]={0,0,1,-1,1,-1,1,-1};
static int pathbuf[NC*8], plen; static int cpath[NC*8], cplen;
static int tmpb[NC];
static int seg(int s,int t,int append){
  for(int i=0;i<NC;i++) dist[i]=1<<29;
  hn=0; dist[s]=0; int tx=t%W, ty=t/W; hpush(0,s);
  while(hn){ int k; int u=hpop(&k); { int ux=u%W-tx, uy=u/W-ty; if(ux<0)ux=-ux; if(uy<0)uy=-uy; int hh=ux<uy? 14*ux+10*(uy-ux):14*uy+10*(ux-uy); if(k-hh>dist[u])continue; } if(u==t)break;
    int x=u%W,y=u/W;
    for(int d=0;d<8;d++){ int nx=x+DX[d],ny=y+DY[d]; if(nx<0||ny<0||nx>=W||ny>=H)continue; int v=ny*W+nx; if(solid[v])continue;
      int c=10; if(d>=4){ if(solid[y*W+nx]||solid[ny*W+x])continue; c=14; }
      if(dist[u]+c<dist[v]){dist[v]=dist[u]+c; prv[v]=u; int ax=nx-tx, ay=ny-ty; if(ax<0)ax=-ax; if(ay<0)ay=-ay; int h2=ax<ay? 14*ax+10*(ay-ax):14*ay+10*(ax-ay); hpush(dist[v]+h2,v);} } }
  if(dist[t]>=1<<29) return -1;
  if(append){ int*tmp=tmpb; int n=0; for(int v=t; v!=s; v=prv[v]) tmp[n++]=v; if(plen==0) pathbuf[plen++]=s; for(int i=n-1;i>=0;i--) pathbuf[plen++]=tmp[i]; }
  return dist[t];
}
static double score_L, score_in;
static double evaluate(int full){
  int tot=0; plen=0;
  for(int i=0;i<nwp-1;i++){ int r=seg(wp[i][1]*W+wp[i][0], wp[i+1][1]*W+wp[i+1][0], 1); if(r<0) return -1; tot+=r; }
  score_L=tot/10.0; score_in=0;
  if(ALPHA>0||full){ if(CX>=0) for(int i=1;i<plen;i++){ int a=pathbuf[i-1], b=pathbuf[i];
      double mx=(a%W+b%W)/2.0+0.5, my=(a/W+b/W)/2.0+0.5; double dx=mx-CX, dy=my-CY;
      if(dx*dx+dy*dy<=R*R) score_in += ((a%W!=b%W)&&(a/W!=b/W))?1.4142:1.0; } }
  return score_L + ALPHA*score_in;
}
static int canput(int x,int y){ if(x<0||y<0||x+1>=W||y+1>=H) return 0; for(int dy=0;dy<2;dy++)for(int dx=0;dx<2;dx++){int c=(y+dy)*W+x+dx; if(!buildable[c]||occ[c])return 0;} return 1; }
static void put(int x,int y,int on){ for(int dy=0;dy<2;dy++)for(int dx=0;dx<2;dx++){int c=(y+dy)*W+x+dx; occ[c]=on; solid[c]=on||!walk[c];} }
int main(int argc,char**argv){
  // args: mapfile N iters seed [cx cy R alpha]
  FILE*f=fopen(argv[1],"r"); NB=atoi(argv[2]); long iters=atol(argv[3]); rs^=atoll(argv[4])*2654435761ULL; for(int i=0;i<10;i++)rnd();
  if(argc>8){CX=atof(argv[5]);CY=atof(argv[6]);R=atof(argv[7]);ALPHA=atof(argv[8]);}
  char line[256];
  for(int y=0;y<H;y++){ fgets(line,256,f); for(int x=0;x<W;x++){ walk[y*W+x]=line[x]=='.'; buildable[y*W+x]=line[x]=='b'; if(line[x]=='b') walk[y*W+x]=1; solid[y*W+x]=!walk[y*W+x]; } }
  fscanf(f,"%d",&nwp); for(int i=0;i<nwp;i++) fscanf(f,"%d %d",&wp[i][0],&wp[i][1]); fclose(f);
  // optional start file
  int nb=0;
  char*init=getenv("INIT"); if(init){ FILE*g=fopen(init,"r"); int x,y; while(nb<NB && fscanf(g,"%d %d",&x,&y)==2){ if(canput(x,y)){put(x,y,1); if(evaluate(0)<0){put(x,y,0);continue;} bx[nb]=x;by[nb]=y;nb++;} } fclose(g); }
  while(nb<NB){ int x=rnd()%W,y=rnd()%H; if(!canput(x,y))continue; put(x,y,1); if(evaluate(0)<0){put(x,y,0);continue;} bx[nb]=x;by[nb]=y;nb++; }
  double cur=evaluate(0), best=cur; memcpy(cpath,pathbuf,plen*sizeof(int)); cplen=plen; int bbx[1000],bby[1000]; memcpy(bbx,bx,sizeof bx); memcpy(bby,by,sizeof by);
  double T0=getenv("T0")?atof(getenv("T0")):8, T1=getenv("T1")?atof(getenv("T1")):0.05;
  for(long it=0;it<iters;it++){
    double T=T0*pow(T1/T0,(double)it/iters);
    int i=rnd()%NB; int ox=bx[i],oy=by[i]; put(ox,oy,0);
    int nx,ny,tries=0;
    do{ if(rnd()%4==0){ nx=ox+(int)(rnd()%7)-3; ny=oy+(int)(rnd()%7)-3; } else { int p=cpath[rnd()%cplen]; nx=p%W+(int)(rnd()%5)-3; ny=p/W+(int)(rnd()%5)-3; } tries++; } while(!canput(nx,ny) && tries<50);
    if(!canput(nx,ny)){ put(ox,oy,1); continue; }
    put(nx,ny,1); double s=evaluate(0);
    if(s>=0 && (s>=cur || frand()<exp((s-cur)/T))){ bx[i]=nx;by[i]=ny;cur=s; memcpy(cpath,pathbuf,plen*sizeof(int)); cplen=plen; if(cur>best){best=cur;memcpy(bbx,bx,sizeof bx);memcpy(bby,by,sizeof by);} }
    else { put(nx,ny,0); put(ox,oy,1); }
  }
  // restore best
  for(int i=0;i<NB;i++) put(bx[i],by[i],0);
  for(int i=0;i<NB;i++) put(bbx[i],bby[i],1);
  evaluate(1);
  fprintf(stderr,"best %.1f L %.1f in %.1f\n",best,score_L,score_in);
  printf("%.1f %.1f %.1f\n",best,score_L,score_in);
  for(int i=0;i<NB;i++) printf("%d %d\n",bbx[i],bby[i]);
  return 0;
}
