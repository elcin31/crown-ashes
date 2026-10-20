class_name DynastySystem
extends RefCounted
static func candidates(s,realm:int)->Array:
	var r=s.data.realms[realm];var ruler=s.data.characters[int(r.ruler)];var result=[]
	for cid in ruler.children:
		var c=s.data.characters[int(cid)]
		if c.alive and int(c.dynasty)==int(r.dynasty_id):result.append(int(cid))
	if result.is_empty():
		for cid in s.data.dynasties[int(r.dynasty_id)].members:
			var c=s.data.characters[int(cid)]
			if c.alive and int(cid)!=int(r.ruler):result.append(int(cid))
	result.sort_custom(func(a,b):return float(s.data.characters[a].age)>float(s.data.characters[b].age))
	return result
static func next_heir(s,realm:int)->int:
	var r=s.data.realms[realm];var possible=candidates(s,realm)
	if possible.is_empty():return -1
	if r.law=="primogeniture":return int(possible[0])
	var best=int(possible[0]);var best_score=-999.0
	for cid in possible:
		var c=s.data.characters[cid];var score=float(c.diplomacy)*2+c.administration+c.martial*0.5+c.loyalty*0.3
		if int(c.age)<16:score-=30
		if int(r.heir)==cid:score+=8
		for p in s.provinces_of(realm):
			var noble=s.data.characters[int(p.holder)]
			if "Амбициозный" in noble.traits and "Амбициозный" in c.traits:score+=2
		if score>best_score:best=cid;best_score=score
	return best
static func succeed(s,realm:int):
	var r=s.data.realms[realm];var heir=next_heir(s,realm)
	if heir<0:
		if realm==int(s.data.player):s.data.outcome="defeat_dynasty"
		else:
			var new=CharacterSystem.make(s,realm,"m",28,"ruler");r.ruler=new.id;r.heir=-1
		return
	var previous=int(r.ruler);r.ruler=heir;var c=s.data.characters[heir];c.role="ruler";c.title=r.title;c.portrait="king_young" if c.gender=="m" else "queen_young"
	s.data.dynasties[int(r.dynasty_id)].head=heir
	r.legitimacy=clampf(float(r.legitimacy)-12+(float(c.diplomacy)-8),10,100);r.stability=maxf(0,r.stability-(16 if c.age<16 else 8))
	for p in s.provinces_of(realm):
		if int(p.holder)==previous:p.holder=heir
	r.heir=next_heir(s,realm)
	if realm==int(s.data.player):s.data.events.push_front({"special":"succession","title":"Да здравствует новый правитель!","description":"Престол наследует %s (%d лет). %s"%[c.name,c.age,"До совершеннолетия совет исполняет обязанности регента." if c.age<16 else "Дворяне вновь приносят присягу."],"illustration":"coronation"})
	s.log_message("%s: новый правитель — %s из дома %s."%[r.name,c.name,r.dynasty])
static func marry(s,realm:int,a:int,b:int)->Dictionary:
	if a<0 or b<0 or a>=s.data.characters.size() or b>=s.data.characters.size() or a==b:return s.result(false,"Некорректная пара.")
	var x=s.data.characters[a];var y=s.data.characters[b]
	if int(x.realm)!=realm:return s.result(false,"Первый кандидат должен принадлежать вашему двору.")
	if not x.alive or not y.alive or x.age<16 or y.age<16 or int(x.spouse)>=0 or int(y.spouse)>=0 or x.gender==y.gender:return s.result(false,"Для брака нужны свободные совершеннолетние жених и невеста.")
	if a in y.parents or b in x.parents or int(x.dynasty)==int(y.dynasty) or not x.parents.filter(func(p):return p in y.parents).is_empty():return s.result(false,"Близкое родство исключает брак.")
	if int(y.realm)!=realm:
		if s.at_war(realm,int(y.realm)):return s.result(false,"Брак невозможен во время войны.")
		if int(s.relation(realm,int(y.realm)).value)<-10:return s.result(false,"Сначала улучшите отношения с этой семьёй.")
	if not s.can_pay(realm,{"gold":45}):return s.result(false,"Свадьба требует 45 золота.")
	s.pay(realm,{"gold":45});x.spouse=b;y.spouse=a
	if int(y.realm)!=realm:
		var rel=s.relation(realm,int(y.realm));rel.value=mini(100,int(rel.value)+22)
		s.data.dynasties[int(x.dynasty)].links.append(int(y.dynasty));s.data.dynasties[int(y.dynasty)].links.append(int(x.dynasty))
	s.data.realms[realm].legitimacy=minf(100,s.data.realms[realm].legitimacy+4)
	return s.result(true,"Династический брак заключён: %s и %s."%[x.name,y.name])
static func child(s,mother:Dictionary,father:Dictionary):
	if not mother.alive or not father.alive or mother.age<18 or mother.age>44 or father.age<18:return
	var realm=int(father.realm);var gender="m" if s.rng.randf()<0.5 else "f"
	var c=CharacterSystem.make(s,realm,gender,0,"child",int(father.dynasty));c.parents=[father.id,mother.id];c.born_day=s.data.day
	mother.children.append(c.id);father.children.append(c.id)
	if realm==int(s.data.player):s.log_message("В доме %s родился ребёнок: %s."%[s.data.realms[realm].dynasty,c.name])
static func monthly(s):
	for c in s.data.characters.duplicate():
		if not c.alive:continue
		if c.health<=0:CharacterSystem.die(s,int(c.id));continue
		if c.gender=="f" and int(c.spouse)>=0 and c.age>=18 and c.age<=42 and c.children.size()<5:
			if s.rng.randf()<0.025:child(s,c,s.data.characters[int(c.spouse)])
	for r in s.data.realms:r.heir=next_heir(s,int(r.id))
static func nominate(s,realm:int,cid:int)->Dictionary:
	var r=s.data.realms[realm]
	if r.law!="elective":return s.result(false,"При первородстве наследник определяется старшинством.")
	if not cid in candidates(s,realm):return s.result(false,"Кандидат не имеет права наследования.")
	if not s.can_pay(realm,{"gold":30}):return s.result(false,"Для поддержки кандидата нужно 30 золота.")
	s.pay(realm,{"gold":30});r.heir=cid;r.legitimacy=maxf(0,r.legitimacy-3)
	return s.result(true,"Вы поддержали кандидата. Итог зависит от голосов дворян.")
