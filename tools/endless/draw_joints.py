"""The joint pictures of the sheet: python tools/endless/draw_joints.py <chunks.pkl> <pictures folder>"""
import sys,pickle,numpy as np,math
import draw as D, stack as st, chunks as ch
O=sys.argv[2].rstrip('/')+'/'
made,today=pickle.load(open(sys.argv[1],'rb'))
def two(lib,a,b,la,lb,ha=1,hb=1):
    c=lib[a]; p={"i":0,"shape":a,"hand":ha,"look":la,"layer":0,"s":0,"at":np.zeros(3),"h":0.0,"boss":False}
    q={"i":1,"shape":b,"hand":hb,"look":lb,"layer":0,"s":0,"at":c['exit']*np.array([ha,1,1]),"h":c['turn']*ha,"boss":False}
    return [p,q]
# raw cut of today: a typical misfit (side step near the median 129)
best=[]
for a in range(20,len(today)):
    for b in range(20,len(today)):
        if abs(a-b)<3: continue
        e=max(abs(today[a]['w1'][0]-today[b]['w0'][0]),abs(today[a]['w1'][1]-today[b]['w0'][1]))
        best.append((abs(e-129),a,b,e))
best.sort(); print(best[:3])
_,a,b,e=best[1]
r=two(today,a,b,today[a]['land'],today[b]['land'])
D.rider_view(today,r,1,back=330,look=today[b]['land'],repaint=False).save(O+'cut-raw.png')
e,a,b=max((x[3],x[1],x[2]) for x in best); print(e,a,b)
r=two(today,a,b,0,0)
D.rider_view(today,r,1,back=330,look=8,repaint=False).save(O+'cut-worst.png')
# purpose-made, same look both sides; and a look change
r=two(made,12,6,9,9); D.rider_view(made,r,1,back=420).save(O+'made-same.png')
# B: one land three times deeper: the same chunk, three looks
for n,l in enumerate((5,7,9)):
    r=two(made,9,8,l,l,1,1); D.rider_view(made,r,1,back=250).save(O+f'b-{n}.png')


def centred(lib,a,b,la,lb):
    c=lib[a]; h=0.0
    p={"i":0,"shape":a,"hand":1,"look":la,"layer":0,"s":0,"at":-c['exit'],"h":-0.0,"boss":False}
    B=D.ch.basis(-c['turn']); p["h"]=-c['turn']; p["at"]=-(c['exit']@B)
    q={"i":0,"shape":b,"hand":1,"look":lb,"layer":0,"s":0,"at":np.zeros(3),"h":0.0,"boss":False}
    return [p,q]
# the same joint with its own boxes (chunks.joint), in the colour of the floor ahead
jP,jA,jS,jC,jK=ch.joint(D.GROUND[made[6]['land']])
# (in slices: the plan paints a whole box by its highest corner)
# (and the sill 12 studs up, as the plan would paint the 64-stud floor tiles over it: it lies 0.2 over the highest of them)
jP[1,1]+=12
cut=lambda k: max(1,int(jS[k,2]/8))
jP,jA,jS,jC,jK=[np.array(v) for v in zip(*[(jP[k]+jA[k][2]*jS[k,2]*((i+.5)/cut(k)-.5),jA[k],jS[k]/np.array([1,1,cut(k)]),jC[k],jK[k]) for k in range(len(jP)) for i in range(cut(k))])]
fixed=list(made); f=dict(made[6]); n=len(jP)
for key,v in (('P',jP),('A',jA),('S',jS),('C',jC.astype(np.uint8)),('K',jK),('T',np.zeros(n)),('X',np.zeros(n,int)),('G',np.full(n,-1))):
    f[key]=np.concatenate([v,f[key]]) if f[key].ndim==v.ndim else f[key]
fixed[6]=f
for name,lib,a,b,l in (('jt-raw',today,30,20,9),('jt-raw2',today,37,21,9),('jt-made',made,12,6,9),('jt-fix',fixed,12,6,9)):
    r=centred(lib,a,b,l,3); im=D.plan(lib,r,1.0,pad=0,box=(np.array([-620,0,-460]),np.array([620,0,460])),label=False)
    im.save(O+f'{name}.png'); print(im.size)
