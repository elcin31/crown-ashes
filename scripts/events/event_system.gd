class_name EventSystem
extends RefCounted
static func matches(s,realm:int,condition:String)->bool:
	var r=s.data.realms[realm];var own=s.provinces_of(realm)
	if own.is_empty():return false
	var ruler=s.data.characters[int(r.ruler)];var month=int(s.calendar().m)
	match condition:
		"always":return true
		"ruler_alive":return ruler.alive
		"fertile":
			if int(ruler.spouse)<0:return false
			var spouse=s.data.characters[int(ruler.spouse)]
			return spouse.alive and spouse.age>=18 and spouse.age<=42 and ruler.age>=18 and spouse.children.size()<5
		"old_advisor":
			for cid in r.council.values():
				if s.data.characters[int(cid)].alive and s.data.characters[int(cid)].age>=60:return true
			return false
		"unrest_high":
			for p in own:
				if p.unrest>=55:return true
			return false
		"neighbor":return not ProvinceSystem.neighbors(s,realm).is_empty()
		"low_legitimacy":return r.legitimacy<65
		"low_loyalty":
			for c in s.data.characters:
				if c.alive and int(c.realm)==realm and c.loyalty<40:return true
			return false
		"market","mine","temple":
			for p in own:
				if int(p.buildings.get(condition,0))>0:return true
			return false
		"populous":
			for p in own:
				if int(p.population)>5000 and int(p.epidemic)==0:return true
			return false
		"recent_victory":return int(s.data.day)-int(s.data.last_victory)<80
		"low_morale":
			for a in s.data.armies:
				if int(a.realm)==realm and a.morale<45:return true
			return false
		"unmarried":return marriage_pair(s,realm).size()==2
		"summer":return month in [5,6,7]
		"winter":return month in [11,0,1]
		"spring":return month in [2,3,4]
		"rich":return r.resources.gold>=160
		"war":
			for w in s.data.wars:
				if int(w.a)==realm or int(w.b)==realm:return true
			return false
		"peace":return not matches(s,realm,"war")
		"stable":return r.stability>=60
	return false
static func schedule(s):
	if s.data.events.size()>=int(s.balance.max_event_queue):return
	var possible=[];var realm=int(s.data.player)
	for e in s.events:
		if int(s.data.day)-int(s.data.event_history.get(e.id,-999))<180:continue
		if matches(s,realm,e.condition):possible.append(e)
	if possible.is_empty():return
	var e=possible[s.rng.randi_range(0,possible.size()-1)]
	s.data.events.append({"event_id":e.id,"day":s.data.day,"realm":realm});s.data.event_history[e.id]=s.data.day
static func definition(s,entry:Dictionary)->Dictionary:
	if entry.has("narrative_id"):return NarrativeSystem.render(s,NarrativeSystem.event_by_id(str(entry.narrative_id)))
	if entry.has("special"):return entry
	for e in s.events:
		if e.id==entry.event_id:return e
	return {}
static func choose(s,index:int,choice:int)->Dictionary:
	if index<0 or index>=s.data.events.size():return s.result(false,"Событие больше недоступно.")
	var entry=s.data.events[index]
	if entry.has("narrative_id"):return NarrativeSystem.choose(s,index,choice)
	var e=definition(s,entry)
	if entry.has("special"):s.data.events.remove_at(index);return s.result(true,"Присяга принята.")
	if choice<0 or choice>=e.choices.size():return s.result(false,"Неизвестное решение.")
	apply(s,int(s.data.player),e.choices[choice].effects);s.data.events.remove_at(index)
	s.log_message(e.title+": "+e.choices[choice].label)
	return s.result(true,"Решение принято.")
static func marriage_pair(s,realm:int)->Array:
	for a in s.data.characters:
		if not a.alive or int(a.realm)!=realm or a.age<16 or int(a.spouse)>=0:continue
		for b in s.data.characters:
			if not b.alive or int(b.realm)==realm or b.age<16 or b.age>50 or int(b.spouse)>=0 or b.gender==a.gender:continue
			if int(b.dynasty)==int(a.dynasty) or s.at_war(realm,int(b.realm)) or int(s.relation(realm,int(b.realm)).value)<-10:continue
			return [int(a.id),int(b.id)]
	return []
static func apply(s,realm:int,effects:Dictionary):
	var r=s.data.realms[realm];var ruler=s.data.characters[int(r.ruler)];var owned=s.provinces_of(realm)
	for key in effects:
		var value=effects[key]
		if r.resources.has(key):
			r.resources[key]+=value
			if key!="gold" and float(r.resources[key])<0:r.resources[key]=0;r.stability=maxf(0,r.stability-3)
		elif key in ["stability","legitimacy"]:r[key]=clampf(r[key]+value,0,100)
		elif key=="health":ruler.health=clampf(ruler.health+value,0,100)
		elif key in ["unrest","development","population","epidemic"]:
			for p in owned:
				p[key]+=value
				if key in ["unrest","development"]:p[key]=clampf(p[key],0,100)
				if key=="population":p.population=maxi(500,int(p.population))
		elif key=="loyalty":
			for c in s.data.characters:
				if c.alive and int(c.realm)==realm:c.loyalty=clampf(c.loyalty+value,0,100)
		elif key in ["morale","army_losses"]:
			for a in s.data.armies:
				if int(a.realm)!=realm:continue
				if key=="morale":a.morale=clampf(a.morale+value,5,100)
				else:ArmySystem.losses(a,minf(0.25,float(value)/maxi(1,ArmySystem.size(a))))
		elif key in ["relation","claim"]:
			var neighbors=ProvinceSystem.neighbors(s,realm)
			if not neighbors.is_empty():
				var other=int(neighbors[0]);var rel=s.relation(realm,other)
				if key=="relation":rel.value=clampi(int(rel.value)+int(value),-100,100)
				elif not other in r.claims:r.claims.append(other)
		elif key=="birth" and int(ruler.spouse)>=0:DynastySystem.child(s,s.data.characters[int(ruler.spouse)],ruler)
		elif key=="advisor_death":
			for cid in r.council.values():
				if s.data.characters[int(cid)].alive and s.data.characters[int(cid)].age>=60:CharacterSystem.die(s,int(cid));break
		elif key=="marriage":
			var pair=marriage_pair(s,realm)
			if pair.size()==2:
				r.resources.gold+=45
				DynastySystem.marry(s,realm,pair[0],pair[1])
		elif key=="commander":
			var c=CharacterSystem.make(s,realm,"m",26,"marshal");c.martial=18;c.loyalty=78
