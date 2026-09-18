import sys, statistics as st
src=open(sys.argv[0].replace("naive","backtest")).read()
exec(src.split("MODELS = {")[0])
def level_at(hist,t):
    v=hist[0][1]
    for a,b in hist:
        if a<=t: v=b
    return v
def m_trailing(hours):
    def f(hist,p,t):
        if t-hours*H<hist[0][0]: return None
        r=(level_at(hist,t-hours*H)-p)/hours
        if r<=0: return None
        return lambda q:(p-q)/r
    return f
def m_fixed(perday):
    return lambda hist,p,t:(lambda q:(p-q)/(perday/24))
MODELS={
 "current (least squares, all history)": m_current,
 "naive: drop over the last 24h": m_trailing(24),
 "naive: drop over the last 48h": m_trailing(48),
 "naive: drop over the last 72h": m_trailing(72),
 "naive: total drop / total time": m_endpoint,
 "fixed 8%/day (hindsight, Tuesday's pace)": m_fixed(8.0),
 "fixed 7.4%/day (hindsight, whole-run pace)": m_fixed(7.4),
}
pts=[(s["at"],s["percent"]) for seg in d["segments"]["bc-89-a7-e3-b9-51"] for s in seg]
pk=max(range(len(pts)),key=lambda i:pts[i][1]); reach={}
for a,b in pts[pk:]: reach.setdefault(b,a)
res={m:[] for m in MODELS}; none={m:0 for m in MODELS}
t=pts[0][0]+24*H
while t<pts[-1][0]:
    hist=[x for x in pts if x[0]<=t]; p=hist[-1][1]
    for m,fn in MODELS.items():
        f=fn(hist,p,t)
        if f is None: none[m]+=1; continue
        for q,tq in reach.items():
            if q<p and tq>t: res[m].append(((tq-t)/H,f(q)-(tq-t)/H))
    t+=H
print(f"{'model':44s} {'n':>4s} {'mean err':>9s} {'bias':>8s} {'worst':>7s}  no-answer hours")
for m,r in res.items():
    print(f"{m:44s} {len(r):4d} {st.mean(abs(e) for _,e in r):8.1f}h {st.mean(e for _,e in r):+7.1f}h {max(abs(e) for _,e in r):6.1f}h  {none[m]}")

print("\nyour example — standing at Tue 22:20 with 18%, when does it reach 7%?  (actual: Fri 04:05, 53.8h later)")
t=[a for a,b in pts if b==18][0]; hist=[x for x in pts if x[0]<=t]
for m,fn in MODELS.items():
    f=fn(hist,18,t)
    if f: print(f"   {m:44s} {f(7):5.1f}h  -> {local(t+f(7)*H).strftime('%a %H:%M')}")

print("\nrate each model believed, day by day at 22:00 (%/day):")
import datetime
print(f"   {'':10s}"+"".join(f"{k[:22]:>24s}" for k in list(MODELS)[:4]))
for day in (14,15,16,17):
    t=(datetime.datetime(2026,9,day,22,0).astimezone()-EPOCH).total_seconds(); hist=[x for x in pts if x[0]<=t]; p=hist[-1][1]
    row=[]
    for m,fn in list(MODELS.items())[:4]:
        f=fn(hist,p,t); row.append(f"{24/f(p-1):24.1f}" if f else f"{'—':>24s}")
    print(f"   Sep {day} 22h"+"".join(row))
