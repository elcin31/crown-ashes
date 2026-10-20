class_name ArmySystem
extends RefCounted
static func create(s,realm:int,province:int,composition:Dictionary)->Dictionary:
	var army={"id":int(s.data.next_army),"realm":realm,"province":province,"units":composition.duplicate(),"morale":85.0,"supply":100.0,"commander":int(s.data.realms[realm].ruler),"route":[],"travel_left":0,"travel_total":0,"order":"idle","last_battle":-999}
	s.data.next_army+=1;s.data.armies.append(army)
	return army
static func size(army:Dictionary)->int:
	var n=0
	for k in army.get("units",{}):n+=int(army.units[k])
	return n
static func strength(s,realm:int)->float:
	var total=0.0
	for a in s.data.armies:
		if int(a.realm)==realm:
			for k in a.units:total+=int(a.units[k])*s.units[k].attack
	return total
static func recruit(s,realm:int,pid:int,unit:String)->Dictionary:
	if not s.units.has(unit) or pid<0 or pid>=s.data.provinces.size():return s.result(false,"Некорректный набор.")
	var p=s.data.provinces[pid];var u=s.units[unit]
	if int(p.owner)!=realm or int(p.occupation)>=0:return s.result(false,"Набор требует собственной свободной провинции.")
	if unit in ["cavalry","crossbowman","siege"] and int(p.buildings.get("barracks",0))<1:return s.result(false,"Для этих войск нужны казармы.")
	var queued=0
	for q in s.data.recruitments:
		if int(q.province)==pid:queued+=1
	if queued>=2:return s.result(false,"Очередь набора заполнена (2 отряда).")
	if not s.can_pay(realm,u.cost):return s.result(false,"Недостаточно золота, снаряжения или резервов.")
	s.pay(realm,u.cost)
	s.data.recruitments.append({"realm":realm,"province":pid,"unit":unit,"days":int(u.days)})
	return s.result(true,"Начат набор: %s, %d воинов, %d дней."%[u.name,u.batch,u.days])
static func move(s,realm:int,id:int,target:int)->Dictionary:
	var a=s.army_by_id(id)
	if a.is_empty() or int(a.realm)!=realm:return s.result(false,"Выберите собственную армию.")
	if target<0 or target>=s.data.provinces.size():return s.result(false,"Неизвестная цель.")
	if int(a.province)==target:return s.result(false,"Армия уже находится здесь.")
	var route=ProvinceSystem.path(s,realm,int(a.province),target)
	if route.is_empty():return s.result(false,"Нет доступного пути. Требуется война, союз или военный проход.")
	a.route=route;a.order="move";set_leg(s,a)
	return s.result(true,"Армия следует в %s. Переходов: %d."%[s.data.provinces[target].name,route.size()])
static func set_leg(s,a:Dictionary):
	if a.route.is_empty():a.travel_left=0;a.travel_total=0;a.order="idle";return
	var destination=s.data.provinces[int(a.route[0])]
	var mobility=0.0;var count=maxi(1,size(a))
	for unit in a.units:mobility+=s.units[unit].mobility*int(a.units[unit])/count
	var terrain=1.6 if destination.terrain=="mountains" else 1.25 if destination.terrain in ["forest","marsh"] else 1.0
	var roads=1.0+int(destination.buildings.get("road",0))*0.15
	var days=maxi(2,int(ceil(ProvinceSystem.distance(s,int(a.province),int(destination.id))/75.0*terrain/maxf(0.5,mobility)/roads)))
	a.travel_left=days;a.travel_total=days
