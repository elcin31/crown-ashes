class_name NarrativeSystem
extends RefCounted
# A data-driven extension of EventSystem. World consequences use existing commands.
static var catalogue:Dictionary={}
static func book()->Dictionary:
	if catalogue.is_empty():catalogue=GameState.read_json("res://data/narrative.json")
	return catalogue
static func active(s)->bool:return s.data.get("narrative",{}).get("enabled",false)
static func start(s):
	s.data.campaign_mode="niyazov"
	s.data.narrative={"version":1,"enabled":true,"realm":0,"dynasty":s.data.realms[0].dynasty_id,"act":1,"slot":0,"completed":[],"skipped":[],"decisions":[],"flags":{},"variables":{"royal_authority":50.0,"noble_support":44.0,"dynasty_prestige":35.0},"threats":{},"claimants":[],"conflict_days":0,"conflict_warned":false,"last_ruler":s.data.realms[0].ruler,"ending":"","ending_seen":false,"timeline":[]}
	update_threats(s);schedule(s)
static func actor(s,key:String)->Dictionary:
	var id=-1
	if key=="ruler":id=int(s.data.realms[0].ruler)
	elif key=="heir":id=DynastySystem.next_heir(s,0)
	else:id=int(s.data.get("canon",{}).get(key,-1))
	return s.data.characters[id] if id>=0 and id<s.data.characters.size() else {}
static func alive(s,key:String)->bool:
	var c=actor(s,key);return not c.is_empty() and c.alive
static func condition(s,key:String)->bool:
	var m=actor(s,"mikhail");var f=actor(s,"sofia");var v=actor(s,"victor")
	match key:
		"always":return true
		"mikhail_disloyal":return alive(s,"mikhail") and int(m.id)!=int(s.data.realms[0].ruler) and float(m.loyalty)<65
		"mikhail_loyal":return alive(s,"mikhail") and int(m.id)!=int(s.data.realms[0].ruler) and float(m.loyalty)>=65
		"mikhail_dead":return not alive(s,"mikhail")
		"family_changed":return not alive(s,"elizabeth") or not alive(s,"mikhail") or not alive(s,"daniil")
		"sofia_available":return alive(s,"sofia") and int(f.spouse)<0 and int(f.age)>=16 and int(f.realm)==0
		"sofia_unavailable":return not condition(s,"sofia_available")
		"east_exists":return not s.provinces_of(9).is_empty()
		"east_gone":return s.provinces_of(9).is_empty()
		"war":return EventSystem.matches(s,0,"war")
		"peace":return not condition(s,"war")
		"heir":return DynastySystem.next_heir(s,0)>=0
		"no_heir":return not condition(s,"heir")
	return false
static func possible(s,e:Dictionary)->bool:
	if e.id=="n_coronation" and int(s.data.realms[0].ruler)!=int(actor(s,"alexander").get("id",-1)):return false
	if not condition(s,e.get("condition","always")):return false
	for key in e.get("actors",[]):
		if not alive(s,key):return false
	return true
static func event_by_id(id:String)->Dictionary:
	for e in book().events:
		if e.id==id:return e
	return {}
static func render(s,e:Dictionary)->Dictionary:
	var copy=e.duplicate(true)
	if e.id=="n_cadet" and not alive(s,"victor"):copy.description="Виктора больше нет в живых. Права северной ветви рассматриваются по родословной, а не по письмам от имени умершего. Как корона сохранит память о родичах?"
	for field in ["title","description"]:
		var text=str(copy.get(field,""))
		for key in ["ruler","heir","alexander","elizabeth","mikhail","sofia","victor","duke"]:
			var c=actor(s,key);var name=str(c.get("name","родич, которого больше нет при дворе"))
			if key=="heir":name="Следующий по закону — %s, %d лет"%[c.name,c.age] if not c.is_empty() else "Законного наследника пока нет"
			text=text.replace("{"+key+"}",name)
		copy[field]=text
	return copy
