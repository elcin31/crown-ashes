class_name AIController
extends RefCounted
static func economic(s,commands):
	for r in s.data.realms:
		var id=int(r.id)
		if id==int(s.data.player) or s.provinces_of(id).is_empty():continue
		var own=s.provinces_of(id);var p=own[s.rng.randi_range(0,own.size()-1)]
		if r.resources.food<150 and r.resources.gold>70:commands.execute(id,"trade",{"resource":"food","buy":true,"amount":50})
		if r.stability<45 or int(r.rebel_warning)>0:commands.execute(id,"tax",{"level":0})
		elif r.resources.gold<70 and r.stability>65:commands.execute(id,"tax",{"level":2})
		else:commands.execute(id,"tax",{"level":1})
		var desired="farm" if r.resources.food<300 else "fort" if r.personality=="defensive" else "market"
		if r.resources.gold>150 and p.construction.is_empty():
			if int(p.buildings.get(desired,0))>=2:desired="sawmill" if int(s.data.day)%60==0 else "barracks"
			commands.execute(id,"build",{"province":int(p.id),"kind":desired})
		var enemy=false
		for w in s.data.wars:
			if int(w.a)==id or int(w.b)==id:enemy=true
		var strength=ArmySystem.strength(s,id)
		if r.resources.gold>110 and r.resources.food>90 and r.resources.manpower>=40 and (strength<340*own.size() or enemy):
			var kind="spearman" if int(s.data.day)%60==0 else "infantry" if int(s.data.difficulty)>=1 else "militia"
			commands.execute(id,"recruit",{"province":int(r.capital),"unit":kind})
		for slot in ["marshal","chancellor","treasurer","spymaster","steward"]:
			if r.council.has(slot):continue
			for c in s.data.characters:
				if c.alive and int(c.realm)==id and c.age>=16 and int(c.id)!=int(r.ruler) and not c.id in r.council.values():commands.execute(id,"appoint",{"slot":slot,"character":int(c.id)});break
static func military(s,commands):
	for r in s.data.realms:
		var id=int(r.id)
		if id==int(s.data.player) or s.provinces_of(id).is_empty():continue
		for w in s.data.wars.duplicate():
			if int(w.a)!=id and int(w.b)!=id:continue
			var enemy=int(w.b) if int(w.a)==id else int(w.a);var score=float(w.score)*(1 if int(w.a)==id else -1)
			if score>=40 or int(s.data.day)-int(w.start)>240:
				var terms="independence" if w.reason=="independence" and int(w.a)==id and score>=20 else "throne" if w.reason=="throne" and score>=55 else "land" if score>=20 else "white"
				var result=commands.execute(id,"peace",{"target":enemy,"terms":terms})
				if not result.ok and terms=="land":commands.execute(id,"peace",{"target":enemy,"terms":"gold"})
				continue
			for a in s.data.armies.duplicate():
				if int(a.realm)!=id or not a.route.is_empty() or a.order=="siege" or a.morale<30:continue
				if int(s.data.difficulty)>=1:commands.execute(id,"merge",{"army":int(a.id)})
				var target=-1;var best=-9999.0
				for p in s.data.provinces:
					if int(p.owner)!=enemy and not (int(p.owner)==id and int(p.occupation)==enemy):continue
					if int(p.occupation)==id:continue
					var route=ProvinceSystem.path(s,id,int(a.province),int(p.id))
					if route.is_empty():continue
					var defense=0.0
					for other in s.data.armies:
						if int(other.realm)==enemy and int(other.province)==int(p.id):defense+=ArmySystem.size(other)
					if int(s.data.difficulty)>=1 and defense>ArmySystem.size(a)*1.25:continue
					var value=160-route.size()*20-float(p.fort)*12-defense*0.15
					if int(p.owner)==id:value+=90
					if int(p.id)==int(s.data.realms[enemy].capital):value+=20
					if value>best:best=value;target=int(p.id)
				if target>=0:commands.execute(id,"move",{"army":int(a.id),"province":target})
static func diplomatic(s,commands):
	for r in s.data.realms:
		var id=int(r.id)
		if id==int(s.data.player) or s.provinces_of(id).is_empty():continue
		var neighbors=ProvinceSystem.neighbors(s,id)
		if neighbors.is_empty():continue
		var target=int(neighbors[s.rng.randi_range(0,neighbors.size()-1)])
		var rel=s.relation(id,target);var ruler=s.data.characters[int(r.ruler)]
		if r.personality=="diplomat" and r.resources.gold>75:
			if rel.value>=25 and not rel.alliance:commands.execute(id,"diplomacy",{"target":target,"action":"alliance"})
			elif rel.value<35:commands.execute(id,"diplomacy",{"target":target,"action":"improve"})
		if int(s.data.day)<int(s.balance.starting_grace_days):continue
		var wars=0
		for w in s.data.wars:
			if int(w.a)==id or int(w.b)==id:wars+=1
		if wars>0 or r.resources.gold<110 or r.resources.food<180 or r.stability<50:continue
		if not r.personality in ["expansionist","opportunist"] and not "Амбициозный" in ruler.traits:continue
		if "Осторожный" in ruler.traits and s.rng.randf()<0.65:continue
		if s.sovereign(id)==s.sovereign(target):continue
		var own=ArmySystem.strength(s,id);var foe=ArmySystem.strength(s,target)
		var threshold=[1.8,1.35,1.15][int(s.data.difficulty)]
		if own>maxf(180,foe)*threshold and s.rng.randf()<0.23:commands.execute(id,"war",{"target":target,"reason":"claim"})
