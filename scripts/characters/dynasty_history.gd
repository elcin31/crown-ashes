class_name DynastyHistory
extends RefCounted
static func ensure(s):
	for d in s.data.dynasties:
		if not d.has("prestige"):
			d.prestige=float(s.data.get("narrative",{}).get("variables",{}).get("dynasty_prestige",35)) if int(d.id)==int(s.data.get("narrative",{}).get("dynasty",-1)) else 35.0
			d.chronicle=[];d.reigns=[]
	for r in s.data.realms:
		var d=s.data.dynasties[int(r.dynasty_id)]
		if not d.reigns.any(func(x):return int(x.realm)==int(r.id) and int(x.ruler)==int(r.ruler) and int(x.end)<0):
			d.reigns.append({"realm":r.id,"ruler":r.ruler,"start":s.data.day,"end":-1,"reason":"Правит"})
static func entry(s,realm:int,text:String,prestige:float=0):
	var d=s.data.dynasties[int(s.data.realms[realm].dynasty_id)]
	d.prestige=clampf(float(d.prestige)+prestige,0,100)
	sync_prestige(s,d)
	d.chronicle.push_front({"day":s.data.day,"ruler":s.data.realms[realm].ruler,"text":text})
	if d.chronicle.size()>80:d.chronicle.resize(80)
static func succession(s,realm:int,previous:int):
	for d in s.data.dynasties:
		for reign in d.get("reigns",[]):
			if int(reign.realm)==realm and int(reign.ruler)==previous and int(reign.end)<0:reign.end=s.data.day;reign.reason="Смерть правителя" if not s.data.characters[previous].alive else "Утрата престола"
	ensure(s);entry(s,realm,"Законное наследование: "+s.data.characters[int(s.data.realms[realm].ruler)].name,3)
static func monthly(s):
	for r in s.data.realms:
		if s.provinces_of(int(r.id)).is_empty():continue
		var d=s.data.dynasties[int(r.dynasty_id)]
		d.prestige=clampf(float(d.prestige)+(.18 if float(r.stability)>=55 else -.12),0,100)
		var tomb=false
		for p in s.provinces_of(int(r.id)):
			if int(p.buildings.get("dynastic_tomb",0))>0 and d.members.any(func(cid):return not s.data.characters[int(cid)].alive):tomb=true
		if tomb:d.prestige=minf(100,d.prestige+.15)
		if float(d.prestige)>=70:r.legitimacy=minf(100,r.legitimacy+.15)
		sync_prestige(s,d)
		if int(s.data.day)%360==0 and s.provinces_of(int(r.id)).any(func(p):return int(p.buildings.get("command_academy",0))>0):
			var cid=int(r.council.get("marshal",-1))
			if cid>=0 and s.data.characters[cid].alive:s.data.characters[cid].martial=mini(18,int(s.data.characters[cid].martial)+1)
static func sync_prestige(s,d):
	if NarrativeSystem.active(s) and int(s.data.narrative.dynasty)==int(d.id):s.data.narrative.variables.dynasty_prestige=d.prestige
