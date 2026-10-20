class_name EconomySystem
extends RefCounted
static func production(s,p:Dictionary)->Dictionary:
	var terrain={"plains":{"food":38.0,"wood":5.0,"stone":2.0,"iron":1.0},"forest":{"food":18.0,"wood":25.0,"stone":3.0,"iron":1.0},"hills":{"food":22.0,"wood":8.0,"stone":12.0,"iron":5.0},"mountains":{"food":10.0,"wood":4.0,"stone":20.0,"iron":12.0},"marsh":{"food":16.0,"wood":15.0,"stone":2.0,"iron":2.0}}
	var out=terrain[p.terrain].duplicate();out.gold=0.0;out.manpower=16.0
	for key in p.buildings:
		for resource in s.buildings[key].effect:
			if out.has(resource):out[resource]+=s.buildings[key].effect[resource]*p.buildings[key]
	var factor=(0.55+float(p.development)/85.0)*(0.6+float(p.population)/12000.0)*(1.0-float(p.unrest)/170.0)
	if int(p.occupation)>=0:factor*=0.25
	if int(p.epidemic)>0:factor*=0.65
	for key in out:out[key]=maxf(0,float(out[key])*factor)
	return out
static func forecast(s,id:int)->Dictionary:
	var r=s.data.realms[id];var tax=0.0;var trade=0.0;var upkeep=0.0
	for p in s.provinces_of(id):
		var prod=production(s,p)
		tax+=float(p.population)/340.0*(0.65+float(p.development)/100.0)*[0.65,1.0,1.4][int(r.tax)]*(1.0-float(p.unrest)/130.0)
		trade+=prod.gold
		for k in p.buildings:upkeep+=s.buildings[k].upkeep*p.buildings[k]
	var army_up=0.0
	for a in s.data.armies:
		if int(a.realm)!=id:continue
		for u in a.units:army_up+=float(a.units[u])/40.0*s.units[u].upkeep
	var court=5.0+float(s.provinces_of(id).size())*0.4
	var tribute=0.0
	for other in s.data.realms:
		if int(other.suzerain)==id:tribute+=maxf(0,float(other.budget.get("income",0)))*0.12
	var outgoing=(tax+trade)*0.12 if int(r.suzerain)>=0 else 0.0
	var bonus=CharacterSystem.bonus(s,id,"treasurer")
	tax*=1.0+bonus*0.007
	r.budget={"income":tax+trade+tribute,"expenses":army_up+upkeep+court+outgoing,"net":tax+trade+tribute-army_up-upkeep-court-outgoing,"tax":tax,"trade":trade,"vassals":tribute-outgoing,"army":army_up,"buildings":upkeep,"court":court}
	return r.budget
static func monthly(s):
	for r in s.data.realms:
		var id=int(r.id);var b=forecast(s,id)
		r.resources.gold+=b.net
		for p in s.provinces_of(id):
			var prod=production(s,p)
			for k in ["food","wood","stone","iron","manpower"]:r.resources[k]+=prod[k]
			r.resources.food-=float(p.population)/130.0
		var cap=2500.0+float(s.provinces_of(id).size())*1100.0
		for p in s.provinces_of(id):cap+=float(p.buildings.get("granary",0))*200.0
		for k in ["food","wood","stone","iron"]:r.resources[k]=clampf(r.resources[k],0,cap)
		r.resources.manpower=clampf(r.resources.manpower,0,600+s.provinces_of(id).size()*650)
		if float(r.resources.gold)<0:
			r.stability=maxf(0,r.stability-6)
			for a in s.data.armies:
				if int(a.realm)==id:a.morale=maxf(5,a.morale-12);ArmySystem.losses(a,0.04)
			r.resources.gold=maxf(-200,r.resources.gold)
			if id==int(s.data.player):s.log_message("Казна пуста: жалованье задержано, солдаты дезертируют.")
		if float(r.resources.food)<=0:
			r.stability=maxf(0,r.stability-5)
			if id==int(s.data.player):s.log_message("Голод: население и мораль войск сокращаются. Купите продовольствие.")
		for k in s.data.market:s.data.market[k]=clampf(s.data.market[k]*0.985+{"food":1.1,"wood":1.8,"stone":2.1,"iron":3.0}[k]*0.015,0.5,6)
static func trade(s,id:int,resource:String,buy:bool,amount:int)->Dictionary:
	if not resource in ["food","wood","stone","iron"] or amount<=0 or amount>500:return s.result(false,"Некорректный торговый приказ.")
	var owned=s.provinces_of(id);var access=false
	for p in owned:
		if int(p.occupation)<0:access=true
	if not access:return s.result(false,"Все торговые пути блокированы оккупацией.")
	var price=float(s.data.market[resource])*(1.0+float(s.balance.trade_spread) if buy else 1.0-float(s.balance.trade_spread))
	var cost={"gold":price*amount} if buy else {resource:amount}
	if not s.can_pay(id,cost):return s.result(false,"Недостаточно средств или товара.")
	s.pay(id,cost)
	if buy:s.data.realms[id].resources[resource]+=amount
	else:s.data.realms[id].resources.gold+=price*amount
	s.data.market[resource]=clampf(s.data.market[resource]*(1.0+(amount*0.0005 if buy else -amount*0.0005)),0.5,6)
	return s.result(true,"Сделка завершена: %d ед. за %.0f золота."%[amount,price*amount])
