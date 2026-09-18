import json, sys, datetime, statistics as st
sys.argv=[sys.argv[0], sys.argv[1]]
exec(open(sys.argv[0].replace("analysis2","backtest")).read().split("MODELS = {")[0])
pts=[(s["at"],s["percent"]) for seg in d["segments"]["bc-89-a7-e3-b9-51"] for s in seg]
now=(datetime.datetime.now(datetime.timezone.utc)-EPOCH).total_seconds()

print("== A. mouse: percent used per calendar day (drops smeared over their interval)")
days={}
for (a,pa),(b,pb) in zip(pts,pts[1:]):
    x=a
    while x<b:
        dt=min(300,b-x); k=local(x).strftime("%a %m-%d"); days[k]=days.get(k,0)+(pa-pb)/(b-a)*dt; x+=dt
for k,v in days.items(): print(f"   {k}  {v:5.1f}%  {'#'*int(v*3)}")

print("\n== B. mouse: gaps between one-percent drops (hours), sorted")
gaps=sorted((b-a)/H for (a,pa),(b,pb) in zip(pts,pts[1:]) if pb==pa-1)
print("   "+" ".join(f"{g:.1f}" for g in gaps))
fast=[g for g in gaps if g<=1.5]
print(f"   {len(fast)} of {len(gaps)} gaps are under 1.5h; median of those {st.median(fast):.2f}h per 1%  -> in-use rate about {1/st.median(fast):.1f} %/hour")
print(f"   at that rate, 7% is about {7*st.median(fast):.1f} hours of actual use")

print("\n== C. your complaint window: where each model puts 'empty' as the idle morning passes")
cur=m_current; pro=m_profile(4,1.0)
print(f"   {'at':14s} {'lvl':>4s} | {'current: hrs / empty at':28s} | {'time-of-day: hrs / empty at':28s}")
marks=[pts[-2][0], pts[-1][0]]+[pts[-1][0]+h*H for h in (2,4,6)]+[now]
for t in marks:
    hist=[x for x in pts if x[0]<=t]; p=hist[-1][1]
    row=[]
    for fn in (cur,pro):
        f=fn(hist,p,t); h=f(0); row.append(f"{h:5.1f}h  {local(t+h*H).strftime('%a %H:%M')}")
    print(f"   {local(t).strftime('%a %H:%M'):14s} {p:3d}% | {row[0]:28s} | {row[1]:28s}")

print("\n== D. how wide an honest range would have to be (current model, all hourly checks)")
reach={}
pk=max(range(len(pts)),key=lambda i:pts[i][1])
for a,b in pts[pk:]: reach.setdefault(b,a)
ratios=[]
t=pts[0][0]+24*H
while t<pts[-1][0]:
    hist=[x for x in pts if x[0]<=t]; p=hist[-1][1]; f=m_current(hist,p,t)
    tq=reach[7]
    if f and p>7 and tq-t>6*H: ratios.append(((tq-t)/H)/f(7))
    t+=H
ratios.sort(); n=len(ratios)
print(f"   actual time / predicted time: min {ratios[0]:.2f}  10th pct {ratios[n//10]:.2f}  median {ratios[n//2]:.2f}  90th pct {ratios[9*n//10]:.2f}  max {ratios[-1]:.2f}")