static func schedule(s):
	if not active(s) or s.data.narrative.ending!="":return
	var n=s.data.narrative
	for entry in s.data.events:
		if entry.has("narrative_id"):return
	for e in book().events:
		if int(e.act)!=int(n.act) or int(e.slot)!=int(n.slot) or int(s.data.day)<int(e.min_day):continue
		if e.id in n.completed or e.id in n.skipped or not possible(s,e):continue
		s.data.events.push_front({"narrative_id":e.id,"day":s.data.day,"realm":0});return
	# A missing/deceased participant never gets resurrected to satisfy a chapter.
	var due=false
	for e in book().events:
		if int(e.act)==int(n.act) and int(e.slot)==int(n.slot) and int(s.data.day)>=int(e.min_day):due=true
	if due:
		n.skipped.append("act_%d_slot_%d"%[n.act,n.slot]);record(s,"Глава изменена: участники больше не могут исполнить прежние роли.");advance(s)
static func advance(s):
	var n=s.data.narrative;n.slot+=1
	if int(n.slot)>=6 and int(n.act)<4:n.act+=1;n.slot=0;record(s,"Акт %d. %s"%[n.act,book().acts[int(n.act)-1].name])
static func choice_status(s,c:Dictionary)->Dictionary:
	if not condition(s,c.get("condition","always")):return s.result(false,"Обстоятельства изменились.")
	var cost=c.get("cost",{}).duplicate();var op=c.get("operation","")
	var extra={}
	match op:
		"develop":
			extra={"gold":65,"wood":15,"stone":15};var p=s.data.provinces[int(s.data.realms[0].capital)]
			if int(p.owner)!=0 or int(p.occupation)>=0 or float(p.development)>=100:return s.result(false,"Столицу сейчас нельзя развить.")
		"investigate":
			extra={"gold":20};var ctarget=investigation_target(s)
			if ctarget.is_empty():return s.result(false,"Нет живого подходящего претендента при дворе.")
			for intrigue in s.data.intrigues:
				if int(intrigue.actor)==0 and int(intrigue.target)==int(ctarget.id):return s.result(false,"Расследование уже идёт.")
		"sofia_marriage":
			extra={"gold":45}
			if marriage_target(s).is_empty():return s.result(false,"Нет свободной подходящей пары или отношений для этого брака.")
		"confirm_heir":
			if s.data.realms[0].law!="primogeniture":extra={"gold":50}
		"brother_command","brother_marshal","grant_brother","strip_brother":
			if not alive(s,"mikhail") or int(actor(s,"mikhail").realm)!=0:return s.result(false,"Принц больше не находится при королевском дворе.")
			if op=="grant_brother" and grant_province(s)<0:return s.result(false,"Нет свободной провинции вне столицы.")
			if op=="brother_command" and royal_army(s)<0:return s.result(false,"Нет королевской армии.")
		"teach_admin","teach_diplomacy","heir_loyalty":
			if not condition(s,"heir"):return s.result(false,"Нет живого законного наследника.")
	for key in extra:cost[key]=float(cost.get(key,0))+float(extra[key])
	return s.result(s.can_pay(0,cost),"Недостаточно ресурсов: "+str(cost))
static func investigation_target(s)->Dictionary:
	for key in ["mikhail","victor"]:
		var c=actor(s,key)
		if not c.is_empty() and c.alive and int(c.realm)==0 and int(c.id)!=int(s.data.realms[0].ruler):return c
	return {}
static func marriage_target(s)->Dictionary:
	if not condition(s,"sofia_available") or s.provinces_of(1).is_empty() or s.at_war(0,1) or int(s.relation(0,1).value)<-10:return {}
	var f=actor(s,"sofia")
	for c in s.data.characters:
		if c.alive and int(c.realm)==1 and c.gender=="m" and int(c.age)>=16 and int(c.spouse)<0 and int(c.dynasty)!=int(f.dynasty):return c
	return {}
