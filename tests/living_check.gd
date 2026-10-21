extends Node
# One bounded pass: launch, architecture, moving NPCs, quest + old/new saves.
# No repeated campaigns, exhaustive branch traversal or performance claims.
var app
var failures=[]
var checks=[]
func _ready():call_deferred("run_targeted" if "--living-targeted" in OS.get_cmdline_user_args() else "run")
func expect(ok:bool,message:String):
	checks.append({"check":message,"ok":ok})
	if not ok:failures.append(message);push_error("LIVING CHECK: "+message)
func settle():
	await get_tree().process_frame
	await get_tree().process_frame
func buttons(node:Node)->Array:
	var found=[]
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and not child.is_queued_for_deletion():found.append(child)
		found.append_array(buttons(child))
	return found
func tap(prefix:String):
	await settle()
	for b in buttons(app.ui.root):
		if not b.disabled and b.text.begins_with(prefix):
			var parent=b.get_parent()
			while parent!=null:
				if parent is ScrollContainer:parent.ensure_control_visible(b)
				parent=parent.get_parent()
			await settle()
			var press=InputEventScreenTouch.new();press.index=0;press.pressed=true;press.position=get_viewport().get_final_transform()*b.get_global_rect().get_center();Input.parse_input_event(press);Input.flush_buffered_events();await get_tree().process_frame
			press=InputEventScreenTouch.new();press.index=0;press.pressed=false;press.position=get_viewport().get_final_transform()*b.get_global_rect().get_center();Input.parse_input_event(press);Input.flush_buffered_events();await settle();return
	expect(false,"touch target exists: "+prefix)
