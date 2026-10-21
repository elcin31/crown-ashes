class_name GameClock
extends RefCounted
var speed:int=0
var accumulator:float=0.0
func advance(delta:float, campaign, commands)->int:
	if speed==0:return 0
	accumulator+=delta*speed
	var days=0
	while accumulator>=1.0 and days<8:
		accumulator-=1.0
		step(campaign,commands)
		days+=1
	return days
func step(s,commands):
	s.data.day+=1
	ConstructionSystem.daily(s)
	ArmySystem.daily(s)
	SiegeSystem.daily(s)
	IntrigueSystem.daily(s)
	RealmSystem.daily(s)
	if int(s.data.day)%7==0:AIController.military(s,commands)
	if int(s.data.day)%15==0:AIController.diplomatic(s,commands)
	if int(s.data.day)%30==0:
		EconomySystem.monthly(s)
		PopulationSystem.monthly(s)
		RealmSystem.monthly(s)
		DynastySystem.monthly(s)
		AIController.economic(s,commands)
	if s.calendar().d==1 and s.calendar().m==0:CharacterSystem.yearly(s)
	if int(s.data.day)%int(s.balance.event_interval_days)==0:EventSystem.schedule(s)
	NarrativeSystem.daily(s)
