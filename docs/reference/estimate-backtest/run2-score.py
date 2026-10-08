import json,sys,datetime,statistics as st
d=json.load(open(sys.argv[1])); H=3600.0
EPOCH=datetime.datetime(2001,1,1,tzinfo=datetime.timezone.utc); loc=lambda ts:(EPOCH+datetime.timedelta(seconds=ts)).astimezone()
M,K="bc-89-a7-e3-b9-51","c4-14-11-04-4d-d8"
P=lambda seg:[(x["at"],x["percent"]) for x in seg]
med=st.median
# ---------- 1. charge: replay chargeMinutesRemaining through charge 2, learned from charge 1 (+ charge 2 so far)
c1,c2=[P(r) for r in d["charges"][M]]
def charge_est(runs,p,now):
    by={};allv=[]
    for run in runs:
        for (a,pa),(b,pb) in zip(run,run[1:]):
            rise=pb-pa
            if rise<1: continue
            each=(b-a)/rise
            if each>20*60: continue
            for l in range(pa,pb): by.setdefault(l,[]).append(each/60)
            allv+=[each/60]*rise
    typ=med(allv); m=sum(med(by[l]) if l in by else typ for l in range(p,100))
    last=runs[-1][-1]
    if last[1]==p and now>last[0]: m-=min((now-last[0])/60, med(by[p]) if p in by else typ)
    return m
end=c2[-1][0]
print(f"== 1. charge 2: {loc(c2[0][0]):%H:%M} {c2[0][1]}% -> {loc(end):%H:%M} 100%, took {(end-c2[0][0])/60:.0f} min (charge 1 took {(c1[-1][0]-c1[0][0])/60:.0f} min)")
errs=[]
for i,(t,p) in enumerate(c2[:-1]):
    est=charge_est([c1,c2[:i+1]],p,t); act=(end-t)/60; errs.append(est-act)
    if p in (4,10,20,30,40,50,60,70,80,90,95,98,99): print(f"   at {loc(t):%H:%M} {p:3d}%: said {est:5.0f} min, took {act:5.0f}  ({est-act:+4.0f})")
print(f"   all {len(errs)} readings: mean abs err {st.mean(map(abs,errs)):.1f} min, worst {max(errs,key=abs):+.0f} min")
# ---------- 2. below 10%: shipped vs 'percents below 10 count half'
def slope(segs):
    cov=var=0
    for seg in segs:
        if len(seg)<2: continue
        o=seg[0][0]; hs=[(a-o)/H for a,_ in seg]; ls=[b for _,b in seg]; mh=sum(hs)/len(hs); ml=sum(ls)/len(ls)
        for h,l in zip(hs,ls): cov+=(h-mh)*(l-ml); var+=(h-mh)**2
    return -cov/var if var and cov<0 else None
def usehrs(segs):
    s=[]
    for seg in segs:
        for (a,pa),(b,pb) in zip(seg,seg[1:]):
            dr=pa-pb
            if dr>=1 and (b-a)/dr<=1.5*H: s+=[(b-a)/dr/H]*dr
    return med(s)
def cost(p,q,half):  # 'percent-units' between p and q, levels at/below 9 cost 0.5
    return sum((0.5 if (half and l<10) else 1) for l in range(q,p))
segs=[P(s) for s in d["segments"][M] if len(s)>1]
r1,r2=segs[0],segs[1]
print("\n== 2. the last 10%: predicted vs actual time to reach 4%")
for name,run,prior in (("run 1 (Sep 18)",r1,[]),("run 2 (today)",r2,[r1])):
    t4=[a for a,b in run if b==4][0]
    print(f"   {name}: reached 4% at {loc(t4):%a %H:%M}")
    for half in (False,True):
        ce=[];ue=[];rows=[]
        for i,(t,p) in enumerate(run):
            if not (5<=p<=12) or t>=t4: continue
            hist=prior+[run[:i+1]]; rate=slope(hist); u=usehrs(hist)
            act=(t4-t)/H
            cl=cost(p,4,half)/rate; us=cost(p,4,half)*u
            ce.append(cl-act); rows.append((p,cl,us,act))
        lab="half below 10%" if half else "shipped       "
        print(f"     {lab}: clock mean abs err {st.mean(map(abs,ce)):5.1f}h | per reading (level: clock / use / actual h): "+"  ".join(f"{p}%:{c:.0f}/{u:.1f}/{a:.1f}" for p,c,u,a in rows))
# ---------- 3. keyboard
kb=P(d["segments"][K][0]); end=kb[-1]
print(f"\n== 3. keyboard: {len(kb)} readings, {loc(kb[0][0]):%a %m-%d} {kb[0][1]}% -> {loc(end[0]):%a %m-%d %H:%M} {end[1]}%, {(end[0]-kb[0][0])/H/24:.1f} days, average {(kb[0][1]-end[1])/((end[0]-kb[0][0])/H/24):.2f}%/day")
reach={}
for a,b in kb: reach.setdefault(b,a)
t=kb[0][0]+24*H; errs=[]; shown=[]
while t<=end[0]:
    h=[x for x in kb if x[0]<=t]; p=h[-1][1]; cur=h+([(t,p)] if t>h[-1][0] else [])
    r=slope([cur])
    if r:
        for q,tq in reach.items():
            if q<p and tq>t: errs.append(((tq-t)/H,(p-q)/r-(tq-t)/H))
        if int((t-kb[0][0])/H)%(24*3)==0: shown.append((t,p,r,(t+(p-end[1])/r*H)))
    t+=H
print(f"   clock model: mean abs err {st.mean(abs(e) for _,e in errs)/24:.1f} days, bias {st.mean(e for _,e in errs)/24:+.1f} days (+ = said later than happened)")
print(f"   every 3 days: what it said, and when it put {end[1]}% (actual {loc(end[0]):%a %m-%d %H:%M}):")
for t,p,r,arr in shown: print(f"     {loc(t):%a %m-%d} {p:3d}%  {r*24:4.2f}%/day  'about {p/r/24:.0f} days left'  -> {end[1]}% on {loc(arr):%a %m-%d} ({(arr-end[0])/H/24:+.1f} d)")
days={}
for (a,pa),(b,pb) in zip(kb,kb[1:]):
    x=a
    while x<b:
        dt=min(300,b-x); k=loc(x).strftime("%m-%d"); days[k]=days.get(k,0)+(pa-pb)/(b-a)*dt; x+=dt
v=list(days.values())[1:-1]; print(f"   per-day drain: min {min(v):.1f}  median {med(v):.1f}  max {max(v):.1f} %/day")
gaps=[(b-a)/H for (a,pa),(b,pb) in zip(kb,kb[1:]) if pb==pa-1]
print(f"   hours per 1%: above 20% median {med([(b-a)/H for (a,pa),(b,pb) in zip(kb,kb[1:]) if pb==pa-1 and pb>20]):.1f}, 20% and below median {med([(b-a)/H for (a,pa),(b,pb) in zip(kb,kb[1:]) if pb==pa-1 and pb<=20]):.1f}")
