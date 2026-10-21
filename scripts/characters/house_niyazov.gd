class_name HouseNiyazov
extends RefCounted
# Applied only to a fresh 1183 world. Existing saves retain every historical identity.
static func install(s):
	var r=s.data.realms[0];var did=int(r.dynasty_id);var d=s.data.dynasties[did]
	d.name="Ниязовы";d.english_name="House Niyazov";d.heraldry="niyazov";d.surname_m="Ниязов";d.surname_f="Ниязова"
	r.dynasty="Ниязовы";r.heraldry="niyazov";r.stability=51;r.legitimacy=62;r.personality="diplomat"
	var king=s.data.characters[int(r.ruler)];var queen=s.data.characters[int(king.spouse)];var son=s.data.characters[int(r.heir)];var sister=s.data.characters[3]
	set_person(king,"Александр I Ниязов",34,"ruler",14,13,14,10)
	king.traits=["Амбициозный","Дипломатичный","Решительный","Стратег"];king.ambition=82;king.health=90
	set_person(queen,"Елизавета Вейр",31,"spouse",5,13,15,11)
	queen.traits=["Справедливый","Харизматичный"];queen.dynasty=s.data.realms[1].dynasty_id;d.members.erase(queen.id);s.data.dynasties[int(queen.dynasty)].members.append(queen.id)
	set_person(son,"Даниил Ниязов",10,"heir",5,6,7,4);son.parents=[king.id,queen.id];son.children=[]
	set_person(sister,"София Ниязова",26,"daughter",6,11,16,10);sister.traits=["Харизматичный","Осторожный"];sister.children=[];sister.parents=[]
	king.children=[son.id];queen.children=[son.id]
	# The generated council is noble, but does not become blood relatives of the king.
	var court_did=s.data.dynasties.size();s.data.dynasties.append({"id":court_did,"name":"Тарвен","heraldry":"aurelian","head":r.council.steward,"members":[],"links":[]})
	for cid in r.council.values():
		var c=s.data.characters[int(cid)];c.dynasty=court_did;d.members.erase(cid);s.data.dynasties[court_did].members.append(cid)
	var brother=CharacterSystem.make(s,0,"m",29,"prince",did);set_person(brother,"Михаил Ниязов",29,"prince",13,10,12,14);brother.traits=["Амбициозный","Хитрый"];brother.loyalty=48;brother.ambition=88;brother.claims=[0];brother.title=0
	var cousin=CharacterSystem.make(s,0,"m",45,"duke",did);set_person(cousin,"Виктор Ниязов",45,"duke",12,14,11,12);cousin.traits=["Амбициозный","Осторожный"];cousin.loyalty=55;cousin.ambition=76;cousin.title=1;cousin.claims=[0];cousin.branch="Северная ветвь"
	var father=CharacterSystem.make(s,0,"m",64,"ancestor",did);set_person(father,"Константин III Ниязов",64,"ancestor",10,12,11,8);father.alive=false;father.death_day=-18;father.spouse=-1
	var mother=CharacterSystem.make(s,0,"f",61,"ancestor",did);set_person(mother,"Анна Ниязова",61,"ancestor",4,12,15,8);mother.alive=false;mother.death_day=-410;mother.born_day=-int(mother.age)*365-410;mother.spouse=-1
	var uncle=CharacterSystem.make(s,0,"m",81,"ancestor",did);set_person(uncle,"Борис Ниязов",81,"ancestor",9,10,10,8);uncle.alive=false;uncle.death_day=-2100;uncle.born_day=-int(uncle.age)*365-2100;uncle.spouse=-1;uncle.children=[cousin.id];cousin.parents=[uncle.id]
	var grandfather=CharacterSystem.make(s,0,"m",90,"ancestor",did);set_person(grandfather,"Юрий II Ниязов",90,"ancestor",10,10,12,8);grandfather.alive=false;grandfather.death_day=-23*365;grandfather.born_day=-113*365;grandfather.children=[father.id,uncle.id]
	father.parents=[grandfather.id];uncle.parents=[grandfather.id]
	father.children=[king.id,brother.id,sister.id];mother.children=father.children.duplicate()
	for c in [king,brother,sister]:c.parents=[father.id,mother.id];c.branch="Королевская ветвь"
	king.relationships[str(brother.id)]=5;brother.relationships[str(king.id)]=-15;cousin.relationships[str(king.id)]=0
	d.links.append(int(queen.dynasty));s.data.dynasties[int(queen.dynasty)].links.append(did)
	s.data.canon={"alexander":king.id,"elizabeth":queen.id,"daniil":son.id,"mikhail":brother.id,"sofia":sister.id,"victor":cousin.id,"previous_king":father.id,"duke":r.council.steward}
static func set_person(c:Dictionary,name:String,age:int,role:String,m:int,a:int,d:int,i:int):
	c.name=name;c.age=age;c.born_day=-age*365;c.role=role;c.martial=m;c.administration=a;c.diplomacy=d;c.intrigue=i
