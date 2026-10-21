class_name DiplomacySystem
extends RefCounted
static func acceptance(s,actor:int,target:int,action:String)->int:
	var rel=s.relation(actor,target);var ratio=ArmySystem.strength(s,actor)/maxf(60,ArmySystem.strength(s,target));var diplomacy=CharacterSystem.bonus(s,actor,"chancellor")
	var base=25+int(rel.value)*0.65+diplomacy*1.5+(ratio-1)*13
	if action=="nap":base+=20
	if s.data.has("living"):
		base+=minf(4,float(s.data.dynasties[int(s.data.realms[actor].dynasty_id)].prestige)/25)
		if s.provinces_of(actor).any(func(p):return int(p.buildings.get("embassy_court",0))>0):base+=3
	if action=="tribute":base=5+maxf(0,ratio-1)*33-int(rel.value)*0.15
	if s.data.realms[target].personality=="diplomat":base+=12
	return clampi(int(base),5,95)
static func act(s,actor:int,target:int,action:String)->Dictionary:
	if target<0 or target>=s.data.realms.size() or target==actor:return s.result(false,"Выберите другое государство.")
	var rel=s.relation(actor,target);var now=int(s.data.day);var cooldown=actor
	var key="%d_%s"%[cooldown,action]
	if int(rel.cooldowns.get(key,-1))>now:return s.result(false,"Посольство ещё занято. Доступно через %d дн."%(int(rel.cooldowns[key])-now))
	if s.at_war(actor,target):return s.result(false,"Во время войны доступны переговоры о мире.")
	var cost={"gold":{"improve":12,"worsen":0,"gift":35,"alliance":20,"break_alliance":0,"nap":15,"tribute":10,"grant_access":0,"request_access":15}.get(action,-1)}
	if int(cost.gold)<0:return s.result(false,"Неизвестное дипломатическое действие.")
	if action=="break_alliance" and not rel.alliance:return s.result(false,"Союза нет.")
	if action=="alliance" and rel.alliance:return s.result(false,"Союз уже заключён.")
	if action=="nap" and int(rel.nap_until)>now:return s.result(false,"Пакт уже действует.")
	if not s.can_pay(actor,cost):return s.result(false,"Недостаточно золота для посольства.")
	s.pay(actor,cost);rel.cooldowns[key]=now+30
	if s.data.has("living") and actor==int(s.data.player):LivingWorld.dispatch(s,"diplomat",int(s.data.realms[actor].capital),int(s.data.realms[target].capital),actor)
	match action:
		"improve":rel.value=mini(100,int(rel.value)+12)
		"worsen":rel.value=maxi(-100,int(rel.value)-15)
		"gift":rel.value=mini(100,int(rel.value)+18);s.data.realms[target].resources.gold+=35
		"break_alliance":rel.alliance=false;rel.value=maxi(-100,int(rel.value)-20);rel.truce_until=now+90
		"grant_access":
			if not actor in rel.access:rel.access.append(actor)
			rel.value=mini(100,int(rel.value)+4)
		_:
			var chance=acceptance(s,actor,target,action)
			if s.rng.randi_range(1,100)>chance:return s.result(true,"Посольство вернулось: предложение отклонено (%d%%)."%chance)
			match action:
				"alliance":rel.alliance=true;rel.value=mini(100,int(rel.value)+12)
				"nap":rel.nap_until=now+360;rel.value=mini(100,int(rel.value)+6)
				"request_access":
					if not target in rel.access:rel.access.append(target)
				"tribute":
					var gold=minf(65,maxf(0,s.data.realms[target].resources.gold));s.data.realms[target].resources.gold-=gold;s.data.realms[actor].resources.gold+=gold;rel.value=maxi(-100,int(rel.value)-12)
	return s.result(true,"Дипломатическое действие выполнено.")
