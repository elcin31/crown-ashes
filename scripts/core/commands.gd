class_name GameCommands
extends RefCounted
var s
func _init(state):s=state
func execute(actor:int,command:String,args:Dictionary={})->Dictionary:
	if actor<0 or actor>=s.data.realms.size():return s.result(false,"Неизвестное владение.")
	match command:
		"build":return ConstructionSystem.build(s,actor,int(args.get("province",-1)),args.get("kind",""))
		"recruit":return ArmySystem.recruit(s,actor,int(args.get("province",-1)),args.get("unit",""))
		"move":return ArmySystem.move(s,actor,int(args.get("army",-1)),int(args.get("province",-1)))
		"split":return ArmySystem.split(s,actor,int(args.get("army",-1)))
		"merge":return ArmySystem.merge(s,actor,int(args.get("army",-1)))
		"cancel":
			var a=s.army_by_id(int(args.get("army",-1)))
			if a.is_empty() or int(a.realm)!=actor:return s.result(false,"Выберите свою армию.")
			a.route=[];a.travel_left=0;a.travel_total=0;a.order="idle";return s.result(true,"Приказ отменён. Армия остаётся в исходной провинции.")
		"retreat":
			var a=s.army_by_id(int(args.get("army",-1)))
			if a.is_empty() or int(a.realm)!=actor:return s.result(false,"Выберите свою армию.")
			if ArmySystem.retreat(s,a):return s.result(true,"Армия отступила на дружественную территорию.")
			return s.result(false,"Нет безопасного пути отступления.")
		"disband":
			var a=s.army_by_id(int(args.get("army",-1)))
			if a.is_empty() or int(a.realm)!=actor or not a.route.is_empty():return s.result(false,"Распустить можно собственную неподвижную армию.")
			if s.at_war(actor,int(s.data.provinces[int(a.province)].owner)):return s.result(false,"Нельзя распустить армию на вражеской территории.")
			s.data.realms[actor].resources.manpower+=int(ArmySystem.size(a)*0.65);s.data.armies.erase(a);return s.result(true,"Армия распущена; 65% воинов вернулись в резерв.")
		"commander":
			var a=s.army_by_id(int(args.get("army",-1)));var cid=int(args.get("character",-1))
			if a.is_empty() or int(a.realm)!=actor or cid<0 or cid>=s.data.characters.size():return s.result(false,"Некорректное назначение.")
			var c=s.data.characters[cid]
			if not c.alive or c.age<16 or int(c.realm)!=actor:return s.result(false,"Нужен взрослый живой командующий вашего двора.")
			a.commander=cid;return s.result(true,"Командующий назначен.")
		"trade":return EconomySystem.trade(s,actor,args.get("resource",""),bool(args.get("buy",true)),int(args.get("amount",0)))
		"tax":
			var level=int(args.get("level",-1))
			if level<0 or level>2:return s.result(false,"Некорректная ставка налога.")
			s.data.realms[actor].tax=level;EconomySystem.forecast(s,actor);return s.result(true,"Налоги: "+["низкие","обычные","высокие"][level])
		"diplomacy":return DiplomacySystem.act(s,actor,int(args.get("target",-1)),args.get("action",""))
		"war":return WarSystem.declare(s,actor,int(args.get("target",-1)),args.get("reason","claim"))
		"peace":return WarSystem.peace(s,actor,int(args.get("target",-1)),args.get("terms","white"))
		"marry":return DynastySystem.marry(s,actor,int(args.get("a",-1)),int(args.get("b",-1)))
		"appoint":return CharacterSystem.appoint(s,actor,args.get("slot",""),int(args.get("character",-1)))
		"heir":return DynastySystem.nominate(s,actor,int(args.get("character",-1)))
		"law":return RealmSystem.law(s,actor,args.get("law",""))
		"title":return RealmSystem.title(s,actor)
		"intrigue":return IntrigueSystem.start(s,actor,int(args.get("character",-1)),args.get("kind",""))
		"event":return EventSystem.choose(s,int(args.get("index",0)),int(args.get("choice",0)))
		"grant":
			var pid=int(args.get("province",-1));var cid=int(args.get("character",-1))
			if pid<0 or pid>=s.data.provinces.size() or cid<0 or cid>=s.data.characters.size():return s.result(false,"Выберите владение и дворянина.")
			var p=s.data.provinces[pid];var c=s.data.characters[cid];var r=s.data.realms[actor]
			if int(p.owner)!=actor or int(p.occupation)>=0 or int(p.id)==int(r.capital):return s.result(false,"Нельзя передать столицу, чужую или занятую провинцию.")
			if not c.alive or int(c.realm)!=actor or c.age<16:return s.result(false,"Нужен взрослый дворянин вашего двора.")
			if int(p.holder)==cid:return s.result(false,"Этот дворянин уже владеет провинцией.")
			var previous=int(p.holder)
			if previous>=0 and previous!=int(r.ruler):s.data.characters[previous].loyalty=maxf(0,s.data.characters[previous].loyalty-18);r.legitimacy=maxf(0,r.legitimacy-5)
			p.holder=cid;c.loyalty=minf(100,c.loyalty+16)
			var holdings=0
			for owned in s.provinces_of(actor):
				if int(owned.holder)==cid:holdings+=1
			c.title=1 if holdings>=3 and int(r.title)>=2 else 0
			return s.result(true,"Владение передано дворянину. Его верность влияет на риск мятежа.")
		"develop":
			var pid=int(args.get("province",-1))
			if pid<0 or pid>=s.data.provinces.size():return s.result(false,"Выберите провинцию.")
			var p=s.data.provinces[pid]
			if int(p.owner)!=actor or int(p.occupation)>=0:return s.result(false,"Это не свободная собственная провинция.")
			if p.development>=100:return s.result(false,"Развитие достигло максимума.")
			if not s.can_pay(actor,{"gold":65,"wood":15,"stone":15}):return s.result(false,"Нужно 65 золота, 15 дерева и 15 камня.")
			s.pay(actor,{"gold":65,"wood":15,"stone":15});p.development=minf(100,p.development+5);return s.result(true,"Развитие провинции повышено на 5.")
	return s.result(false,"Неизвестная команда.")
