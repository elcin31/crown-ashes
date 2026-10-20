class_name WarSystem
extends RefCounted
static func declare(s,actor:int,target:int,reason:String="claim")->Dictionary:
	if actor==target or target<0 or target>=s.data.realms.size() or s.provinces_of(target).is_empty():return s.result(false,"Недопустимая цель войны.")
	if s.at_war(actor,target):return s.result(false,"Война уже идёт.")
	var rel=s.relation(actor,target)
	if rel.alliance:return s.result(false,"Сначала расторгните союз.")
	if int(rel.truce_until)>int(s.data.day) or int(rel.nap_until)>int(s.data.day):return s.result(false,"Действует перемирие или пакт о ненападении.")
	var valid=false
	if reason=="independence":valid=int(s.data.realms[actor].suzerain)==target
	elif reason=="throne":valid=target in s.data.realms[actor].claims and float(s.data.realms[actor].legitimacy)>=65
	elif reason=="claim":valid=target in ProvinceSystem.neighbors(s,actor)
	elif reason=="retaliation":valid=int(rel.value)<=-45
	if not valid:return s.result(false,"Нет подходящего основания для этой войны.")
	if not s.can_pay(actor,{"gold":40,"food":50}):return s.result(false,"Для похода нужны 40 золота и 50 продовольствия.")
	s.pay(actor,{"gold":40,"food":50});s.data.realms[actor].stability=maxf(0,s.data.realms[actor].stability-7)
	rel.value=maxi(-100,int(rel.value)-45)
	var war={"id":s.data.next_war,"a":actor,"b":target,"reason":reason,"score":0.0,"start":s.data.day}
	s.data.next_war+=1;s.data.wars.append(war)
	for other in ProvinceSystem.neighbors(s,actor):
		if other!=target:s.relation(actor,other).value=maxi(-100,int(s.relation(actor,other).value)-4)
	s.log_message("Война: %s против %s."%[s.realm_name(actor),s.realm_name(target)])
	return s.result(true,"Война объявлена. Переместите войска на вражескую территорию.")
static func peace(s,actor:int,target:int,terms:String="white")->Dictionary:
	var w=s.war_between(actor,target)
	if w.is_empty():return s.result(false,"Нет войны для заключения мира.")
	var score=float(w.score)*(1 if int(w.a)==actor else -1);var duration=int(s.data.day)-int(w.start)
	if terms=="white" and absf(score)>12 and duration<90:return s.result(false,"Противник пока не согласен на белый мир.")
	if terms in ["land","gold","independence","throne"] and score<20:return s.result(false,"Для требований нужен военный счёт не менее +20.")
	if terms=="independence" and w.reason!="independence":return s.result(false,"Война не велась за независимость.")
	if terms=="throne" and (w.reason!="throne" or score<55):return s.result(false,"Для престола нужен счёт +55 и соответствующее основание.")
	var taken=[]
	if terms=="land":
		var max_count=maxi(1,int(score/20))
		for p in s.provinces_of(target):
			if int(p.occupation)==actor and taken.size()<max_count:taken.append(int(p.id))
		if taken.is_empty():return s.result(false,"Нет занятых провинций в пределах военного счёта.")
	if not terms in ["white","land","gold","independence","throne"]:return s.result(false,"Неизвестные условия мира.")
	for pid in taken:
		var p=s.data.provinces[pid];p.owner=actor;p.holder=s.data.realms[actor].ruler;p.unrest=minf(100,p.unrest+18)
	if terms=="gold":
		var payment=minf(maxf(0,s.data.realms[target].resources.gold),score*3.0)
		s.data.realms[target].resources.gold-=payment;s.data.realms[actor].resources.gold+=payment
	if terms=="independence":s.data.realms[actor].suzerain=-1;s.data.realms[actor].independent_since=s.data.day
	if terms=="throne":
		for p in s.provinces_of(target):p.owner=actor;p.holder=s.data.realms[actor].ruler;p.unrest=minf(100,p.unrest+22)
		s.data.realms[actor].title=maxi(2,int(s.data.realms[actor].title));s.data.realms[actor].suzerain=-1
	for p in s.data.provinces:
		if int(p.owner) in [actor,target] and int(p.occupation) in [actor,target]:p.occupation=-1;p.siege={}
	for r in [actor,target]:
		if s.provinces_of(r).is_empty():
			for a in s.data.armies.duplicate():
				if int(a.realm)==r:s.data.armies.erase(a)
		else:
			if int(s.data.provinces[int(s.data.realms[r].capital)].owner)!=r:s.data.realms[r].capital=int(s.provinces_of(r)[0].id)
	for a in s.data.armies:
		if int(a.realm) in [actor,target]:
			a.route=[];a.order="idle"
			if not ProvinceSystem.can_enter(s,int(a.realm),int(s.data.provinces[int(a.province)].owner)):a.province=s.data.realms[int(a.realm)].capital
	s.data.wars.erase(w);s.relation(actor,target).truce_until=int(s.data.day)+360
	s.log_message("Мир: %s и %s. Передано провинций: %d. Перемирие — 360 дней."%[s.realm_name(actor),s.realm_name(target),taken.size()])
	return s.result(true,"Мирный договор заключён.")
