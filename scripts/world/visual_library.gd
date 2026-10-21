class_name VisualLibrary
extends RefCounted
# Pure presentation rules. Never modifies campaign data or costs/effects.
const NEW_ACTORS=["royal_guard","heavy_infantry","elite_spearman","royal_archer","mounted_knight","light_cavalry","royal_messenger","village_farmer","lumberjack","blacksmith","miner","market_trader","noble_lady","noble_lord","royal_advisor","court_priest","tax_collector","village_guard","rebel_fighter","siege_engineer"]
const OLD_ACTORS=["peasant_male","peasant_female","noble_male","noble_female","courier","merchant","priest","scout","militia","infantry","spearman","archer","cavalry","crossbowman","siege_engine","bandit"]
static func building(kind:String,level:int,province:Dictionary={})->String:
	var id=int(province.get("id",0))
	match kind:
		"farm":return "large_windmill" if level>=3 else "watermill" if level>=2 and id%2==0 else "windmill" if level>=2 else "farm"
		"market":return "medieval_university" if level>=3 else "merchant_guildhall" if level>=2 else "market"
		"barracks":return "siege_workshop" if level>=3 else "royal_barracks" if level>=2 else "horse_stable" if id%3==0 else "barracks"
		"fort":return "royal_citadel" if level>=3 else "grand_stone_castle" if level>=2 else "fortified_manor"
		"temple":return "great_cathedral" if level>=3 else "monastery" if level>=2 else "temple"
		"port":return "fortified_harbor" if level>=2 else "port"
		"sawmill":return "sawmill"
		"mine":return "iron_mine"
		"quarry":return "quarry"
		"granary":return "granary"
		"road":return "stone_road"
	return "house"
static func settlement(p:Dictionary,realm:Dictionary)->String:
	if int(p.id)==int(realm.capital):
		if int(realm.title)>=3:return "royal_citadel"
		if int(realm.title)>=2:return ["royal_citadel","grand_stone_castle","royal_palace"][int(realm.id)%3]
		return "fortified_manor" if int(realm.title)==0 else "grand_castle"
	if int(p.buildings.get("fort",1))>=2:return building("fort",int(p.buildings.fort),p)
	if int(p.population)>=7600:return "walled_town"
	if float(p.development)>=42:return "noble_estate"
	if float(p.development)>=34 or int(p.population)>=6000:return "town_quarter"
	return "wooden_fort" if p.terrain=="forest" and int(p.buildings.get("fort",0))>0 else "village_cluster"
static func portrait(c:Dictionary)->String:
	var old=str(c.get("portrait","noble_mature"));var role=str(c.get("role",""));var traits=c.get("traits",[]);var age=int(c.get("age",30));var female=c.get("gender","m")=="f"
	if role=="rebel":return "portrait_rebel_pretender"
	if role=="ruler":
		if female and "Амбициозный" in traits:return "portrait_ambitious_queen"
		if not female and age>=60:return "portrait_wise_monarch"
		if not female and (int(c.get("martial",0))>=10 or age<36):return "portrait_warrior_king"
	if female and age<20:return "portrait_young_heiress"
	if role=="marshal":return "portrait_old_marshal" if age>=50 else "portrait_famous_general"
	if role=="treasurer":return "portrait_rich_merchant"
	if role=="spymaster":return "portrait_secret_councillor" if female else "portrait_treacherous_noble"
	if "Вероломный" in traits or "Хитрый" in traits:return "portrait_secret_councillor" if female else "portrait_treacherous_noble"
	if int(c.get("title",0))==1 and not female:return "portrait_arrogant_duke"
	if role in ["priest","inquisitor"] and not female:return "portrait_grim_inquisitor"
	return old
static func army_sprite(s,a:Dictionary,kind:String)->String:
	var professional=ArmySystem.size(a)>=140 and float(a.morale)>=60
	if s.data.realms[int(a.realm)].get("is_rebel",false):return "rebel_fighter"
	if not professional:return s.units[kind].asset
	return {"militia":"village_guard","infantry":"heavy_infantry","spearman":"elite_spearman","archer":"royal_archer","cavalry":"mounted_knight","crossbowman":"royal_guard","siege":"siege_engineer"}.get(kind,s.units[kind].asset)
static func formation(kind:String)->String:
	return "cavalry_formation" if kind=="cavalry" else "pike_formation" if kind=="spearman" else "archer_formation" if kind in ["archer","crossbowman"] else "infantry_formation"
static func event_picture(event_id:String,fallback:String)->String:
	return {"birth":"event_royal_marriage","marriage_offer":"event_royal_marriage","victory":"event_great_battle","peasants":"event_peasant_rebellion","vassal_betrayal":"event_noble_betrayal","plot":"event_noble_betrayal","plague":"event_medieval_plague","council_loss":"event_royal_funeral","illness":"event_medieval_plague","harvest":"event_harvest_festival","trade":"event_diplomatic_summit","insult":"event_diplomatic_summit","fire":"event_city_fire","claim":"event_royal_coronation","succession_dispute":"event_royal_coronation","refugees":"event_capital_siege","deserter":"event_capital_siege","oath":"event_empire_foundation"}.get(event_id,fallback)
