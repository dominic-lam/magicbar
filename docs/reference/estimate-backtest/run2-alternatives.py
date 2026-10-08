import json, datetime, statistics as st, sys
EPOCH=datetime.datetime(2001,1,1,tzinfo=datetime.timezone.utc); H=3600.0
d=json.load(open(sys.argv[1])); loc=lambda ts:(EPOCH+datetime.timedelta(seconds=ts)).astimezone()
segs=[[(s["at"],s["percent"]) for s in seg] for seg in d["segments"]["bc-89-a7-e3-b9-51"] if seg]
s1,s2=segs[0],segs[1]
print("100->88 readings:"); 
for a,b in s2[:14]: print(f"  {loc(a):%a %m-%d %H:%M} {b}%")
def slope(seglist):
    cov=var=0
    for seg in seglist:
        if len(seg)<2: continue
        o=seg[0][0]; hs=[(a-o)/H for a,_ in seg]; ls=[b for _,b in seg]
        mh=sum(hs)/len(hs); ml=sum(ls)/len(ls)
        for h,l in zip(hs,ls): cov+=(h-mh)*(l-ml); var+=(h-mh)**2
    return -cov/var if var and cov<0 else None
reach={}
for a,b in s2: reach.setdefault(b,a)
models={
 "shipped (both runs pooled)": lambda cur,t: slope([s1,cur]),
 "this run only": lambda cur,t: slope([cur]),
 "this run only, after 90%": lambda cur,t: slope([[x for x in cur if x[1]<=90]]) if any(x[1]<=90 for x in cur) and cur[-1][0]-min(x[0] for x in cur if x[1]<=90)>24*H else None,
 "last 7 days (both runs)": lambda cur,t: slope([[x for x in s1 if x[0]>t-7*24*H],[x for x in cur if x[0]>t-7*24*H]]),
}
print(f"\n{'model':30s} {'mean abs err':>12s} {'bias':>7s}   days shown, one reading per day from Sep 19")
for name,fn in models.items():
    errs=[]; shown=[]; t=s2[0][0]+24*H
    while t<=s2[-1][0]:
        h2=[x for x in s2 if x[0]<=t]; p=h2[-1][1]; cur=h2+([(t,p)] if t>h2[-1][0] else [])
        r=fn(cur,t)
        if r:
            for q,tq in reach.items():
                if q<p and tq>t and q>=11: errs.append((p-q)/r-(tq-t)/H)
        if int((t-s2[0][0])/H)%24==0: shown.append(f"{p/r/24:.0f}" if r else "-")
        t+=H
    print(f"{name:30s} {st.mean(map(abs,errs)):10.1f}h {st.mean(errs):+6.1f}h   {' '.join(shown)}")
print("truth: days from each daily check to 11% ->", ' '.join(f"{(reach[11]-(s2[0][0]+k*24*H))/H/24:.0f}" for k in range(1,18)))
