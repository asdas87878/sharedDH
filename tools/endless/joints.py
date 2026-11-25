"""How well chunk ends meet IN THE LANE (what is missing beside it is skipped here: see holes.py): python tools/endless/joints.py <chunks.pkl>"""
import math
import pickle
import sys

import numpy as np

import chunks as ch

pc, tc = pickle.load(open(sys.argv[1], "rb"))
us=np.arange(-420,421,6.0)
def all_(cs):
    out=[]
    for c in cs: out+= [c,ch.flip(c)]
    return out
def pairs(cs,label):
    cs=all_(cs)
    E=[ch.profile(c,True,us) for c in cs]
    I=[ch.profile(c,False,us) for c in cs]
    # 24 studs of lane between two profiles: take the slope out
    E=[e-12*math.tan(math.radians(c['slope1'])) for e,c in zip(E,cs)]
    I=[i+12*math.tan(math.radians(c['slope0'])) for i,c in zip(I,cs)]
    n=len(cs); edge=np.zeros((n,n)); lanefl=np.zeros((n,n)); wall=np.zeros((n,n)); ok=np.zeros((n,n),bool)
    for a in range(n):
        for b in range(n):
            if cs[a]['name'].rstrip('m')==cs[b]['name'].rstrip('m'): ok[a,b]=False; edge[a,b]=np.nan; lanefl[a,b]=np.nan;wall[a,b]=np.nan; continue
            edge[a,b]=max(abs(cs[a]['w1'][0]-cs[b]['w0'][0]),abs(cs[a]['w1'][1]-cs[b]['w0'][1]))
            inn=np.abs(us)<min(cs[a]['w1'][0],cs[b]['w0'][0],cs[a]['w1'][1],cs[b]['w0'][1])-12
            d=np.abs(E[a]-I[b]); lanefl[a,b]=np.nanmax(d[inn]) if inn.any() else np.nan
            wall[a,b]=np.nanmean(d[~inn])
            ok[a,b]=edge[a,b]<=24
    print(label,'n',n,'edge step: median',np.nanmedian(edge),'p90',np.nanpercentile(edge,90),'max',np.nanmax(edge))
    print('  floor step in the lane: median',np.round(np.nanmedian(lanefl),2),'p90',np.round(np.nanpercentile(lanefl,90),2),'max',np.round(np.nanmax(lanefl),2))
    print('  wall/terrace height step (mean): median',np.round(np.nanmedian(wall),1),'p90',np.round(np.nanpercentile(wall,90),1))
    s=ok.sum(1); print('  partners within 24 studs: min',s.min(),'median',np.median(s),'max',s.max(),'of',n-2,'share',round(ok.sum()/(n*(n-2)),3), 'dead ends',(s==0).sum())
    print('  no floor (NaN) inside lane', sum(np.isnan(e[np.abs(us)<60]).any() for e in E), sum(np.isnan(e[np.abs(us)<60]).any() for e in I))
    return E,I
E1,I1=pairs(pc,'purpose-made 18x2')
E2,I2=pairs(tc,'today cut at necks 38x2')
