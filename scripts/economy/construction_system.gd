class_name ConstructionSystem
extends RefCounted
static func build(s,id:int,pid:int,kind:String)->Dictionary:
	if pid<0 or pid>=s.data.provinces.size() or not s.buildings.has(kind):return s.result(false,"Неизвестная постройка.")
	var p=s.data.provinces[pid];var b=s.buildings[kind]
	if int(p.owner)!=id or int(p.occupation)>=0:return s.result(false,"Строить можно только в свободном собственном владении.")
	if not p.construction.is_empty():return s.result(false,"Строители уже заняты. Дождитесь завершения работ.")
	var level=int(p.buildings.get(kind,0))
	if level>=int(b.max_level):return s.result(false,"Достигнут максимальный уровень.")
	if kind=="port" and not p.coastal:return s.result(false,"Порт требует выхода к морю.")
	if kind=="mine" and not p.terrain in ["mountains","hills"]:return s.result(false,"Шахта требует гор или холмов.")
	if level==0 and p.buildings.size()>=4+int(float(p.development)/20):return s.result(false,"Нет места: повысьте развитие провинции.")
	var cost={}
	for k in b.cost:cost[k]=float(b.cost[k])*(level+1)
	if not s.can_pay(id,cost):return s.result(false,"Недостаточно ресурсов для строительства.")
	s.pay(id,cost)
	p.construction={"type":kind,"remaining":int(b.days)*(level+1),"total":int(b.days)*(level+1),"paid_by":id}
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
			p.construction={}
			if int(p.owner)==int(s.data.player):s.log_message("%s: завершено — %s."%[p.name,s.buildings[kind].name])