static func grant_province(s)->int:
	var brother=actor(s,"mikhail")
	for p in s.provinces_of(0):
		if int(p.id)!=int(s.data.realms[0].capital) and int(p.occupation)<0 and int(p.holder)!=int(brother.get("id",-1)):return int(p.id)
	return -1
static func royal_army(s)->int:
	for a in s.data.armies:
		if int(a.realm)==0:return int(a.id)
	return -1
static func operation(s,kind:String)->Dictionary:
	var cmd=GameCommands.new(s);var r=s.data.realms[0]
	match kind:
		"tax_low":return cmd.execute(0,"tax",{"level":0})
		"confirm_heir":
			if r.law!="primogeniture":return cmd.execute(0,"law",{"law":"primogeniture"})
		"develop":return cmd.execute(0,"develop",{"province":int(r.capital)})
		"investigate":return cmd.execute(0,"intrigue",{"character":int(investigation_target(s).id),"kind":"gather"})
		"sofia_marriage":return cmd.execute(0,"marry",{"a":int(actor(s,"sofia").id),"b":int(marriage_target(s).id)})
		"brother_command":return cmd.execute(0,"commander",{"army":royal_army(s),"character":int(actor(s,"mikhail").id)})
		"brother_marshal":
			if int(r.council.get("marshal",-1))!=int(actor(s,"mikhail").id):return cmd.execute(0,"appoint",{"slot":"marshal","character":int(actor(s,"mikhail").id)})
		"grant_brother":return cmd.execute(0,"grant",{"province":grant_province(s),"character":int(actor(s,"mikhail").id)})
		"strip_brother":
			var c=actor(s,"mikhail");c.title=0
			for p in s.provinces_of(0):
				if int(p.holder)==int(c.id):p.holder=r.ruler
			for slot in r.council.keys():
				if int(r.council[slot])==int(c.id):r.council.erase(slot)
		"border_envoy":change_relation(s,9,18)
		"border_claim","expansion":
			if not s.provinces_of(9).is_empty():
				change_relation(s,9,-18)
				if not 9 in r.claims:r.claims.append(9)
		"neighbors","neighbors_pressure","peace_envoy":
			for target in ProvinceSystem.neighbors(s,0):
				if kind=="peace_envoy" and not s.at_war(0,int(target)):continue
				change_relation(s,int(target),-6 if kind=="neighbors_pressure" else 8 if kind=="peace_envoy" else 10)
		"teach_admin","teach_diplomacy":
			var c=actor(s,"heir");var skill="administration" if kind=="teach_admin" else "diplomacy";c[skill]=mini(20,int(c[skill])+2)
		"heir_loyalty":var c=actor(s,"heir");c.loyalty=minf(100,float(c.loyalty)+8)
		"ending":finish(s,ending(s))
	return s.result(true,"")
static func change_relation(s,target:int,amount:int):
	if s.provinces_of(target).is_empty():return
	s.relation(0,target).value=clampi(int(s.relation(0,target).value)+amount,-100,100)
static func choose(s,index:int,choice:int)->Dictionary:
	var entry=s.data.events[index];var e=event_by_id(str(entry.narrative_id))
	if e.is_empty():return s.result(false,"Сюжетное событие не найдено.")
	if not possible(s,e):
		s.data.events.remove_at(index);schedule(s);return s.result(false,"Обстоятельства изменились. Летописец подготовит другую главу.")
	if choice<0 or choice>=e.choices.size():return s.result(false,"Неизвестное решение.")
	var c=e.choices[choice];var valid=choice_status(s,c)
	if not valid.ok:return valid
	var op=operation(s,c.get("operation",""))
	if not op.ok:return op
	s.pay(0,c.get("cost",{}));EventSystem.apply(s,0,c.get("effects",{}))
	var n=s.data.narrative
	for key in c.get("politics",{}):n.variables[key]=clampf(float(n.variables.get(key,50))+float(c.politics[key]),0,100)
	for key in c.get("loyalty",{}):
		var person=actor(s,key)
		if not person.is_empty() and person.alive:
			person.loyalty=clampf(float(person.loyalty)+float(c.loyalty[key]),0,100);person.relationships[str(s.data.realms[0].ruler)]=clampi(int(person.relationships.get(str(s.data.realms[0].ruler),0))+int(c.loyalty[key]),-100,100)
	for key in c.get("flags",{}):n.flags[key]=c.flags[key]
	n.completed.append(e.id);n.decisions.append({"id":e.id,"choice":choice,"label":c.label,"day":s.data.day,"ruler":s.data.realms[0].ruler});record(s,e.title+": "+c.label)
	s.data.events.remove_at(index)
	if n.ending=="":advance(s)
	update_threats(s);EconomySystem.forecast(s,0)
	return s.result(true,"Решение записано в историю."+(" "+op.message if op.message!="" else ""))