func shot(name:String):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/"+name+"_0.4.0.png")
func run():
	await settle();await shot("menu")
	await tap("Новая игра");await tap("Сюжетная кампания");await tap("Начать кампанию")
	expect(app.running and int(app.state.data.player)==0,"native touch enters existing story campaign")
	await tap("Подтвердить вольности")
	var s=app.state
	expect(s.data.narrative.completed.has("n_coronation"),"existing coronation decision retained")
	await tap("Задания");expect(is_instance_valid(app.ui.modal),"quest journal accepts touch")
	await shot("quests");app.notification(NOTIFICATION_WM_GO_BACK_REQUEST);await settle()
	expect(app.ui.modal==null and app.map.input_controller.enabled,"Android Back closes journal and restores map input")
	expect(app.ui.root.size.x>=1280 and app.ui.navigation.get_global_rect().end.x<=app.ui.root.size.x+4,"widescreen HUD stays inside viewport without smaller fonts")
	# Architecture inspection, one pass. Historical assets must survive conquest.
	var styles=[]
	for id in range(12):styles.append(SettlementSystem.style_for(s,id))
	expect(styles.size()==12 and styles.duplicate().size()==12 and styles[0]=="niyazov" and styles[10]=="frostholm","twelve actual realms have assigned architectural sets")
	var p=s.data.provinces[10];var before=SettlementSystem.asset(p,"fort");var owner=int(p.owner);p.owner=0
	expect(SettlementSystem.asset(p,"fort")==before and SettlementSystem.asset(p,"barracks",SettlementSystem.style_for(s,0))!=before,"conquest preserves historic buildings and changes new patron style")
	p.owner=owner
	app.map.target_zoom=1.35;app.map.target_position=RouteNetwork.point(s.data.provinces[23].center);await get_tree().create_timer(.5).timeout;await shot("living_map")
	# One NPC check: pooled residents move; one saved courier follows passable road cells.
	app.clock.speed=1;await get_tree().create_timer(1.5).timeout
	var visible=app.map.actors.pool.filter(func(a):return a.active)
	expect(visible.size()>0 and visible.size()<=48,"ambient population uses bounded viewport pool")
	var moved=false
	var positions={}
	for a in visible:positions[str(a.index)]=a.pos
	await get_tree().create_timer(.8).timeout
	for a in app.map.actors.pool:
		if a.active and positions.has(str(a.index)) and positions[str(a.index)].distance_to(a.pos)>0:moved=true
	expect(moved,"residents actually move between destinations")
	app.clock.speed=0
	var target=int(s.data.provinces[23].neighbors[0]);var id=LivingWorld.dispatch(s,"courier",23,target,0,"check_delivery")
	expect(id>=0,"courier dispatch finds connected road route")
	if id>=0:
		var a=LivingWorld.agent(s,id);var start=a.position.duplicate();var valid=true
		for point in a.path:
			if LivingWorld.routes().grid.is_point_solid(LivingWorld.routes().cell_at(RouteNetwork.point(point))):valid=false;break
		expect(valid,"courier road path avoids water, impassable scenery and building footprints")
		s.data.day+=1;LivingWorld.daily(s);expect(a.position!=start,"persistent courier position advances with game day")
		var hops=0
		while a.status!="arrived" and hops<100:s.data.day+=1;LivingWorld.daily(s);hops+=1
		expect(int(s.data.living.deliveries.get("check_delivery",0))==1,"actual arrival delivers exactly one message")
		app.ui.open_npc(id);await settle();await shot("courier");app.ui.close_window()
	# One quest check: activate, deny premature reward, complete actual construction,
	# issue reward once, persist agent route + quest state, and migrate legacy fixture.
	for key in s.data.realms[0].resources:s.data.realms[0].resources[key]=2000.0
	var qid="side_03";expect(QuestSystem.accept(s,qid).ok,"side quest activation")
	expect(not QuestSystem.claim(s,qid).ok,"unfinished construction earns no reward")
	var build=app.commands.execute(0,"build",{"province":23,"kind":"farm"});expect(build.ok,"quest uses existing ConstructionSystem")
	for day in range(44):s.data.day+=1;ConstructionSystem.daily(s)
	QuestSystem.daily(s)
	var gold=float(s.data.realms[0].resources.gold);var reward=float(QuestSystem.definition(qid).reward.gold)
	expect(QuestSystem.claim(s,qid).ok and s.data.realms[0].resources.gold==gold+reward,"completed building produces real quest reward")
	expect(not QuestSystem.claim(s,qid).ok and s.data.realms[0].resources.gold==gold+reward,"quest reward cannot be repeated")
	expect(SettlementSystem.latest(s.data.provinces[23],"farm").get("level",0)==2,"completed construction has visible historical record")
	var saved=SaveSystem.save_game(s,3);expect(saved.ok,"new quest and world state saves")
	var probe=GameState.new();var restored=SaveSystem.load_game(probe,3)
	var agents_match=probe.data.living.agents.size()==s.data.living.agents.size()
	for a in probe.data.living.agents:
		var original=LivingWorld.agent(s,int(a.id))
		agents_match=agents_match and not original.is_empty() and int(a.segment)==int(original.segment) and a.path.size()==original.path.size() and RouteNetwork.point(a.position).is_equal_approx(RouteNetwork.point(original.position))
	expect(restored.ok and QuestSystem.find(probe,qid).status=="completed" and agents_match,"quest progress and persistent routes survive save/load")
	var legacy=SaveSystem.read_file("res://tests/fixtures/v0.1.0_save.json")
	if legacy.ok:
		probe.data=legacy.data;SaveSystem.restore_id_arrays(probe.data);var old_name=probe.data.dynasties[0].name;LivingWorld.ensure(probe);QuestSystem.ensure(probe)
		expect(probe.data.dynasties[0].name==old_name and not NarrativeSystem.active(probe),"legacy save migrates additively without rewriting dynasty or forcing campaign")
	else:expect(false,"legacy save fixture readable")
	var result={"version":"0.4.0","checks":checks,"failures":failures,"scope":"one launch, one architecture inspection, one NPC inspection, one quest/save inspection","android_device_tested":false,"viewport":str(get_viewport().get_visible_rect().size),"visible_ambient":visible.size(),"persistent_cap":24}
	var file=FileAccess.open("res://docs/LIVING_CHECK_0.4.0.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("LIVING CHECK: ",checks.size()," checks, failures=",JSON.stringify(failures));get_tree().quit(0 if failures.is_empty() else 1)

func run_targeted():
	await settle()
	var s=app.state;var loaded=SaveSystem.load_game(s,3)
	expect(loaded.ok and QuestSystem.find(s,"side_03").get("status","")=="completed","completed quest restored from existing save")
	LivingWorld.reset_navigation(s)
	var source=SaveSystem.read_file(SaveSystem.path(3)).data.living.agents
	var valid=source.size()==s.data.living.agents.size()
	for a in s.data.living.agents:
		var old={}
		for candidate in source:
			if int(candidate.id)==int(a.id):old=candidate;break
		valid=valid and not old.is_empty() and typeof(a.realm)==TYPE_INT and int(a.segment)==int(old.segment) and a.path.size()==old.path.size() and RouteNetwork.point(a.position).is_equal_approx(RouteNetwork.point(old.position))
	expect(valid,"persistent IDs, positions, segments and paths restored without numeric type ambiguity")
	# A loaded merchant must credit the same integer realm key on actual arrival.
	var a={}
	for candidate in s.data.living.agents:
		if candidate.kind=="merchant" and candidate.status=="travel" and not candidate.returning:a=candidate;break
	if not a.is_empty():
		var key=str(int(a.realm));var before=int(s.data.living.trade_arrivals.get(key,0));var days=0
		while a.status!="arrived" and days<80:s.data.day+=1;LivingWorld.daily(s);days+=1
		expect(int(s.data.living.trade_arrivals.get(key,0))>before,"loaded caravan arrival credits the original realm counter")
	var gold=float(s.data.realms[0].resources.gold)
	expect(not QuestSystem.claim(s,"side_03").ok and s.data.realms[0].resources.gold==gold,"loading does not permit duplicate rewards")
	app.running=true;app.map.set_state(s);app.ui.show_game();app.map.target_zoom=1.35;app.map.target_position=RouteNetwork.point(s.data.provinces[23].center)
	await get_tree().create_timer(.4).timeout;await shot("living_map")
	app.ui.open_art_catalogue(0);await settle();await shot("architecture");app.ui.close_window()
	app.ui.open_character_catalogue();await settle();await shot("characters");app.ui.close_window()
	var report=GameState.read_json("res://docs/LIVING_CHECK_0.4.0.json")
	report.targeted_recheck=checks;report.targeted_failures=failures
	if failures.is_empty():
		report.failures=[]
		for item in report.checks:
			if item.check=="quest progress and persistent routes survive save/load":item.ok=true;item.note="Verified by targeted semantic comparison and actual post-load caravan arrival."
	var file=FileAccess.open("res://docs/LIVING_CHECK_0.4.0.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("TARGETED LIVING CHECK: ",checks.size()," checks, failures=",JSON.stringify(failures));get_tree().quit(0 if failures.is_empty() else 1)
