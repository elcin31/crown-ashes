class_name ConstructionSystem
extends RefCounted
static func build(s,id:int,pid:int,kind:String)->Dictionary:
	if pid<0 or pid>=s.data.provinces.size() or not s.buildings.has(kind):return s.result(false,"Неизвестная постройка.")
	var p=s.data.provinces[pid];var b=s.buildings[kind]
	if int(p.owner)!=id or int(p.occupation)>=0:return s.result(false,"Строить можно только в свободном собственном владении.")
	if not p.construction.is_empty():return s.result(false,"Строители уже заняты. Дождитесь завершения работ.")
	var level=int(p.buildings.get(kind,0))
	if level>=int(b.max_level):return s.result(false,"Достигнут максимальный уровень.")
	if kind in ["port","royal_shipyard"] and not p.coastal:return s.result(false,"Порт и верфь требуют выхода к морю.")
	if kind=="niyazov_palace" and (int(s.data.realms[id].capital)!=pid or s.data.dynasties[int(s.data.realms[id].dynasty_id)].get("english_name","")!="House Niyazov"):return s.result(false,"Дворец Ниязовых возводится только в столице этого дома.")
	if b.get("unique",false):
		for other in s.provinces_of(id):
			if int(other.buildings.get(kind,0))>0 or other.construction.get("type","")==kind:return s.result(false,"Этот династический проект уже существует или строится.")
	if kind=="mine" and not p.terrain in ["mountains","hills"]:return s.result(false,"Шахта требует гор или холмов.")
	if level==0 and p.buildings.size()>=4+int(float(p.development)/20):return s.result(false,"Нет места: повысьте развитие провинции.")
	var cost={}
	for k in b.cost:cost[k]=float(b.cost[k])*(level+1)
	if not s.can_pay(id,cost):return s.result(false,"Недостаточно ресурсов для строительства.")
	s.pay(id,cost)
	p.construction={"type":kind,"remaining":int(b.days)*(level+1),"total":int(b.days)*(level+1),"paid_by":id,"style":SettlementSystem.style_for(s,id),"dynasty":s.data.realms[id].dynasty_id}
	return s.result(true,"Начато строительство: "+b.name)
static func daily(s):
	for p in s.data.provinces:
		if p.construction.is_empty() or int(p.occupation)>=0:continue
		p.construction.remaining-=1
		if p.construction.remaining<=0:
			var kind=p.construction.type
			p.buildings[kind]=int(p.buildings.get(kind,0))+1
			if kind=="fort":p.fort=int(p.buildings[kind]);p.garrison+=45
			p.development=minf(100,p.development+1.5)
			SettlementSystem.record(s,p,kind,int(p.buildings[kind]),p.construction.get("style",SettlementSystem.style_for(s,int(p.owner))))
			var history=SettlementSystem.latest(p,kind)
			history.dynasty=int(p.construction.get("dynasty",s.data.realms[int(p.owner)].dynasty_id))
			DynastyHistory.entry(s,int(p.owner),"%s: %s, уровень %d"%[p.name,s.buildings[kind].name,p.buildings[kind]],2 if s.buildings[kind].get("unique",false) else .2)
			p.construction={}
			if int(p.owner)==int(s.data.player):s.log_message("%s: завершено — %s."%[p.name,s.buildings[kind].name])
static func restore(s,realm:int,pid:int)->Dictionary:
	if pid<0 or pid>=s.data.provinces.size():return s.result(false,"Выберите владение.")
	var p=s.data.provinces[pid]
	if int(p.owner)!=realm or int(p.occupation)>=0 or not p.siege.is_empty():return s.result(false,"Для восстановления нужен мир в собственном владении.")
	if float(p.heritage.damage)<1:return s.result(false,"Поселение не повреждено.")
	if not s.can_pay(realm,{"gold":45,"wood":10,"stone":20}):return s.result(false,"Нужно 45 золота, 10 дерева, 20 камня.")
	s.pay(realm,{"gold":45,"wood":10,"stone":20});p.heritage.damage=maxf(0,float(p.heritage.damage)-30);p.heritage.revision+=1
	if not p.settlement_houses.is_empty():
		var index=int(s.data.day)%p.settlement_houses.size();var h=p.settlement_houses[index];h.style=SettlementSystem.style_for(s,realm);h.built=s.data.day;h.dynasty=s.data.realms[realm].dynasty_id
	return s.result(true,"Восстановление оплачено. Один двор реконструирован в стиле нынешнего покровителя.")
