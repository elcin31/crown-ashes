class_name SiegeSystem
extends RefCounted
static func occupy(s,p:Dictionary,realm:int):
	if int(p.occupation)==realm:return
	p.occupation=realm;p.siege={};p.garrison=maxi(10,int(p.garrison)*0.3)
	var w=s.war_between(realm,int(p.owner))
	if not w.is_empty():w.score=clampf(w.score+(18 if int(w.a)==realm else -18),-100,100)
	s.log_message("%s: армия %s заняла провинцию. Для присоединения нужен мирный договор."%[p.name,s.realm_name(realm)])
static func daily(s):
	for p in s.data.provinces:
		var besieger={}
		for a in s.data.armies:
			if int(a.province)==int(p.id) and a.route.is_empty() and s.at_war(int(a.realm),int(p.owner)) and ArmySystem.size(a)>=25 and int(p.occupation)!=int(a.realm):besieger=a;break
		if besieger.is_empty():
			if not p.siege.is_empty():p.siege.progress=maxf(0,p.siege.progress-1.5)
			continue
		if int(p.fort)<=0:occupy(s,p,int(besieger.realm));continue
		var realm=int(besieger.realm)
		if p.siege.is_empty() or int(p.siege.realm)!=realm:p.siege={"realm":realm,"progress":0.0,"fort_health":100.0}
		var n=ArmySystem.size(besieger);var engines=int(besieger.units.get("siege",0));var supply=0.4+besieger.supply/160.0
		var progress=(1.0+float(n)/150.0+float(engines)/18.0)*supply/maxi(1,int(p.fort))
		if n<int(p.garrison):progress*=0.3
		p.siege.progress=minf(100,p.siege.progress+progress);p.siege.fort_health=maxf(0,100-p.siege.progress)
		if int(s.data.day)%7==0:ArmySystem.losses(besieger,0.012);p.garrison=maxi(8,int(p.garrison)-4)
		if p.siege.progress>=100:occupy(s,p,realm);besieger.order="idle"
