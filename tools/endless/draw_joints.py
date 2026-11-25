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
for name,lib,a,b,l in (('jt-raw',today,30,20,9),('jt-raw2',today,37,21,9),('jt-made',made,12,6,9)):
    r=centred(lib,a,b,l,3); im=D.plan(lib,r,1.0,pad=0,box=(np.array([-620,0,-460]),np.array([620,0,460])),label=False)
    im.save(O+f'{name}.png'); print(im.size)
