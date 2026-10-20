class_name RealmSystem
extends RefCounted
static func monthly(s):
	for r in s.data.realms.duplicate():
		var id=int(r.id);var ruler=s.data.characters[int(r.ruler)]
		if s.provinces_of(id).is_empty():continue
		var avg=0.0
		for p in s.provinces_of(id):avg+=float(p.unrest)
		avg/=s.provinces_of(id).size()
		var stability_gain=0.7+(float(ruler.administration)-8)*0.09+CharacterSystem.bonus(s,id,"steward")*0.05-float(r.tax)*0.25
		r.stability=clampf(r.stability+stability_gain-(avg/40.0),0,100)
		var worst=100.0
		for c in s.data.characters:
			if not c.alive or int(c.realm)!=id or int(c.id)==int(r.ruler):continue
			var change=1.1-float(r.tax)*0.7+(float(r.legitimacy)-60)*0.035+(float(ruler.diplomacy)-8)*0.05
			if "Амбициозный" in c.traits:change-=0.7
			if "Жестокий" in ruler.traits:change-=0.5
			if "Справедливый" in ruler.traits:change+=0.35
			c.loyalty=clampf(c.loyalty+change,0,100);worst=minf(worst,c.loyalty)
		if avg>=65 or worst<25:
			r.rebel_warning+=30
			if id==int(s.data.player):s.log_message("Предупреждение: дворяне или крестьяне готовят мятеж. Снизьте налоги и недовольство.")
		else:r.rebel_warning=maxi(0,int(r.rebel_warning)-30)
		if int(r.rebel_warning)>=90 and int(s.data.day)>180:revolt(s,id)
static func revolt(s,realm:int):
	var owned=s.provinces_of(realm)
	if owned.is_empty():return
	var source=s.data.realms[realm];var chosen=owned[0]
	for p in owned:
		if float(p.unrest)>float(chosen.unrest):chosen=p
	var holder=int(chosen.holder)
	if holder==int(source.ruler):
		var noble=CharacterSystem.make(s,realm,"m",31,"rebel");holder=int(noble.id)
	var id=s.data.realms.size();var rebel=source.duplicate(true)
	rebel.id=id;rebel.name="Мятежники: "+chosen.name;rebel.ruler=holder;rebel.heir=-1;rebel.capital=int(chosen.id);rebel.suzerain=realm;rebel.tax=1;rebel.stability=52;rebel.rebel_warning=0;rebel.council={};rebel.resources={"gold":200.0,"food":350.0,"wood":80.0,"stone":70.0,"iron":35.0,"manpower":350.0};rebel.title=0;rebel.personality="opportunist";rebel.is_rebel=true
	s.data.realms.append(rebel);s.data.characters[holder].realm=id
	var transferred=0
	for p in owned:
		if int(p.holder)==int(chosen.holder) or int(p.id)==int(chosen.id):
			p.owner=id;p.holder=holder;p.unrest=35;transferred+=1
			if transferred>=3:break
	for i in range(id):s.data.relations[s.pair(i,id)]={"value":-20,"alliance":false,"nap_until":0,"truce_until":0,"access":[],"cooldowns":{}}
	ArmySystem.create(s,id,int(chosen.id),{"militia":160,"spearman":50})
	source.rebel_warning=0
	WarSystem.declare(s,id,realm,"independence")
	s.log_message("Мятеж! %s поднял %d провинц. и требует независимости."%[s.data.characters[holder].name,transferred])
static func daily(s):
	var player=int(s.data.player);var r=s.data.realms[player];var owned=s.provinces_of(player)
	if owned.is_empty() and s.data.outcome=="":s.data.outcome="defeat_land"
	if owned.size()>=int(s.balance.empire_provinces) and int(r.title)>=3 and float(r.stability)>=50:
		var occupied=0
		for p in owned:
			if int(p.occupation)>=0:occupied+=1
		if occupied==0:s.data.victory_days+=1
		else:s.data.victory_days=0
	else:s.data.victory_days=0
	if int(s.data.victory_days)>=int(s.balance.empire_hold_days) and not s.data.freeplay:s.data.outcome="victory"
static func law(s,realm:int,kind:String)->Dictionary:
	var r=s.data.realms[realm]
	if not kind in ["primogeniture","elective"] or r.law==kind:return s.result(false,"Этот закон уже действует или недоступен.")
	if not s.can_pay(realm,{"gold":50}):return s.result(false,"Изменение закона стоит 50 золота.")
	s.pay(realm,{"gold":50});r.law=kind;r.stability=maxf(0,r.stability-8);r.legitimacy=maxf(0,r.legitimacy-5);r.heir=DynastySystem.next_heir(s,realm)
	return s.result(true,"Закон наследования изменён. Дворянство обеспокоено.")
static func title(s,realm:int)->Dictionary:
	var r=s.data.realms[realm];var n=s.provinces_of(realm).size();var current=int(r.title)
	if current>=3:return s.result(false,"Вы уже носите императорский титул.")
	var required=[3,8,35][current];var cost=[180,420,900][current]
	if n<required or r.legitimacy<60:return s.result(false,"Нужно %d провинц. и легитимность 60."%required)
	if not s.can_pay(realm,{"gold":cost}):return s.result(false,"Нужно %d золота."%cost)
	s.pay(realm,{"gold":cost});r.title+=1;r.legitimacy=minf(100,r.legitimacy+8)
	if r.title>=2:r.suzerain=-1
	return s.result(true,"Провозглашён новый титул: "+["граф","герцог","король","император"][int(r.title)])
