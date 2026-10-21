class_name QuestSystem
extends RefCounted
static var catalogue:Dictionary={}
static func book()->Dictionary:
	if catalogue.is_empty():catalogue=GameState.read_json("res://data/quests.json")
	return catalogue
static func definition(id:String)->Dictionary:
	var base=id.split("@")[0]
	for q in book().quests:
		if q.id==base:return q
	return {}
static func ensure(s):
	if not s.data.has("quests"):
		s.data.quests={"version":1,"entries":{},"cooldowns":{},"counters":{},"tracked":"","flags":{}}
		# Existing campaign chapters are historical accomplishments, with no second reward.
		if NarrativeSystem.active(s):
			var n=s.data.narrative;var before=(int(n.act)-1)*6+int(n.slot)
			for i in range(before):
				var id="main_%02d"%(i+1);var d=definition(id)
				s.data.quests.entries[id]={"id":id,"status":"completed","started":s.data.day,"completed":s.data.day,"province":s.data.realms[int(s.data.player)].capital,"objective":d.objective.duplicate(true),"progress":d.objective.target,"rewarded":true,"deadline":-1,"agent":-1,"reason":"Глава завершена до обновления; повторная награда не начисляется."}
static func counters(s)->Dictionary:return s.data.quests.counters
static func find(s,id:String)->Dictionary:return s.data.quests.entries.get(id,{})
static func max_building(s,kind:String)->int:
	var value=0
	for p in s.provinces_of(int(s.data.player)):
		if int(p.occupation)<0:value=maxi(value,int(p.buildings.get(kind,0)))
	return value
static func available(s,d:Dictionary)->bool:
	var player=int(s.data.player);var own=s.provinces_of(player)
	if own.is_empty():return false
	if d.objective.get("building","") in ["port","royal_shipyard"] and not own.any(func(p):return p.coastal):return false
	if d.objective.get("building","")=="mine" and not own.any(func(p):return p.terrain in ["mountains","hills"]):return false
	if d.objective.get("action","")=="grant" and own.size()<2:return false
	return true
static func accept(s,id:String)->Dictionary:
	ensure(s);var d=definition(id)
	if d.is_empty() or d.category=="main":return s.result(false,"Это задание выдаёт сюжет.")
	if not available(s,d):return s.result(false,"Для поручения нет подходящих владений.")
	if s.data.quests.entries.has(id):return s.result(false,"Поручение уже принято.")
	var count=0
	for q in s.data.quests.entries.values():
		if q.status in ["active","ready"] and definition(q.id).category!="main":count+=1
	if count>=8:return s.result(false,"Сначала завершите одно из восьми текущих поручений.")
	activate(s,id,d);return s.result(true,"Поручение принято: "+d.title)
static func activate(s,id:String,d:Dictionary):
	var player=int(s.data.player);var r=s.data.realms[player];var pid=int(r.capital)
	if d.objective.kind in ["secure","condition","restore_farm"]:
		for p in s.provinces_of(player):
			var current=s.data.provinces[pid]
			if (float(p.unrest)>float(current.unrest) if d.objective.kind=="secure" else float(p.heritage.damage)>float(current.heritage.damage)):pid=int(p.id)
	var dev={}
	for p in s.provinces_of(player):dev[str(p.id)]=float(p.development)
	var q={"id":id,"status":"active","started":s.data.day,"province":pid,"objective":d.objective.duplicate(true),"snapshot":counters(s).duplicate(true),"development":dev,"arrivals":s.data.living.trade_arrivals.get(str(player),0),"progress":0.0,"streak":0,"rewarded":false,"reason":"","agent":-1,"deadline":int(s.data.day)+int(d.get("deadline",0)) if d.has("deadline") else -1}
	s.data.quests.entries[id]=q
	if d.category=="main" or s.data.quests.tracked=="":s.data.quests.tracked=id
	if d.objective.kind in ["delivery","caravan"]:
		var start=pid;var target=-1
		if id=="main_04":start=int(s.data.realms[1].capital);target=pid
		else:
			for road in LivingWorld.routes().graph.get(pid,[]):
				var to=int(road.b) if int(road.a)==pid else int(road.a)
				if not LivingWorld.danger(s,s.data.provinces[to]) and not s.at_war(player,int(s.data.provinces[to].owner)):target=to;break
		if target>=0:q.agent=LivingWorld.dispatch(s,"merchant" if d.objective.kind=="caravan" else "courier",start,target,player,id)
		q.reason="Посланник в пути." if int(q.agent)>=0 else "Дорога закрыта. Нужны безопасный маршрут или сведения тайного совета."
