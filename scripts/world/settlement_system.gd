class_name SettlementSystem
extends RefCounted
# Save fields are additive. Visual history belongs to each completed building,
# never to the current political overlay. Legacy saves retain all old identities.
static var catalogue:Dictionary={}
const TYPES={"farm":"outbuilding","sawmill":"outbuilding","mine":"outbuilding","quarry":"outbuilding","granary":"outbuilding","road":"administration","market":"market","barracks":"barracks","fort":"castle","temple":"temple","port":"market"}
const LAYOUTS=[
 [[-63,-5],[-23,-7],[23,-9],[66,-5],[-63,-48],[-23,-50],[23,-49],[65,-47],[-62,32],[-23,32],[23,32],[64,33]],
 [[-65,-45],[-26,-47],[22,-43],[65,-42],[-66,-3],[-26,-4],[24,-2],[65,-1],[-65,35],[-25,36],[24,35],[65,36]],
 [[-60,30],[-61,-10],[-60,-50],[-21,-53],[22,-53],[63,-49],[64,-9],[64,31],[-20,32],[23,32],[-22,-9],[23,-9]],
 [[-65,32],[-24,32],[23,32],[66,32],[-65,-9],[-24,-10],[23,-9],[66,-8],[-64,-50],[-24,-50],[23,-50],[65,-50]],
 [[-63,31],[-24,32],[22,31],[65,31],[-64,-8],[-23,-10],[24,-8],[65,-10],[-62,-48],[-23,-49],[23,-48],[65,-49]],
 [[-65,32],[-25,34],[22,32],[65,32],[-65,-8],[-25,-9],[23,-8],[65,-10],[-65,-49],[-25,-49],[22,-48],[65,-49]]
]
static func book()->Dictionary:
	if catalogue.is_empty():catalogue=GameState.read_json("res://data/architecture.json")
	return catalogue
static func style_for(s,realm:int)->String:
	var r=s.data.realms[realm];var d=s.data.dynasties[int(r.dynasty_id)]
	return str(d.get("architectural_style",r.get("architectural_style","niyazov")))
static func ensure(s):
	for d in s.data.dynasties:
		if not d.has("architectural_style"):
			d.architectural_style=book().styles[int(d.id)].id if int(d.id)<12 else "niyazov"
	for r in s.data.realms:
		if not r.has("architectural_style"):r.architectural_style=book().styles[int(r.id)].id if int(r.id)<12 else "niyazov"
	for p in s.data.provinces:
		if not p.has("heritage"):
			var origin=int(p.get("country",p.owner));var style=book().styles[origin].id if origin<12 else "niyazov"
			p.heritage={"culture":book().styles[origin if origin<12 else 0].culture,"historic_style":style,"layout":layout_for(p),"records":[],"damage":0.0,"revision":0}
			for kind in p.buildings:record(s,p,kind,int(p.buildings[kind]),style,-1)
			var r=s.data.realms[int(p.owner)]
			p.heritage.residence_type="residence" if int(r.title)>=2 else "castle"
			if int(p.id)==int(r.capital):record(s,p,"residence",1,style,-1)
		if not p.has("settlement_houses"):p.settlement_houses=[]
		if not p.heritage.has("residence_type"):p.heritage.residence_type="residence" if int(s.data.realms[int(p.get("country",p.owner))].title)>=2 else "castle"
		grow_houses(s,p)
static func layout_for(p)->int:
	if p.coastal:return 5
	if p.terrain=="mountains":return 4
	if int(p.id)%7==0:return 1
	return int(p.id)%4
static func tier(p,realm)->int:
	if int(p.id)==int(realm.capital):return 4
	if int(p.population)>=7600 and float(p.development)>=35:return 3
	if int(p.population)>=6000 or float(p.development)>=34:return 2
	return 1 if int(p.population)>=3500 else 0
static func grow_houses(s,p):
	var count=[3,6,8,10,12][tier(p,s.data.realms[int(p.owner)])]
	while p.settlement_houses.size()<count:
		var i=p.settlement_houses.size();var style=p.heritage.historic_style if int(s.data.get("living_version",0))==0 else style_for(s,int(p.owner))
		var kind=["peasant","large_house","townhouse","peasant","manor","administration"][i%6]
		p.settlement_houses.append({"style":style,"type":kind,"built":s.data.day,"dynasty":s.data.realms[int(p.owner)].dynasty_id})
		p.heritage.revision+=1
static func record(s,p,kind:String,level:int,style:String="",day:int=-999999):
	if not p.has("heritage"):return
	if style=="":style=style_for(s,int(p.owner))
	if day== -999999:day=int(s.data.day)
	# Each improvement records its own patron and style; previous phases stay in history.
	p.heritage.records.append({"kind":kind,"level":level,"style":style,"built":day,"dynasty":s.data.realms[int(p.owner)].dynasty_id,"condition":100.0,"name":"Дворец Ниязовых" if kind=="residence" and style=="niyazov" else "Резиденция" if kind=="residence" else s.buildings.get(kind,{}).get("name",kind)})
	p.heritage.revision+=1
static func latest(p,kind:String)->Dictionary:
	for i in range(p.heritage.records.size()-1,-1,-1):
		if p.heritage.records[i].kind==kind:return p.heritage.records[i]
	return {}
static func asset(p,kind:String,preview_style:String="")->String:
	var r=latest(p,kind);var style=str(r.get("style",p.heritage.historic_style)) if preview_style=="" else preview_style
	if kind=="niyazov_palace":return "lk_niyazov_residence"
	if kind in book().projects:return "lk_"+kind
	if kind=="residence":return "lk_"+style+"_"+str(p.heritage.get("residence_type","residence"))
	return "lk_"+style+"_"+str(TYPES.get(kind,"outbuilding"))
static func daily(s):
	for p in s.data.provinces:
		var hurt=not p.siege.is_empty() or int(p.occupation)>=0
		var change=.7 if hurt else -.22
		var before=int(float(p.heritage.damage)/10);p.heritage.damage=clampf(float(p.heritage.damage)+change,0,95)
		if before!=int(float(p.heritage.damage)/10):p.heritage.revision+=1
		for r in p.heritage.records:r.condition=100-float(p.heritage.damage)
		if int(s.data.day)%30==0:grow_houses(s,p)
static func monthly(s):
	for realm in s.data.realms:
		var owned=s.provinces_of(int(realm.id));var administrative=0.0;var legitimacy=0.0
		for p in owned:
			if int(p.occupation)>=0:continue
			if int(p.buildings.get("niyazov_palace",0))>0:legitimacy+=.35;p.development=minf(100,p.development+.2)
			administrative+=float(p.buildings.get("royal_archive",0))*.08+float(p.buildings.get("great_library",0))*.12
			p.development=minf(100,p.development+minf(.3,administrative))
		realm.legitimacy=minf(100,realm.legitimacy+minf(.7,legitimacy))
		if legitimacy>0:
			for c in s.data.characters:
				if c.alive and int(c.realm)==int(realm.id):c.loyalty=minf(100,c.loyalty+.15)
