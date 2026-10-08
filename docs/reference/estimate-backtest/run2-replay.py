import json, datetime, statistics as st, sys
EPOCH=datetime.datetime(2001,1,1,tzinfo=datetime.timezone.utc); H=3600.0
d=json.load(open(sys.argv[1]))
segs=[[(s["at"],s["percent"]) for s in seg] for seg in d["segments"]["bc-89-a7-e3-b9-51"] if seg]
loc=lambda ts:(EPOCH+datetime.timedelta(seconds=ts)).astimezone()
s1,s2=segs[0],segs[1]
NOW=(datetime.datetime.now(datetime.timezone.utc)-EPOCH).total_seconds()
print(f"run 2: {len(s2)} readings, {loc(s2[0][0]):%a %m-%d %H:%M} {s2[0][1]}% -> {loc(s2[-1][0]):%a %m-%d %H:%M} {s2[-1][1]}%, {(s2[-1][0]-s2[0][0])/H/24:.1f} days")
# shipped clock model: pooled LS across segments, current reading at now
def fit(seglist):
    cov=var=0;
    for seg in seglist:
        if len(seg)<2: continue
        o=seg[0][0]; hs=[(a-o)/H for a,_ in seg]; ls=[b for _,b in seg]
        mh=sum(hs)/len(hs); ml=sum(ls)/len(ls)
        for h,l in zip(hs,ls): cov+=(h-mh)*(l-ml); var+=(h-mh)**2
    s=cov/var; return -s if s<0 else None
def usehrs(seglist):
    steps=[]
    for seg in seglist:
        for (a,pa),(b,pb) in zip(seg,seg[1:]):
            dr=pa-pb
            if dr>=1 and (b-a)/dr<=1.5*H: steps+= [(b-a)/dr/H]*dr
    return st.median(steps) if len(steps)>=5 else None
# A. per-day drain
print("\n== A. percent used per calendar day")
days={}
for (a,pa),(b,pb) in zip(s2,s2[1:]):
    x=a
    while x<b:
        dt=min(300,b-x); k=loc(x).strftime("%a %m-%d"); days[k]=days.get(k,0)+(pa-pb)/(b-a)*dt; x+=dt
for k,v in days.items(): print(f"   {k} {v:5.1f}% {'#'*int(v*2)}")
# B. per 10% band: wall-clock %/day and in-use h per 1%
print("\n== B. by level band: calendar rate and in-use rate")
peak=max(range(len(s2)),key=lambda i:s2[i][1]); r=s2[peak:]
reach={}
for a,b in r: reach.setdefault(b,a)
for hi in range(100,10,-10):
    lo=max(hi-10,11)
    if hi in reach and lo in reach:
        days_=(reach[lo]-reach[hi])/H/24
        g=[(b-a)/H for (a,pa),(b,pb) in zip(r,r[1:]) if pb==pa-1 and lo<pb<=hi and (b-a)<=1.5*H]
        allg=[(b-a)/H for (a,pa),(b,pb) in zip(r,r[1:]) if pb==pa-1 and lo<pb<=hi]
        print(f"   {hi:3d}->{lo:2d}%: {days_:4.1f} days = {(hi-lo)/days_:4.1f}%/day | in-use steps {len(g):2d}/{len(allg):2d}, median {st.median(g) if g else float('nan'):.2f} h per 1%")
# first-run comparison
g1=[(b-a)/H for (a,pa),(b,pb) in zip(s1,s1[1:]) if pb==pa-1 and (b-a)<=1.5*H and pb>10]
g1lo=[(b-a)/H for (a,pa),(b,pb) in zip(s1,s1[1:]) if pb==pa-1 and (b-a)<=1.5*H and pb<=10]
print(f"   run 1, 41->11%: in-use median {st.median(g1):.2f} h per 1%;  below 10%: {st.median(g1lo):.2f} ({len(g1lo)} steps)")
# C. replay shipped models hourly through run 2; score clock prediction of reaching each later level
print("\n== C. replay: what the app said vs what happened")
errs=[]; arr=[]; rows=[]
t=s2[0][0]+24*H; target=s2[-1][1]
while t<=s2[-1][0]:
    h2=[x for x in s2 if x[0]<=t]; p=h2[-1][1]
    cur=h2+([(t,p)] if t>h2[-1][0] else [])
    rate=fit([s1,cur]); u=usehrs([s1,h2])
    if rate:
        for q,tq in reach.items():
            if q<p and tq>t: errs.append(((tq-t)/H,(p-q)/rate-(tq-t)/H))
        if p>target: arr.append((t,t+(p-target)/rate*H))
    rows.append((t,p,rate,u))
    t+=H
mae=st.mean(abs(e) for _,e in errs); bias=st.mean(e for _,e in errs)
rel=[e/h for h,e in errs if h>24]
print(f"   clock model, all hourly checks: mean abs err {mae:.1f}h, bias {bias:+.1f}h (+ = said later than happened); median relative err {st.median(abs(x) for x in rel)*100:.0f}% for horizons >1 day")
for lo,hi in [(0,24),(24,72),(72,168),(168,999)]:
    v=[e for h,e in errs if lo<=h<hi]
    if v: print(f"     horizon {lo:3d}-{hi:3d}h: n={len(v):4d} mean abs {st.mean(map(abs,v)):5.1f}h  bias {st.mean(v):+6.1f}h")
print(f"   predicted arrival at {target}% (actual {loc(reach[target]):%a %m-%d %H:%M}):")
for t,a in arr[::48]: print(f"     at {loc(t):%a %m-%d %H:%M}: {loc(a):%a %m-%d %H:%M}  ({(a-reach[target])/H:+.0f}h)")
# jumps: max hour-to-hour change in predicted empty moment
emp=[(t,t+p/rate*H) for t,p,rate,u in rows if rate]
jumps=[abs(b2-b1)/H for (t1,b1),(t2,b2) in zip(emp,emp[1:])]
print(f"   'empty at' moment, hour to hour: median move {st.median(jumps):.2f}h, 95th pct {sorted(jumps)[int(.95*len(jumps))]:.1f}h, max {max(jumps):.1f}h")
print("   rate the app used, daily:")
for t,p,rate,u in rows[::24]: print(f"     {loc(t):%a %m-%d %H:%M} {p:3d}%  clock {rate*24 if rate else 0:4.1f}%/day -> {p/rate/24 if rate else 0:4.1f} days | use {u or 0:.2f} h/1% -> {p*(u or 0):5.1f} h of use")