static func value(s,q:Dictionary)->float:
	var o=q.objective;var player=int(s.data.player);var r=s.data.realms[player];var target=float(o.target)
	var p=s.data.provinces[int(q.province)];var support=float(s.data.get("narrative",{}).get("variables",{}).get("noble_support",0))
	var canon=s.data.get("canon",{});var character=s.data.characters[int(canon.get(o.get("character",""),r.ruler))]
	match o.kind:
		"support":return target if float(r.legitimacy)>=target or support>=55 else float(r.legitimacy)
		"solvency":return minf(target,r.resources.gold) if r.budget.net>=0 else 0
		"building":return max_building(s,o.building)
		"delivery","caravan":return float(s.data.living.deliveries.get(q.id,0)) + (1 if o.kind=="delivery" and int(q.agent)<0 and intelligence_since(s,q)>0 else 0)
		"northern":
			if not character.alive:return target if r.legitimacy>=70 else 0
			return target if character.loyalty>=target or (r.stability>=65 and total_army(s)>=350) else character.loyalty
		"heir":return target if DynastySystem.next_heir(s,player)>=0 and r.legitimacy>=target else 0
		"relation":
			var other=int(o.realm_target)
			if other==player or s.provinces_of(other).is_empty():
				var best=-100.0
				for neighbor in ProvinceSystem.neighbors(s,player):best=maxf(best,float(s.relation(player,int(neighbor)).value))
				return target if best>=target or (r.stability>=65 and total_army(s)>=350) else maxf(0,best)
			return maxf(0,s.relation(player,other).value)
		"marriage_alliance":return target if (character.alive and int(character.spouse)>=0) or alliance_count(s)>0 else 0
		"brother":
			if not character.alive or int(character.realm)!=player or int(character.id)==int(r.ruler):return target if DynastySystem.next_heir(s,player)>=0 and r.legitimacy>=70 else 0
			var office=int(character.id) in r.council.values().map(func(x):return int(x))
			for owned in s.provinces_of(player):
				if int(owned.holder)==int(character.id):office=true
			return minf(target,character.loyalty) if office else 0
		"loyalists":return s.data.characters.filter(func(c):return c.alive and int(c.realm)==player and c.age>=16 and c.loyalty>=65 and int(c.id)!=int(r.ruler)).size()
		"action","command":return float(counters(s).get(o.action,0))-float(q.snapshot.get(o.action,0))
		"peace":return target if not EventSystem.matches(s,player,"war") and r.stability>=target else 0
		"heir_skill":
			var cid=DynastySystem.next_heir(s,player)
			return maxf(s.data.characters[cid].administration,s.data.characters[cid].diplomacy) if cid>=0 else 0
		"intelligence":return target if intelligence_since(s,q)>0 or (no_claimants(s) and (support>=70 or r.legitimacy>=75)) else 0
		"market_recovery":return target if max_building(s,"great_market")>0 and r.budget.net>=0 else 0
		"legitimacy":return float(r.legitimacy)
		"cadet":
			if not character.alive:return target if max_building(s,"dynastic_tomb")>0 and DynastySystem.next_heir(s,player)>=0 else 0
			if int(character.realm)!=player:return target if not s.at_war(player,int(character.realm)) and r.legitimacy>=65 else 0
			return character.loyalty
		"memorial":return target if maxi(max_building(s,"royal_archive"),max_building(s,"dynastic_tomb"))>0 else 0
		"recognition":
			if max_building(s,"embassy_court")==0:return 0
			var count=0;var live=0
			for other in s.data.realms:
				if int(other.id)!=player and not s.provinces_of(int(other.id)).is_empty():
					live+=1
					if int(s.relation(player,int(other.id)).value)>=30:count+=1
			return target if live<2 and r.legitimacy>=75 else count
		"legacy_project":return target if maxi(max_building(s,"niyazov_palace"),max_building(s,"great_library"))>0 and s.data.provinces[int(r.capital)].development>=target else 0
		"legacy":return target if r.stability>=target and DynastySystem.next_heir(s,player)>=0 and (support>=65 or float(s.data.get("narrative",{}).get("variables",{}).get("royal_authority",0))>=70) else 0
		"secure":
			if float(p.unrest)>target:return 0
			for a in s.data.armies:
				if int(a.realm)==player and int(a.province)==int(p.id) and ArmySystem.size(a)>=80:return target
			return 0
		"restore_farm":return target if max_building(s,"farm")>=2 and float(p.heritage.damage)<=20 else 0
		"food_store":return minf(target,r.resources.food) if max_building(s,"granary")>0 else 0
		"stone_store":return minf(target,r.resources.stone) if max_building(s,"quarry")>0 else 0
		"trade_market":return max_building(s,"market") if r.budget.net>=0 else 0
		"alliance":return alliance_count(s)
		"development_gain":
			var best=0.0
			for owned in s.provinces_of(player):best=maxf(best,float(owned.development)-float(q.development.get(str(owned.id),owned.development)))
			return best
		"low_tax_days","peace_days":return float(q.streak)
		"purchase","sale":
			var key=o.kind+"_"+o.resource;return float(counters(s).get(key,0))-float(q.snapshot.get(key,0))
		"commander":
			for a in s.data.armies:
				if int(a.realm)==player and int(a.commander)>=0:
					var c=s.data.characters[int(a.commander)]
					if c.alive and c.martial>=target:return target
			return 0
		"arrivals":return float(s.data.living.trade_arrivals.get(str(player),0))-float(q.arrivals)
		"gardens":return target if max_building(s,"royal_gardens")>0 and p.unrest<=target else 0
		"condition":return 100-float(p.heritage.damage)
	return 0
