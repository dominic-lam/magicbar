import json, datetime, statistics as st, sys
EPOCH = datetime.datetime(2001,1,1,tzinfo=datetime.timezone.utc)
d = json.load(open(sys.argv[1]))
H = 3600.0
def local(ts): return (EPOCH + datetime.timedelta(seconds=ts)).astimezone()
def hod(ts):
    t = local(ts); return t.hour + t.minute/60 + t.second/3600

# ---------- models: each takes history (list of (ts,pct)) strictly before/at t, current pct p, time t
# and returns a function hours_to(q) -> predicted hours until level q, or None
def m_current(hist, p, t):
    pts = hist + ([(t,p)] if t > hist[-1][0] else [])
    xs=[(a-pts[0][0])/H for a,_ in pts]; ys=[b for _,b in pts]
    n=len(xs); mx=sum(xs)/n; my=sum(ys)/n
    var=sum((x-mx)**2 for x in xs)
    if var==0: return None
    s=sum((x-mx)*(y-my) for x,y in zip(xs,ys))/var
    if s>=0: return None
    return lambda q: (p-q)/(-s)

def m_window(hours):
    def f(hist,p,t):
        h=[(a,b) for a,b in hist if a>=t-hours*H]
        if len(h)<2: return None
        return m_current(h,p,t)
    return f

def m_endpoint(hist,p,t):
    top=max(b for _,b in hist[:4]); t0=[a for a,b in hist if b==top][0]
    if t<=t0 or top<=p: return None
    r=(top-p)/((t-t0)/H)
    return lambda q:(p-q)/r

def profile(hist,p,t,bucket,k):
    """drop per hour for each time-of-day bucket; each observed drop smeared evenly over its interval"""
    nb=int(24/bucket); drop=[0.0]*nb; expo=[0.0]*nb
    pts = hist + [(t,p)]
    step=300.0
    for (a,pa),(b,pb) in zip(pts,pts[1:]):
        if b<=a: continue
        per_sec=(pa-pb)/(b-a)
        x=a
        while x<b:
            dt=min(step,b-x); i=int(hod(x)/bucket)%nb
            drop[i]+=per_sec*dt; expo[i]+=dt/H
            x+=dt
    total=sum(drop); hours=sum(expo)
    if hours<=0 or total<=0: return None
    mean=total/hours
    return [max(0.0,(drop[i]+k*mean)/(expo[i]+k)) for i in range(nb)]

def m_profile(bucket,k):
    def f(hist,p,t):
        r=profile(hist,p,t,bucket,k)
        if r is None: return None
        nb=len(r)
        def hours_to(q):
            need=p-q; x=t; step=600.0; lim=t+60*24*H
            while need>0 and x<lim:
                need-=r[int(hod(x)/bucket)%nb]*step/H; x+=step
            return (x-t)/H
        return hours_to
    return f

MODELS = {
 "current (one line, all history)": m_current,
 "line, last 48h only": m_window(48),
 "line, last 72h only": m_window(72),
 "plain average (total drop / total time)": m_endpoint,
 "time-of-day profile, 1h buckets": m_profile(1,1.0),
 "time-of-day profile, 2h buckets": m_profile(2,1.0),
 "time-of-day profile, 3h buckets": m_profile(3,1.0),
 "time-of-day profile, 4h buckets": m_profile(4,1.0),
}

def run(name, samples):
    pts=[(s["at"],s["percent"]) for s in samples]
    t0=pts[0][0]; tend=pts[-1][0]
    # actual first time each level was reached (after the early post-charge creep)
    peak_i=max(range(len(pts)),key=lambda i:pts[i][1])
    reach={}
    for a,b in pts[peak_i:]:
        reach.setdefault(b,a)
    print(f"\n===== {name}: {len(pts)} readings, {(tend-t0)/H/24:.1f} days, {pts[peak_i][1]}% -> {pts[-1][1]}%")
    res={m:[] for m in MODELS}; drift={m:[] for m in MODELS}
    final=pts[-1][1]
    t=t0+24*H
    while t<tend:
        hist=[x for x in pts if x[0]<=t]; p=hist[-1][1]
        for m,fn in MODELS.items():
            f=fn(hist,p,t)
            if f is None: continue
            for q,tq in reach.items():
                if q<p and tq>t:
                    res[m].append(((tq-t)/H, f(q)-(tq-t)/H))
            if final<p: drift[m].append(t+f(final)*H)   # predicted moment of reaching the final level
        t+=H
    print(f"{'model':42s} {'n':>5s} {'mean abs err':>13s} {'bias':>7s} | {'<12h':>6s} {'12-36h':>7s} {'>36h':>6s} | predicted arrival at {final}%: spread")
    for m,r in res.items():
        if not r: continue
        mae=st.mean(abs(e) for _,e in r); bias=st.mean(e for _,e in r)
        def band(lo,hi):
            v=[abs(e) for h,e in r if lo<=h<hi]; return f"{st.mean(v):5.1f}h" if v else "   —"
        dr=drift[m]; sd=st.pstdev(dr)/H if len(dr)>1 else 0
        lo=local(min(dr)).strftime("%a %H:%M"); hi=local(max(dr)).strftime("%a %H:%M")
        print(f"{m:42s} {len(r):5d} {mae:11.1f}h {bias:+6.1f}h | {band(0,12):>6s} {band(12,36):>7s} {band(36,999):>6s} | ±{sd:4.1f}h  ({lo} … {hi})")
    print(f"   actual arrival at {final}%: {local(reach[final]).strftime('%a %H:%M')}")

names={"bc-89-a7-e3-b9-51":"Magic Mouse","c4-14-11-04-4d-d8":"Magic Keyboard"}
for id,segs in d["segments"].items():
    run(names.get(id,id),[s for seg in segs for s in seg])

# show the learned profile from all mouse data
pts=[(s["at"],s["percent"]) for seg in d["segments"]["bc-89-a7-e3-b9-51"] for s in seg]
r=profile(pts[:-1],pts[-1][1],pts[-1][0],2,1.0)
print("\nmouse drain by time of day (2h buckets, %/hour):")
for i,v in enumerate(r): print(f"  {i*2:02d}-{i*2+2:02d}h  {v:4.2f}  {'#'*int(v*40)}")
