class_name BattleResolver
extends RefCounted
static func power(s,a:Dictionary,enemy:Dictionary,defender:bool)->float:
	var result=0.0;var enemy_size=maxi(1,ArmySystem.size(enemy))
	for kind in a.units:
		var u=s.units[kind];var counter=1.0
		for other in enemy.units:counter+=(float(u.counters.get(other,1.0))-1.0)*float(enemy.units[other])/enemy_size
		result+=int(a.units[kind])*(float(u.attack)+float(u.defense)*0.55)*counter
	var skill=0
	if int(a.commander)>=0 and int(a.commander)<s.data.characters.size() and s.data.characters[int(a.commander)].alive:skill=s.data.characters[int(a.commander)].martial
	result*=0.55+float(a.morale)/140.0;result*=0.55+float(a.supply)/180.0;result*=1.0+skill*0.025
	if defender:
		var p=s.data.provinces[int(a.province)]
		result*=1.3 if p.terrain=="mountains" else 1.16 if p.terrain in ["hills","forest"] else 1.0
		if int(p.owner)==int(a.realm):result*=1.0+mini(3,int(p.fort))*0.06
	return result*s.rng.randf_range(0.93,1.07)
static func resolve(s,attacker:Dictionary,defender:Dictionary):
	var ap=power(s,attacker,defender,false);var dp=power(s,defender,attacker,true)
	var winner=attacker if ap>=dp else defender;var loser=defender if ap>=dp else attacker
	var ratio=maxf(ap,dp)/maxf(1,minf(ap,dp));var before_a=ArmySystem.size(attacker);var before_d=ArmySystem.size(defender)
	var winner_loss=ArmySystem.losses(winner,clampf(0.18/ratio,0.035,0.23));var loser_loss=ArmySystem.losses(loser,clampf(0.32+ratio*0.09,0.38,0.85))
	winner.morale=maxf(25,winner.morale-9);loser.morale=maxf(5,loser.morale-38)
	winner.last_battle=s.data.day;loser.last_battle=s.data.day
	var location=int(attacker.province);var war=s.war_between(int(winner.realm),int(loser.realm))
	if not war.is_empty():war.score=clampf(float(war.score)+(1 if int(war.a)==int(winner.realm) else -1)*minf(18,4+float(loser_loss)/30),-100,100)
	if ArmySystem.size(loser)<15 or not ArmySystem.retreat(s,loser):s.data.armies.erase(loser)
	var report={"day":s.data.day,"province":location,"winner":winner.realm,"loser":loser.realm,"attacker":attacker.realm,"defender":defender.realm,"before_a":before_a,"before_d":before_d,"winner_loss":winner_loss,"loser_loss":loser_loss}
	s.data.reports.push_front(report)
	if s.data.reports.size()>20:s.data.reports.resize(20)
	if int(winner.realm)==int(s.data.player):s.data.last_victory=s.data.day
	s.log_message("Битва у %s: победа %s. Потери %d / %d."%[s.data.provinces[location].name,s.realm_name(int(winner.realm)),winner_loss,loser_loss])