static func intelligence_since(s,q)->int:return int(counters(s).get("intelligence",0))-int(q.snapshot.get("intelligence",0))
static func no_claimants(s)->bool:
	return not s.data.characters.any(func(c):return c.alive and int(c.realm)==int(s.data.player) and int(c.id)!=int(s.data.realms[int(s.data.player)].ruler) and int(s.data.player) in c.claims)
static func total_army(s)->int:
	var count=0
	for a in s.data.armies:
		if int(a.realm)==int(s.data.player):count+=ArmySystem.size(a)
	return count
static func alliance_count(s)->int:
	var count=0
	for r in s.data.realms:
		if int(r.id)!=int(s.data.player) and not s.provinces_of(int(r.id)).is_empty() and s.relation(int(s.data.player),int(r.id)).alliance:count+=1
	return count
static func claim(s,id:String)->Dictionary:
	var q=find(s,id);var d=definition(id)
	if q.is_empty() or q.status not in ["active","ready"] or q.rewarded:return s.result(false,"Награда уже получена или задание недоступно.")
	q.progress=value(s,q)
	if q.progress<float(q.objective.target):q.status="active";return s.result(false,"Условия ещё не выполнены.")
	q.status="completed";q.rewarded=true;q.completed=s.data.day
	var player=int(s.data.player);s.data.realms[player].resources.gold+=float(d.reward.gold)
	DynastyHistory.entry(s,player,"Завершено поручение: "+d.title,float(d.reward.prestige))
	if NarrativeSystem.active(s) and d.category=="main":
		s.data.narrative.variables.noble_support=minf(100,float(s.data.narrative.variables.noble_support)+.5)
		s.data.narrative.timeline.push_front({"day":s.data.day,"text":"Дело короны: "+d.title})
	s.log_message("Задание выполнено: "+d.title)
	return s.result(true,"Задание завершено. Награда: %d золота."%d.reward.gold)
