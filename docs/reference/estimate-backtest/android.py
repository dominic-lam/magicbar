import sys, statistics as st, math
exec(open(sys.argv[0].replace("android","backtest")).read().split("MODELS = {")[0])

def steps(hist):
    """(end_time, duration_h) for each 1% drop; a multi-point drop is split evenly; rises are skipped"""
    out=[]
    for (a,pa),(b,pb) in zip(hist,hist[1:]):
        n=pa-pb
        if n>=1:
            for i in range(n): out.append((b,(b-a)/H/n))
    return out

def m_steps(last=None, halflife_days=None, open_step=False):
    def f(hist,p,t):
        s=steps(hist)
        if open_step and s:
            idle=(t-hist[-1][0])/H
            if idle>0: s=s+[(t,idle)] if idle>st.mean(x for _,x in s) else s   # a step already longer than average counts
        if last: s=s[-last:]
        if len(s)<3: return None
        if halflife_days:
            w=[0.5**((t-e)/H/24/halflife_days) for e,_ in s]
        else: w=[1.0]*len(s)
        per=sum(wi*x for wi,(_,x) in zip(w,s))/sum(w)
        return lambda q:(p-q)*per
    return f

MODELS={
 "current (least squares, all history)": m_current,
 "android: mean of all steps": m_steps(),
 "android: mean of last 10 steps": m_steps(last=10),
 "android: mean of last 20 steps": m_steps(last=20),
 "android + recency, half-life 1 day": m_steps(halflife_days=1),
 "android + recency, half-life 2 days": m_steps(halflife_days=2),
 "android + recency, half-life 3 days": m_steps(halflife_days=3),
 "  same (2 days) + counts the open step": m_steps(halflife_days=2,open_step=True),
 "  all steps + counts the open step": m_steps(open_step=True),
}
for id,name in (("bc-89-a7-e3-b9-51","Magic Mouse"),("c4-14-11-04-4d-d8","Magic Keyboard")):
    pts=[(s["at"],s["percent"]) for seg in d["segments"][id] for s in seg]
    pk=max(range(len(pts)),key=lambda i:pts[i][1]); reach={}
    for a,b in pts[pk:]: reach.setdefault(b,a)
    res={m:[] for m in MODELS}; jumps={m:[] for m in MODELS}; prev={}
    t=pts[0][0]+24*H
    while t<pts[-1][0]:
        hist=[x for x in pts if x[0]<=t]; p=hist[-1][1]
        for m,fn in MODELS.items():
            f=fn(hist,p,t)
            if f is None: continue
            for q,tq in reach.items():
                if q<p and tq>t: res[m].append(((tq-t)/H,f(q)-(tq-t)/H))
            left=f(0)
            if m in prev: jumps[m].append(abs((left-prev[m])+1))   # a perfect countdown loses exactly 1h per hour
            prev[m]=left
        t+=H
    print(f"\n===== {name}: {len(pts)} readings, {pts[pk][1]}% -> {pts[-1][1]}%")
    print(f"{'model':42s} {'n':>4s} {'mean err':>9s} {'bias':>8s} {'worst':>7s} | hour-to-hour jump: typical / biggest")
    for m,r in res.items():
        if not r: continue
        j=jumps[m]
        print(f"{m:42s} {len(r):4d} {st.mean(abs(e) for _,e in r):8.1f}h {st.mean(e for _,e in r):+7.1f}h {max(abs(e) for _,e in r):6.1f}h | {st.median(j):5.1f}h / {max(j):5.1f}h")

# in-use figure: is "time per 1% while in use" predictable one step ahead?
pts=[(s["at"],s["percent"]) for seg in d["segments"]["bc-89-a7-e3-b9-51"] for s in seg]
s=[x for _,x in steps(pts)]
print("\n===== hours-of-use figure (mouse): predict each in-use step from the ones before it")
for cut in (1.5,2.0):
    use=[x for x in s if x<=cut]; err=[]; 
    for i in range(3,len(use)):
        pred=st.median(use[:i]); err.append(abs(use[i]-pred)/use[i])
    print(f"   in-use = steps <= {cut}h: {len(use)} of {len(s)} steps, median {st.median(use)*60:.0f} min per 1%, mean {st.mean(use)*60:.0f} min; one-step-ahead median error {st.median(err)*100:.0f}%")
# session test: predicted vs actual duration of each unbroken in-use stretch
print("   unbroken in-use stretches (consecutive steps <= 1.5h), predicted from the median known before each stretch:")
i=0; seen=[]
while i<len(s):
    if s[i]<=1.5:
        j=i
        while j<len(s) and s[j]<=1.5: j+=1
        if j-i>=3 and len(seen)>=3:
            pred=st.median(seen)*(j-i); act=sum(s[i:j])
            print(f"      {j-i}% dropped: predicted {pred:4.1f}h of use, actual {act:4.1f}h  ({(pred/act-1)*100:+.0f}%)")
        seen+=s[i:j]; i=j
    else: i+=1