static func daily(s):
	for q in s.data.recruitments.duplicate():
		var p=s.data.provinces[int(q.province)]
		if int(p.owner)!=int(q.realm):
			s.data.recruitments.erase(q);continue
		if int(p.occupation)>=0:continue
		q.days-=1
		if int(q.days)>0:continue
		var target={}
		for a in s.data.armies:
			if int(a.realm)==int(q.realm) and int(a.province)==int(q.province) and a.route.is_empty():target=a;break
		if target.is_empty():target=create(s,int(q.realm),int(q.province),{})
		target.units[q.unit]=int(target.units.get(q.unit,0))+int(s.units[q.unit].batch)
		s.data.recruitments.erase(q)
	for a in s.data.armies.duplicate():
		if size(a)<=0:continue
		var realm=int(a.realm);var r=s.data.realms[realm];var p=s.data.provinces[int(a.province)];var friendly=s.sovereign(int(p.owner))==s.sovereign(realm) and int(p.occupation)<0
		var demand=float(size(a))/100.0*float(s.balance.army_food_per_100_daily)*(1.0 if friendly else 1.45)
		if float(r.resources.food)>=demand:
			r.resources.food-=demand;a.supply=minf(100,a.supply+(3 if friendly else -0.55))
		else:a.supply=maxf(0,a.supply-4)
		if float(size(a))>float(p.population)/12.0:a.supply=maxf(0,a.supply-1.2)
		if float(a.supply)<20:a.morale=maxf(5,a.morale-2.0);losses(a,0.006)
		elif friendly:a.morale=minf(100,a.morale+0.6)
		if not a.route.is_empty():
			var next=int(a.route[0]);var owner=int(s.data.provinces[next].owner)
			if not ProvinceSystem.can_enter(s,realm,owner):a.route=[];a.order="idle";continue
			a.travel_left-=1
			if int(a.travel_left)<=0:
				a.province=next;a.route.pop_front();arrive(s,a)
				if not s.army_by_id(int(a.id)).is_empty():set_leg(s,a)
		else:arrive(s,a)
	for a in s.data.armies.duplicate():
		if size(a)<5:s.data.armies.erase(a)
static func arrive(s,a:Dictionary):
	for defender in s.data.armies.duplicate():
		if int(defender.id)==int(a.id) or int(defender.province)!=int(a.province):continue
		if not defender.route.is_empty() or not s.at_war(int(a.realm),int(defender.realm)):continue
		if int(a.last_battle)==int(s.data.day) or int(defender.last_battle)==int(s.data.day):continue
		BattleResolver.resolve(s,a,defender)
		if s.army_by_id(int(a.id)).is_empty():return
	var p=s.data.provinces[int(a.province)]
	if s.at_war(int(a.realm),int(p.owner)) and size(a)>=25 and (int(p.occupation)<0 or int(p.occupation)!=int(a.realm)):
		if int(p.fort)<=0:SiegeSystem.occupy(s,p,int(a.realm))
		elif a.route.is_empty():a.order="siege"
	if int(p.owner)==int(a.realm) and int(p.occupation)>=0:
		p.occupation=-1;p.siege={}
static func losses(a:Dictionary,fraction:float)->int:
	var lost=0
	for unit in a.units.keys():
		var casualties=mini(int(a.units[unit]),maxi(0,int(ceil(float(a.units[unit])*fraction))))
		a.units[unit]-=casualties;lost+=casualties
		if int(a.units[unit])<=0:a.units.erase(unit)
	return lost
static func split(s,realm:int,id:int)->Dictionary:
	var a=s.army_by_id(id)
	if a.is_empty() or int(a.realm)!=realm or not a.route.is_empty():return s.result(false,"Разделить можно собственную неподвижную армию.")
	if size(a)<40:return s.result(false,"Нужно не менее 40 воинов.")
	var half={}
	for k in a.units:
		half[k]=int(a.units[k])/2;a.units[k]-=int(half[k])
	var child=create(s,realm,int(a.province),half);child.morale=a.morale;child.supply=a.supply
	return s.result(true,"Армия разделена на два отряда.")
static func merge(s,realm:int,id:int)->Dictionary:
	var a=s.army_by_id(id)
	if a.is_empty() or int(a.realm)!=realm or not a.route.is_empty():return s.result(false,"Выберите неподвижную армию.")
	var merged=0
	for other in s.data.armies.duplicate():
		if int(other.id)==id or int(other.realm)!=realm or int(other.province)!=int(a.province) or not other.route.is_empty():continue
		var count=size(a)+size(other)
		a.morale=(a.morale*size(a)+other.morale*size(other))/maxi(1,count);a.supply=minf(a.supply,other.supply)
		for k in other.units:a.units[k]=int(a.units.get(k,0))+int(other.units[k])
		s.data.armies.erase(other);merged+=1
	return s.result(merged>0,"Армии объединены." if merged>0 else "Рядом нет другой собственной армии.")
static func retreat(s,a:Dictionary)->bool:
	var realm=int(a.realm)
	for neighbor in s.data.provinces[int(a.province)].neighbors:
		var p=s.data.provinces[int(neighbor)]
		if s.sovereign(int(p.owner))!=s.sovereign(realm) or int(p.occupation)>=0:continue
		var enemy=false
		for other in s.data.armies:
			if int(other.province)==int(neighbor) and s.at_war(realm,int(other.realm)):enemy=true
		if enemy:continue
		a.province=int(neighbor);a.route=[];a.order="idle";a.morale=maxf(18,a.morale);a.supply=maxf(20,a.supply);return true
	return false
