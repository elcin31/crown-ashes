class_name GameState
extends RefCounted

var data: Dictionary = {}
var buildings: Dictionary = {}
var units: Dictionary = {}
var balance: Dictionary = {}
var events: Array = []
var rng = RandomNumberGenerator.new()

func _init():
	buildings = read_json("res://data/buildings.json")
	units = read_json("res://data/units.json")
	balance = read_json("res://data/balance.json")
	events = read_json("res://data/events.json")

static func read_json(path: String):
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func new_campaign(player: int = 12, difficulty: int = 1):
	rng.seed = 1183
	var world = read_json("res://data/world.json")
	data = {"version":1,"seed":1183,"day":0,"player":player,"difficulty":difficulty,"provinces":world.provinces,"realms":world.realms,"characters":[],"dynasties":[],"armies":[],"wars":[],"reports":[],"relations":{},"events":[],"log":[],"recruitments":[],"intrigues":[],"market":{"food":1.1,"wood":1.8,"stone":2.1,"iron":3.0},"next_army":0,"next_war":0,"victory_days":0,"outcome":"","freeplay":false,"last_victory":-999,"event_history":{},"tutorial_step":0,"last_autosave":0}
	for realm in data.realms:
		var id = int(realm.id)
		realm.resources = {"gold":270.0 if id==12 else 370.0+id*20,"food":380.0 if id==12 else 900.0,"wood":115.0 if id==12 else 220.0,"stone":80.0 if id==12 else 170.0,"iron":40.0 if id==12 else 95.0,"manpower":450.0 if id==12 else 850.0}
		realm.tax = 1
		realm.law = "primogeniture"
		realm.heir = -1
		realm.claims = []
		realm.budget = {"income":0.0,"expenses":0.0,"net":0.0,"tax":0.0,"trade":0.0,"vassals":0.0,"army":0.0,"buildings":0.0,"court":0.0}
		realm.council = {}
		realm.rebel_warning = 0
		realm.independent_since = -1
		CharacterSystem.create_court(self,id)
		var army = ArmySystem.create(self,id,int(realm.capital),{"militia":90 if id==12 else 150,"spearman":30 if id==12 else 70})
		army.commander = realm.council.get("marshal",realm.ruler)
	for p in data.provinces:
		var realm=data.realms[int(p.owner)]
		p.holder = realm.council.get("steward",realm.ruler) if int(p.id)!=int(realm.capital) else realm.ruler
		if int(p.id)==23:
			p.population=6240
			p.development=38
			p.buildings={"farm":1,"fort":1,"road":1}
	for a in range(data.realms.size()):
		for b in range(a+1,data.realms.size()):
			data.relations[pair(a,b)]={"value":int(rng.randi_range(-18,25)),"alliance":false,"nap_until":0,"truce_until":0,"access":[],"cooldowns":{}}
	data.relations[pair(0,12)].value = 15
	for realm in data.realms:
		EconomySystem.forecast(self,int(realm.id))
	log_message("1183 год. Старый король Аурелии слабеет. Судьба вашей династии — в ваших руках.")

func pair(a:int,b:int)->String:
	return "%d:%d"%[mini(a,b),maxi(a,b)]
func relation(a:int,b:int)->Dictionary:
	if a==b:return {"value":100,"alliance":true,"access":[a,b],"nap_until":0,"truce_until":0,"cooldowns":{}}
	return data.relations[pair(a,b)]
func provinces_of(realm:int, include_vassals:bool=false)->Array:
	var result=[]
	for p in data.provinces:
		if int(p.owner)==realm or (include_vassals and sovereign(int(p.owner))==realm):result.append(p)
	return result
func sovereign(realm:int)->int:
	var seen=[]
	while realm>=0 and int(data.realms[realm].suzerain)>=0 and not realm in seen:
		seen.append(realm)
		realm=int(data.realms[realm].suzerain)
	return realm
func at_war(a:int,b:int)->bool:
	for w in data.wars:
		if (int(w.a)==a and int(w.b)==b) or (int(w.a)==b and int(w.b)==a):return true
	return false
func war_between(a:int,b:int)->Dictionary:
	for w in data.wars:
		if (int(w.a)==a and int(w.b)==b) or (int(w.a)==b and int(w.b)==a):return w
	return {}
func army_by_id(id:int)->Dictionary:
	for army in data.armies:
		if int(army.id)==id:return army
	return {}
func log_message(message:String):
	data.log.push_front({"day":int(data.day),"text":message})
	if data.log.size()>80:data.log.resize(80)
func date_text()->String:
	var dt=calendar()
	var months=["янв","фев","мар","апр","май","июн","июл","авг","сен","окт","ноя","дек"]
	return "%d %s %d"%[dt.d,months[dt.m],dt.y]
func calendar()->Dictionary:
	# Gregorian day lengths, including leap years; start 1 January 1183.
	var remaining=int(data.get("day",0));var year=1183
	while remaining >= (366 if is_leap(year) else 365):
		remaining-=366 if is_leap(year) else 365
		year+=1
	var lengths=[31,29 if is_leap(year) else 28,31,30,31,30,31,31,30,31,30,31];var month=0
	while remaining>=lengths[month]:
		remaining-=lengths[month]
		month+=1
	return {"d":remaining+1,"m":month,"y":year}
func is_leap(year:int)->bool:return year%4==0 and (year%100!=0 or year%400==0)
func can_pay(realm:int,cost:Dictionary)->bool:
	for key in cost:
		if float(data.realms[realm].resources.get(key,0))<float(cost[key]):return false
	return true
func pay(realm:int,cost:Dictionary):
	for key in cost:data.realms[realm].resources[key]-=cost[key]
func result(ok:bool,message:String)->Dictionary:return {"ok":ok,"message":message}
func realm_name(id:int)->String:return data.realms[id].name
