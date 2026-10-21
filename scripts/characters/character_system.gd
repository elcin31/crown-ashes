class_name CharacterSystem
extends RefCounted
const TRAITS=["Амбициозный","Справедливый","Жестокий","Щедрый","Осторожный","Храбрый","Хитрый","Вероломный","Харизматичный","Жадный"]
const MALE=["Аларик","Роланд","Эдрик","Гарет","Леофрик","Освин","Дариан","Теобальд","Эммерик","Конрад","Бальдур","Меррик","Седрик","Артур","Элиас","Годфри"]
const FEMALE=["Элеонора","Изольда","Аделина","Розалин","Сибилла","Матильда","Беатриса","Агнесса","Эвелина","Ингрид","Фрейя","Мириэль","Клара","Эмма"]
static func make(s,realm:int,gender:String,age:int,role:String,dynasty:int=-1)->Dictionary:
	var r=s.data.realms[realm];var id=s.data.characters.size()
	if dynasty<0:dynasty=int(r.dynasty_id)
	var list=MALE if gender=="m" else FEMALE
	var name=list[(id+realm*3)%list.size()]
	var family=s.data.dynasties[dynasty]
	if family.has("surname_m"):name+=" "+str(family.surname_m if gender=="m" else family.surname_f)
	var portraits={"ruler":"king_old" if age>55 else "king_mature" if age>35 else "king_young","spouse":"queen_mature" if age>35 else "queen_young","heir":"noble_young","daughter":"noblewoman_young","chancellor":"noble_mature","treasurer":"steward","marshal":"commander_veteran","spymaster":"spymaster","steward":"steward","child":"noble_young" if gender=="m" else "noblewoman_young"}
	var char={"id":id,"name":name,"realm":realm,"age":age,"gender":gender,"dynasty":dynasty,"portrait":portraits.get(role,"noble_mature"),"traits":[TRAITS[s.rng.randi_range(0,9)],TRAITS[s.rng.randi_range(0,9)]],"martial":s.rng.randi_range(3,15),"administration":s.rng.randi_range(3,15),"diplomacy":s.rng.randi_range(3,15),"intrigue":s.rng.randi_range(3,15),"loyalty":s.rng.randi_range(58,85),"ambition":s.rng.randi_range(20,80),"health":90,"alive":true,"spouse":-1,"parents":[],"children":[],"role":role,"relationships":{},"title":0,"claims":[],"born_day":-age*365,"death_day":-1,"secrets":[]}
	if "Амбициозный" in char.traits:char.ambition=90
	if "Харизматичный" in char.traits:char.diplomacy+=3
	if "Храбрый" in char.traits:char.martial+=3
	if "Хитрый" in char.traits:char.intrigue+=3
	s.data.characters.append(char);s.data.dynasties[dynasty].members.append(id)
	return char
static func create_court(s,realm:int):
	var r=s.data.realms[realm];var did=s.data.dynasties.size();r.dynasty_id=did
	s.data.dynasties.append({"id":did,"name":r.dynasty,"heraldry":r.heraldry,"head":-1,"members":[],"links":[]})
	var ruler=make(s,realm,"m",68 if realm==0 else 32 if realm==12 else 37+realm%14,"ruler")
	var spouse=make(s,realm,"f",55 if realm==0 else 30 if realm==12 else ruler.age-4,"spouse")
	ruler.spouse=spouse.id;spouse.spouse=ruler.id;ruler.title=r.title;r.ruler=ruler.id
	s.data.dynasties[did].head=ruler.id
	var heir=make(s,realm,"m",36 if realm==0 else 12 if realm==12 else 17,"heir")
	var daughter=make(s,realm,"f",28 if realm==0 else 7 if realm==12 else 14,"daughter")
	for child in [heir,daughter]:
		child.parents=[ruler.id,spouse.id];ruler.children.append(child.id);spouse.children.append(child.id)
	r.heir=heir.id
	for slot in ["chancellor","treasurer","marshal","spymaster","steward"]:
		var advisor=make(s,realm,"m" if slot!="chancellor" else "f",s.rng.randi_range(27,62),slot)
		advisor.title=1 if slot=="steward" else 0;r.council[slot]=advisor.id
	if realm==12:ruler.name="Эдрик";spouse.name="Аделина";heir.name="Роланд";daughter.name="Эвелина"
static func bonus(s,realm:int,slot:String)->float:
	var id=int(s.data.realms[realm].council.get(slot,-1))
	if id<0 or id>=s.data.characters.size():return 0.0
	var c=s.data.characters[id]
	if not c.alive or int(c.age)<16:return 0.0
	var skill="diplomacy" if slot=="chancellor" else "martial" if slot=="marshal" else "intrigue" if slot=="spymaster" else "administration"
	return float(c[skill])*(0.65+float(c.loyalty)/280.0)+(2 if slot=="treasurer" and "Жадный" in c.traits else 0)
static func appoint(s,realm:int,slot:String,cid:int)->Dictionary:
	if not slot in ["chancellor","treasurer","marshal","spymaster","steward"] or cid<0 or cid>=s.data.characters.size():return s.result(false,"Некорректное назначение.")
	var c=s.data.characters[cid];var r=s.data.realms[realm]
	if not c.alive or int(c.realm)!=realm or int(c.age)<16 or int(c.id)==int(r.ruler):return s.result(false,"Кандидат должен быть взрослым живым придворным.")
	var old=int(r.council.get(slot,-1))
	if old==cid:return s.result(false,"Этот советник уже занимает должность.")
	for office in r.council.keys():
		if int(r.council[office])==cid:r.council.erase(office)
	if old>=0:s.data.characters[old].loyalty=maxf(0,s.data.characters[old].loyalty-8)
	r.council[slot]=cid;c.loyalty=minf(100,c.loyalty+10)
	return s.result(true,"Назначение в совет выполнено.")
static func yearly(s):
	for c in s.data.characters:
		if not c.alive:continue
		c.age+=1
		if c.age>=56 and s.rng.randf()<minf(0.85,(float(c.age)-53)*0.018):die(s,int(c.id))
		elif c.age>=16 and c.role=="child":c.portrait="noble_young" if c.gender=="m" else "noblewoman_young"
static func die(s,cid:int):
	var c=s.data.characters[cid]
	if not c.alive:return
	c.alive=false;c.death_day=s.data.day
	if int(c.spouse)>=0:s.data.characters[int(c.spouse)].spouse=-1;c.spouse=-1
	var realm=int(c.realm);var r=s.data.realms[realm]
	for slot in r.council.keys():
		if int(r.council[slot])==cid:r.council.erase(slot)
	for army in s.data.armies:
		if int(army.commander)==cid:army.commander=-1
	s.log_message("%s из дома %s умер(ла) в возрасте %d лет."%[c.name,s.data.dynasties[int(c.dynasty)].name,c.age])
	if int(r.ruler)==cid:DynastySystem.succeed(s,realm)
