extends SceneTree
var failures=0
var checks=0
func _initialize():call_deferred("run")
func expect(value:bool,message:String):
	checks+=1
	if not value:failures+=1;push_error("CHECK FAILED: "+message)
func run():
	var s=GameState.new();s.new_campaign(12,1);var c=GameCommands.new(s);var clock=GameClock.new();var home_id=int(s.data.realms[12].capital)
	expect(s.data.provinces.size()==60,"60 provinces")
	expect(s.provinces_of(12).size()==1,"Rosehill one province")
	expect(float(s.data.realms[12].budget.net)>0,"affordable starting budget")
	clock.advance(5,s,c);expect(int(s.data.day)==0,"pause freezes simulation")
	var initial=float(s.data.realms[12].resources.gold)
	expect(c.execute(12,"build",{"province":home_id,"kind":"market"}).ok,"construction accepted")
	expect(float(s.data.realms[12].resources.gold)<initial,"construction paid")
	var after=float(s.data.realms[12].resources.gold)
	expect(not c.execute(12,"build",{"province":home_id,"kind":"farm"}).ok,"no double construction")
	expect(float(s.data.realms[12].resources.gold)==after,"rejected command does not charge")
	expect(c.execute(12,"recruit",{"province":home_id,"unit":"spearman"}).ok,"recruit accepted")
	for day in range(32):clock.step(s,c)
	expect(int(s.data.provinces[home_id].buildings.get("market",0))==1,"building completed with time")
	var a=s.army_by_id(12)
	expect(ArmySystem.size(a)==160,"trained soldiers join army")
	var destination=-1
	for n in s.data.provinces[home_id].neighbors:
		if s.sovereign(int(s.data.provinces[int(n)].owner))==0:destination=int(n);break
	expect(destination>=0,"reachable liege territory")
	expect(c.execute(12,"move",{"army":int(a.id),"province":destination}).ok,"move command accepted")
	for day in range(10):clock.step(s,c)
	expect(int(a.province)==destination,"movement arrives")
	var held=float(s.data.realms[12].resources.gold)
	c.execute(12,"trade",{"resource":"wood","buy":true,"amount":10});c.execute(12,"trade",{"resource":"wood","buy":false,"amount":10})
	expect(float(s.data.realms[12].resources.gold)<held,"trade spread prevents arbitrage")
	expect(c.execute(12,"diplomacy",{"target":0,"action":"improve"}).ok,"real diplomacy")
	expect(not c.execute(12,"diplomacy",{"target":0,"action":"improve"}).ok,"diplomacy cooldown")
	# A small controlled battle fixture verifies combat, siege and peace without long simulation.
	var warstate=GameState.new();warstate.new_campaign(12,1);var wc=GameCommands.new(warstate)
	warstate.data.realms[12].resources.gold=500
	var attacker=warstate.army_by_id(12);attacker.units={"infantry":350,"siege":80};attacker.province=int(warstate.data.realms[12].capital)
	expect(wc.execute(12,"war",{"target":0,"reason":"independence"}).ok,"war reason and paid declaration")
	var defender=warstate.army_by_id(0);defender.units={"militia":45};defender.province=int(warstate.data.realms[12].capital)
	BattleResolver.resolve(warstate,attacker,defender)
	expect(warstate.data.reports.size()==1 and ArmySystem.size(attacker)<430,"battle produces real losses")
	var target=int(warstate.data.realms[0].capital)
	for other in warstate.data.armies.duplicate():
		if int(other.realm)==0:warstate.data.armies.erase(other)
	expect(wc.execute(12,"move",{"army":int(attacker.id),"province":target}).ok,"wartime path")
	for day in range(65):
		warstate.data.day+=1;ArmySystem.daily(warstate);SiegeSystem.daily(warstate)
	expect(int(warstate.data.provinces[target].occupation)==12,"fort requires siege before occupation")
	expect(int(warstate.data.provinces[target].owner)==0,"occupation is not instant annexation")
	expect(wc.execute(12,"peace",{"target":0,"terms":"land"}).ok,"score-limited peace accepted")
	expect(int(warstate.data.provinces[target].owner)==12,"peace transfers land")
	expect(not wc.execute(12,"war",{"target":0,"reason":"claim"}).ok,"truce prevents repeated war")
	var oldruler=int(warstate.data.realms[12].ruler);var heir=int(warstate.data.realms[12].heir)
	CharacterSystem.die(warstate,oldruler)
	expect(int(warstate.data.realms[12].ruler)==heir and not warstate.data.characters[oldruler].alive,"death causes inheritance")
	expect(warstate.data.outcome=="","ordinary succession continues campaign")
	expect(SaveSystem.save_game(s,3).ok,"atomic manual save")
	var saved_day=int(s.data.day);var next_random=s.rng.randi();var loaded=GameState.new()
	expect(SaveSystem.load_game(loaded,3).ok,"save reload")
	expect(int(loaded.data.day)==saved_day and int(loaded.army_by_id(12).province)==destination,"date and orders preserved")
	expect(loaded.rng.randi()==next_random,"RNG state preserved")
	s.data.day+=1;expect(SaveSystem.save_game(s,3).ok,"backup on second save")
	var f=FileAccess.open(SaveSystem.path(3),FileAccess.WRITE);f.store_string("interrupted");f.close()
	expect(SaveSystem.load_game(loaded,3).ok and int(loaded.data.day)==saved_day,"corrupt primary recovers backup")
	print("MECHANICS: %d checks, %d failures, short campaign and controlled combat fixture."%[checks,failures])
	quit(0 if failures==0 else 1)
