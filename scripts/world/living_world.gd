class_name LivingWorld
extends RefCounted
# Persistent agents use game days and the same road network as visible actors.
# Ambient actors are a bounded renderer pool and never enter save data.
static var network:RouteNetwork
static func routes()->RouteNetwork:
	if network==null:network=RouteNetwork.new()
	return network
static func ensure(s):
	if not s.data.has("living"):s.data.living={"agents":[],"next_id":0,"deliveries":{},"trade_arrivals":{},"cooldowns":{},"revision":0}
	SettlementSystem.ensure(s);DynastyHistory.ensure(s);s.data.living_version=1
static func reset_navigation(s):routes().block_buildings(s)
static func agent(s,id:int)->Dictionary:
	for a in s.data.living.agents:
		if int(a.id)==id:return a
	return {}
static func dispatch(s,kind:String,start:int,target:int,realm:int,quest:String="",character:int=-1,cargo:Dictionary={})->int:
	if s.data.living.agents.size()>=24 or start<0 or target<0 or start>=s.data.provinces.size() or target>=s.data.provinces.size():return -1
	var path=routes().journey(s,realm,start,target,kind)
	if path.size()<2:return -1
	var id=int(s.data.living.next_id);s.data.living.next_id+=1
	var names={"courier":"Королевский курьер","merchant":"Караван торговой гильдии","diplomat":"Посланник короны","noble":"Дворянский кортеж","priest":"Паломник"}
	var a={"id":id,"kind":kind,"name":s.data.characters[character].name if character>=0 else names.get(kind,kind),"realm":realm,"province":start,"origin":start,"target":target,"path":path,"segment":0,"position":path[0].duplicate(),"status":"travel","quest":quest,"character":character,"cargo":cargo,"created":s.data.day,"arrived":-1,"returning":false,"wait":0,"message":"Письмо из Вейрмарка: соперники короны собирают поддержку северной ветви." if quest=="main_04" else "Поручение доставлено. Канцелярия внесла запись в журнал."}
	s.data.living.agents.append(a)
	return id
static func interpolated(a:Dictionary,fraction:float)->Vector2:
	var pos=RouteNetwork.point(a.position)
	if a.status!="travel":return pos
	var index=int(a.segment);var budget=speed(a)*fraction
	while budget>0 and index<a.path.size()-1:
		var next=RouteNetwork.point(a.path[index+1]);var dist=pos.distance_to(next)
		if dist>budget:return pos.move_toward(next,budget)
		budget-=dist;pos=next;index+=1
	return pos
