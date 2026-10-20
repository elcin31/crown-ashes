class_name IntrigueSystem
extends RefCounted
const SPECS={"gather":{"name":"Сбор сведений","gold":20,"days":18,"base":80},"bribe":{"name":"Подкуп дворянина","gold":45,"days":15,"base":70},"rumor":{"name":"Распространение слухов","gold":30,"days":22,"base":62},"plot":{"name":"Поддержка заговора","gold":60,"days":35,"base":45},"expose":{"name":"Раскрытие заговора","gold":25,"days":20,"base":72}}
static func start(s,actor:int,target:int,kind:String)->Dictionary:
	if not SPECS.has(kind) or target<0 or target>=s.data.characters.size():return s.result(false,"Некорректная операция.")
	var c=s.data.characters[target]
	if not c.alive:return s.result(false,"Персонаж умер.")
	for op in s.data.intrigues:
		if int(op.actor)==actor and int(op.target)==target:return s.result(false,"Операция против этого персонажа уже идёт.")
	var spec=SPECS[kind]
	if not s.can_pay(actor,{"gold":spec.gold}):return s.result(false,"Недостаточно золота для операции.")
	s.pay(actor,{"gold":spec.gold});s.data.intrigues.append({"actor":actor,"target":target,"kind":kind,"remaining":spec.days,"started":s.data.day})
	return s.result(true,"Операция начата: %s (%d дн.)."%[spec.name,spec.days])
static func daily(s):
	for op in s.data.intrigues.duplicate():
		op.remaining-=1
		if int(op.remaining)>0:continue
		var c=s.data.characters[int(op.target)];var actor=int(op.actor)
		if not c.alive:s.data.intrigues.erase(op);continue
		var chance=clampf(SPECS[op.kind].base+CharacterSystem.bonus(s,actor,"spymaster")*2-c.intrigue,10,95)
		var success=s.rng.randi_range(1,100)<=chance
		if success:
			match op.kind:
				"gather":
					var key=str(actor);c.secrets.append("Амбиции: %d, верность: %d"%[c.ambition,c.loyalty]);c.relationships[key]=int(c.relationships.get(key,0))-2
				"bribe":c.loyalty=minf(100,c.loyalty+22);c.relationships[str(actor)]=int(c.relationships.get(str(actor),0))+20
				"rumor":s.data.realms[int(c.realm)].legitimacy=maxf(0,s.data.realms[int(c.realm)].legitimacy-10);c.loyalty=maxf(0,c.loyalty-12)
				"plot":c.loyalty=maxf(0,c.loyalty-35);s.data.realms[int(c.realm)].stability=maxf(0,s.data.realms[int(c.realm)].stability-12)
				"expose":
					for other in s.data.intrigues.duplicate():
						if int(other.actor)!=actor and int(s.data.characters[int(other.target)].realm)==actor:s.data.intrigues.erase(other)
					s.data.realms[actor].stability=minf(100,s.data.realms[actor].stability+5);c.loyalty=minf(100,c.loyalty+6)
		if s.rng.randf()<(0.18 if success else 0.55):
			if int(c.realm)!=actor:s.relation(actor,int(c.realm)).value=maxi(-100,int(s.relation(actor,int(c.realm)).value)-18)
			s.data.realms[actor].legitimacy=maxf(0,s.data.realms[actor].legitimacy-4)
		if actor==int(s.data.player):s.log_message("%s: %s. Цель — %s."%[SPECS[op.kind].name,"успех" if success else "провал",c.name])
		s.data.intrigues.erase(op)