static func record(s,message:String):
	s.data.narrative.timeline.push_front({"day":s.data.day,"text":message});s.log_message(message)
static func update_threats(s):
	if not active(s):return
	var n=s.data.narrative;var r=s.data.realms[0];var ruler=s.data.characters[int(r.ruler)];var candidates=[];var tension=0.0;var foreign=0.0
	for c in s.data.characters:
		if not c.alive or int(c.age)<16 or int(c.id)==int(r.ruler) or not 0 in c.claims:continue
		var support=0
		for noble in s.data.characters:
			if noble.alive and int(noble.realm)==0 and float(noble.loyalty)<45 and int(noble.title)>0:support+=1
		var personal=float(c.relationships.get(str(r.ruler),0))
		var strength=clampf((100-float(c.loyalty))*.45+float(c.ambition)*.18+(100-float(r.legitimacy))*.2+(100-float(n.variables.noble_support))*.15-personal*.08,0,100)
		var loyal=int(c.realm)==0 and float(c.loyalty)>=65
		candidates.append({"character":c.id,"basis":"Боковая ветвь дома" if c.get("branch","")=="Северная ветвь" else "Родство с прежним монархом","supporters":support,"relationship":personal,"ambition":c.ambition,"noble_support":strength,"chance":"слабые" if strength<45 else "неясные" if strength<70 else "серьёзные","loyal":loyal})
		if not loyal:tension=maxf(tension,strength)
	for target in ProvinceSystem.neighbors(s,0):foreign=maxf(foreign,maxf(0,-float(s.relation(0,int(target)).value))+(25 if s.at_war(0,int(target)) else 0))
	n.claimants=candidates;n.threats={"succession_tension":tension,"civil_war_risk":clampf((tension-52)*1.9+maxf(0,55-float(r.stability))*.6,0,100),"foreign_pressure":minf(100,foreign),"dynasty_legitimacy":r.legitimacy}
static func daily(s):
	if not active(s) or s.data.narrative.ending!="":return
	var n=s.data.narrative;var r=s.data.realms[0]
	if s.provinces_of(0).is_empty() or int(r.dynasty_id)!=int(n.dynasty):finish(s,"dynasty_lost");return
	if int(n.last_ruler)!=int(r.ruler):
		record(s,"Престол унаследовал(а) "+s.data.characters[int(r.ruler)].name+". История дома продолжается.");n.flags.successor_reigned=true;n.last_ruler=r.ruler
	if int(s.data.day)%7==0:
		update_threats(s)
		if float(n.threats.civil_war_risk)>=70:
			n.conflict_days+=7
			if not n.conflict_warned:record(s,"Предупреждение: сторонники претендентов собираются в замках. Верность ниже 25 и затяжной кризис могут привести к вооружённому мятежу.");n.conflict_warned=true
			if int(n.conflict_days)>=60:
				for claim in n.claimants:
					var c=s.data.characters[int(claim.character)]
					if int(c.realm)!=0 or float(c.loyalty)>=25:continue
					var owns=false
					for p in s.provinces_of(0):
						if int(p.holder)==int(c.id) and int(p.id)!=int(r.capital):owns=true
					if owns:
						RealmSystem.revolt(s,0,int(c.id));record(s,c.name+" поднял знамя против короны.");n.flags.civil_war=true;n.conflict_days=0;break
		else:n.conflict_days=maxi(0,int(n.conflict_days)-14);n.conflict_warned=false
	if int(s.data.day)%30==0:
		# Modest political effects, never a parallel economy or free army generator.
		if float(n.variables.royal_authority)>=70 and s.can_pay(0,{"gold":8}):s.pay(0,{"gold":8});r.stability=minf(100,float(r.stability)+.8)
		if float(n.variables.noble_support)>=65:
			for p in s.provinces_of(0):p.unrest=maxf(0,float(p.unrest)-1)
			r.legitimacy=minf(100,float(r.legitimacy)+.4)
		if float(n.variables.dynasty_prestige)>=70 and int(s.data.day)%60==0:
			for target in ProvinceSystem.neighbors(s,0):change_relation(s,int(target),1)
	schedule(s)