static func speed(a)->float:return 22.0 if a.kind=="courier" else 10.0 if a.kind=="merchant" else 14.0
static func danger(s,p)->bool:return not p.siege.is_empty() or int(p.occupation)>=0 or float(p.unrest)>65
static func daily(s):
	var living=s.data.living
	for a in living.agents.duplicate():
		if int(a.character)>=0 and not s.data.characters[int(a.character)].alive:a.status="cancelled"
		if a.status=="cancelled":living.agents.erase(a);continue
		if a.status=="arrived":
			if int(s.data.day)-int(a.arrived)<6:continue
			if not a.returning:
				var back=routes().journey(s,int(a.realm),int(a.target),int(a.origin),a.kind)
				if back.size()>1:a.path=back;a.segment=0;a.position=back[0].duplicate();a.returning=true;a.status="travel";continue
			living.agents.erase(a);continue
		var pos=RouteNetwork.point(a.position);var nearest=int(a.province);var best=INF
		for p in s.data.provinces:
			var d=pos.distance_squared_to(RouteNetwork.point(p.center))
			if d<best:best=d;nearest=int(p.id)
		a.province=nearest
		var p=s.data.provinces[nearest];var owner=int(p.owner)
		if not routes().passage(s,int(a.realm),owner,a.kind) or (a.kind=="merchant" and not a.returning and danger(s,p)):
			a.status="blocked";a.wait+=1
			var escorted=s.data.armies.any(func(army):return int(army.realm)==int(a.realm) and int(army.province)==nearest and ArmySystem.size(army)>=80)
			if a.kind=="merchant" and float(p.unrest)>65 and not escorted and not a.get("robbed",false):
				var loss=minf(8,maxf(0,s.data.realms[int(a.realm)].resources.gold));s.data.realms[int(a.realm)].resources.gold-=loss
				a.robbed=true;a.message="Разбойники захватили часть товаров: потеряно %d золота. Караван ищет путь отступления."%int(loss)
				if int(a.realm)==int(s.data.player):s.log_message(a.message+" "+p.name)
			if a.get("robbed",false) and int(a.wait)>=10 and not a.returning:
				var retreat=routes().journey(s,int(a.realm),nearest,int(a.origin),a.kind)
				if retreat.size()>1:
					var connector=routes().local_path(pos,RouteNetwork.point(retreat[0]))
					if connector.size()>0:a.path=connector+retreat;a.segment=0;a.returning=true;a.status="travel";a.wait=0
			if int(a.wait)%7==0:
				var replacement=routes().journey(s,int(a.realm),nearest,int(a.origin) if a.returning else int(a.target),a.kind)
				if replacement.size()>1:
					var connector=routes().local_path(pos,RouteNetwork.point(replacement[0]))
					if connector.size()>0:a.path=connector+replacement;a.segment=0;a.wait=0;a.status="travel"
			if int(a.wait)>90:
				s.log_message(a.name+": маршрут отменён из-за закрытых дорог.");a.status="cancelled"
			continue
		a.status="travel";a.wait=0
		var destination=s.data.provinces[int(a.origin) if a.returning else int(a.target)]
		if s.provinces_of(int(destination.owner)).is_empty():a.status="cancelled";continue
		var budget=speed(a)
		while budget>0 and int(a.segment)<a.path.size()-1:
			var next=RouteNetwork.point(a.path[int(a.segment)+1]);var dist=pos.distance_to(next)
			if dist>budget:pos=pos.move_toward(next,budget);budget=0
			else:pos=next;budget-=dist;a.segment+=1
		a.position=[pos.x,pos.y]
		if int(a.segment)>=a.path.size()-1:
			a.status="arrived";a.arrived=s.data.day;a.province=int(a.origin) if a.returning else int(a.target)
			if not a.returning:
				if a.quest!="":living.deliveries[a.quest]=int(living.deliveries.get(a.quest,0))+1
				if a.kind=="merchant":
					var key=str(int(a.realm));living.trade_arrivals[key]=int(living.trade_arrivals.get(key,0))+1
					# Small real trade turnover; cancelled and blocked caravans earn nothing.
					s.data.realms[int(a.realm)].resources.gold+=3
				for resource in a.cargo:s.data.realms[int(destination.owner)].resources[resource]+=a.cargo[resource]
				if int(a.realm)==int(s.data.player) or a.quest!="":s.log_message(a.name+": прибыл в "+destination.name)
	if int(s.data.day)%12==1:spawn_trade(s)
static func spawn_trade(s):
	# Stable capitals produce more departures. War/revolt reduces the same real traffic.
	for r in s.data.realms:
		var realm=int(r.id);var owned=s.provinces_of(realm)
		if owned.is_empty() or r.get("is_rebel",false) or float(r.stability)<35:continue
		var count=s.data.living.agents.filter(func(a):return a.kind=="merchant" and int(a.realm)==realm).size()
		if count>= (2 if r.budget.net>10 else 1):continue
		var origin=int(r.capital)
		if danger(s,s.data.provinces[origin]):continue
		var candidates=[]
		for road in routes().graph.get(origin,[]):
			var pid=int(road.b) if int(road.a)==origin else int(road.a);var p=s.data.provinces[pid]
			if not danger(s,p) and not s.at_war(realm,int(p.owner)):candidates.append(pid)
		if not candidates.is_empty():dispatch(s,"merchant",origin,int(candidates[(int(s.data.day)/12+realm)%candidates.size()]),realm)