static func action(s,id:String,kind:String)->Dictionary:
	var q=find(s,id);var player=int(s.data.player)
	if q.is_empty() or q.status!="active":return s.result(false,"Поручение недоступно.")
	if q.objective.get("action","")!=kind:return s.result(false,"Это действие не относится к поручению.")
	var p=s.data.provinces[int(q.province)]
	if int(p.owner)!=player or int(p.occupation)>=0:return s.result(false,"Нужна свободная собственная провинция.")
	if kind=="relief":
		if not s.can_pay(player,{"food":60}):return s.result(false,"Нужно 60 продовольствия.")
		s.pay(player,{"food":60});p.unrest=maxf(0,p.unrest-8);p.population+=30
	elif kind=="supply_army":
		var own=s.data.armies.filter(func(a):return int(a.realm)==player)
		if own.is_empty() or not s.can_pay(player,{"food":80}):return s.result(false,"Нужны собственная армия и 80 продовольствия.")
		s.pay(player,{"food":80})
		for a in own:a.supply=minf(100,a.supply+15);a.morale=minf(100,a.morale+3)
	else:return s.result(false,"Неизвестное действие.")
	bump(s,kind,1);q.progress=value(s,q);q.status="ready" if q.progress>=float(q.objective.target) else "active"
	return s.result(true,"Ресурсы переданы. Результат записан в журнал.")
static func bump(s,key:String,amount:float):
	if not s.data.has("quests"):return
	s.data.quests.counters[key]=float(s.data.quests.counters.get(key,0))+amount
static func retry_delivery(s,id:String)->Dictionary:
	var q=find(s,id)
	if q.is_empty() or q.status!="active" or int(q.agent)>=0 or q.objective.kind not in ["delivery","caravan"]:return s.result(false,"Нового посланника сейчас отправлять не требуется.")
	if int(s.data.day)-int(q.get("last_retry",-30))<14:return s.result(false,"Повторная отправка доступна через две недели.")
	q.last_retry=s.data.day
	var player=int(s.data.player);var start=int(s.data.realms[player].capital);var target=-1
	if id=="main_04":target=start;start=int(s.data.realms[1].capital)
	else:
		for road in LivingWorld.routes().graph.get(start,[]):
			var pid=int(road.b) if int(road.a)==start else int(road.a)
			if LivingWorld.routes().passage(s,player,int(s.data.provinces[pid].owner),"merchant"):target=pid;break
	if target>=0:q.agent=LivingWorld.dispatch(s,"merchant" if q.objective.kind=="caravan" else "courier",start,target,player,id)
	return s.result(int(q.agent)>=0,"Посланник отправлен." if int(q.agent)>=0 else "Дороги ещё закрыты.")
static func on_command(s,actor:int,command:String,args:Dictionary):
	if actor!=int(s.data.player) or not s.data.has("quests"):return
	bump(s,command,1)
	if command=="trade":bump(s,("purchase_" if args.get("buy",true) else "sale_")+str(args.resource),float(args.amount))
static func chapter_ready(s)->bool:
	if not NarrativeSystem.active(s):return true
	var n=s.data.narrative;var id="main_%02d"%((int(n.act)-1)*6+int(n.slot)+1)
	return find(s,id).get("status","")=="completed"