static func ending(s)->String:
	var n=s.data.narrative;var r=s.data.realms[0]
	if int(r.dynasty_id)!=int(n.dynasty) or s.provinces_of(0).is_empty():return "dynasty_lost"
	for w in s.data.wars:
		var other=int(w.b) if int(w.a)==0 else int(w.a) if int(w.b)==0 else -1
		if other>=0 and s.data.realms[other].get("is_rebel",false):return "dynastic_war"
	if int(r.title)>=3 and s.provinces_of(0).size()>=35 and float(r.stability)>=50:return "empire"
	if n.flags.get("successor_reigned",false) and float(r.stability)>=50 and float(r.legitimacy)>=55:return "peaceful_succession"
	if float(n.variables.noble_support)>=65 and float(n.variables.royal_authority)<=60 and float(r.stability)>=50:return "federation"
	if float(n.variables.royal_authority)>=65 and float(n.variables.noble_support)>=40 and float(r.stability)>=55 and not condition(s,"war"):return "central_monarchy"
	if float(n.threats.get("civil_war_risk",0))>=65 or float(r.legitimacy)<45:return "contested_crown"
	return "surviving_crown"
static func ending_text(id:String)->Dictionary:
	return {"dynasty_lost":{"title":"Лев без трона","text":"Дом Ниязовых лишился власти в Аурелиане. Его история не переписана победителями: родство и принятые решения остались в летописи."},"dynastic_war":{"title":"Разделённое знамя","text":"Соперники подняли настоящие армии. Королевство вступило в династическую войну; её исход ещё предстоит решить на карте."},"empire":{"title":"Империя золотого льва","text":"Ниязовы объединили не менее 35 земель под императорской короной. Масштаб власти стал новым испытанием для дома."},"peaceful_succession":{"title":"Корона пережила короля","text":"Законный преемник Ниязовых принял власть, и королевство выдержало смену правления. Прочность дома оказалась сильнее одной жизни."},"federation":{"title":"Союз великих домов","text":"Король сохранил корону, разделив власть с вассалами. Аурелиан стал союзом владений, связанных законом и взаимными обязательствами."},"central_monarchy":{"title":"Единая королевская печать","text":"Сильная канцелярия и достаточное согласие знати сделали Аурелиан устойчивой централизованной монархией."},"contested_crown":{"title":"Незавершённая присяга","text":"Дом удержал трон, но не убедил всех в праве повелевать. Будущее остаётся открытым: кризис ещё можно разрешить без войны."},"surviving_crown":{"title":"Корона, которую сохранили","text":"Ниязовы сохранили государство, хотя ни король, ни вассалы не получили всего желаемого. История продолжится за пределами первых лет царствования."}}.get(id,{"title":"Наследие","text":"История продолжается."})
static func finish(s,id:String):
	var n=s.data.narrative
	if n.ending!="":return
	n.ending=id;record(s,ending_text(id).title)