static func daily(s):
	ensure(s);var player=int(s.data.player);var r=s.data.realms[player]
	if NarrativeSystem.active(s) and s.data.narrative.ending=="":
		var n=s.data.narrative;var id="main_%02d"%((int(n.act)-1)*6+int(n.slot)+1)
		if not s.data.quests.entries.has(id):activate(s,id,definition(id))
	for q in s.data.quests.entries.values():
		if q.status not in ["active","ready"]:continue
		var d=definition(q.id);var p=s.data.provinces[int(q.province)]
		if int(p.owner)!=player:
			if d.category=="main" and not s.provinces_of(player).is_empty():q.province=r.capital;q.reason="Прежнее владение потеряно; цель перенесена в столицу."
			else:q.status="cancelled";q.reason="Связанное владение потеряно. Награда не выдана.";continue
		if int(q.deadline)>=0 and int(s.data.day)>int(q.deadline):q.status="cancelled";q.reason="Срок поручения истёк.";continue
		if q.objective.kind=="low_tax_days":q.streak=int(q.streak)+1 if int(r.tax)==0 and r.budget.net>=0 else 0
		if q.objective.kind=="peace_days":q.streak=int(q.streak)+1 if not EventSystem.matches(s,player,"war") and r.stability>=60 else 0
		if q.objective.kind in ["delivery","caravan"] and int(q.agent)>=0:
			var a=LivingWorld.agent(s,int(q.agent))
			if a.is_empty() and int(s.data.living.deliveries.get(q.id,0))==0:
				q.agent=-1;q.reason="Посланник не вернулся. Тайный совет может добыть сведения; новый курьер доступен после открытия дорог."
		q.progress=value(s,q);q.status="ready" if q.progress>=float(q.objective.target) else "active"
	if NarrativeSystem.active(s) and s.data.narrative.get("chapter_waiting",false) and chapter_ready(s):
		s.data.narrative.chapter_waiting=false;NarrativeSystem.advance(s)
	if int(s.data.day)%15==0:dynamic(s)
static func dynamic(s):
	var own=s.provinces_of(int(s.data.player));var r=s.data.realms[int(s.data.player)]
	if own.is_empty():return
	var active=0
	for q in s.data.quests.entries.values():
		if definition(q.id).category=="dynamic" and q.status in ["active","ready"]:active+=1
	if active>=3:return
	for d in book().quests:
		if d.category!="dynamic" or not available(s,d) or int(s.data.quests.cooldowns.get(d.id,-1))>int(s.data.day):continue
		if s.data.quests.entries.values().any(func(q):return q.id.begins_with(d.id+"@") and q.status in ["active","ready"]):continue
		var matches=false
		match d.trigger:
			"famine":matches=r.resources.food<60
			"unrest":matches=own.any(func(p):return float(p.unrest)>60)
			"blocked":matches=s.data.living.agents.any(func(a):return int(a.realm)==int(r.id) and a.status=="blocked" and a.kind=="merchant")
			"no_heir":matches=DynastySystem.next_heir(s,int(r.id))<0
			"war":matches=EventSystem.matches(s,int(r.id),"war")
			"low_stability":matches=r.stability<40
			"damage":matches=own.any(func(p):return float(p.heritage.damage)>40)
			"prosperity":matches=r.budget.net>25 and r.stability>65 and max_building(s,"market")<2
			"succession":matches=s.data.dynasties[int(r.dynasty_id)].reigns.size()>1 and r.legitimacy<65
			"coastal":matches=own.any(func(p):return p.coastal) and max_building(s,"port")<2 and r.resources.gold>200
			"claimant":matches=not no_claimants(s) and r.stability<50
		if matches:
			var id=d.id+"@"+str(int(s.data.day));activate(s,id,d);s.data.quests.cooldowns[d.id]=int(s.data.day)+int(d.cooldown);return
static func marker(s,pid:int,lod:int)->String:
	if not s.data.has("quests"):return ""
	for q in s.data.quests.entries.values():
		if int(q.province)==pid and q.status in ["active","ready"] and (lod==0 or definition(q.id).category=="main"):return "✓" if q.status=="ready" else "!"
	return ""
