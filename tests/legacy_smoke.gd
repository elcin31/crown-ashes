extends Node
# One bounded launch/story/visual pass. Uses native ScreenTouch through the GUI.
var app
var checks:int=0
var failures:int=0
var screenshots=[]
func _ready():call_deferred("run_ids" if "--id-only" in OS.get_cmdline_user_args() else "run_targeted" if "--targeted-story" in OS.get_cmdline_user_args() else "run")
func expect(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;push_error("LEGACY CHECK: "+message)
func settle():
	await get_tree().process_frame
	await get_tree().process_frame
func buttons(node:Node)->Array:
	var found=[]
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and not child.is_queued_for_deletion():found.append(child)
		found.append_array(buttons(child))
	return found
func tap_at(at:Vector2):
	var press=InputEventScreenTouch.new();press.index=0;press.position=at;press.pressed=true;Input.parse_input_event(press);Input.flush_buffered_events();await get_tree().process_frame
	press=InputEventScreenTouch.new();press.index=0;press.position=at;press.pressed=false;Input.parse_input_event(press);Input.flush_buffered_events();await settle()
func tap(prefix:String):
	var active=app.ui.modal if is_instance_valid(app.ui.modal) else app.ui.root
	for b in buttons(active):
		if not b.disabled and b.text.begins_with(prefix):
			var ancestor=b.get_parent()
			while ancestor!=null:
				if ancestor is ScrollContainer:ancestor.ensure_control_visible(b)
				ancestor=ancestor.get_parent()
			await settle();await tap_at(b.get_global_rect().get_center());return
	expect(false,"touch target exists: "+prefix)
func shot(id:String):
	await settle();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/0.3/"+id+".png");screenshots.append(id)
func run():
	await settle();DirAccess.make_dir_recursive_absolute("res://docs/screenshots/0.3")
	await shot("01_menu")
	await tap("Настройки");expect(is_instance_valid(app.ui.modal),"settings accepts touch");await tap("×")
	await tap("Новая игра");await shot("02_campaign_choice")
	await tap("Сюжетная кампания");expect(app.ui.chosen_story and app.ui.chosen_realm==0,"story selection by touch");await shot("03_selection")
	await tap("Начать кампанию");await settle();expect(app.running and int(app.state.data.player)==0,"native touch enters story campaign")
	var s=app.state;expect(NarrativeSystem.active(s),"narrative state enabled");expect(s.data.events.size()==1 and s.data.events[0].get("narrative_id","")=="n_coronation","first story event queued once")
	expect(is_instance_valid(app.ui.modal),"coronation shown");await shot("04_coronation")
	var initial_gold=float(s.data.realms[0].resources.gold);var initial_legit=float(s.data.realms[0].legitimacy)
	await tap("Подтвердить вольности")
	expect(s.data.narrative.completed.has("n_coronation"),"choice completes actual narrative event")
	expect(float(s.data.realms[0].legitimacy)==initial_legit+6,"choice changes real legitimacy")
	expect(int(s.data.narrative.variables.noble_support)==56,"choice changes noble support")
	expect(s.data.narrative.flags.get("charter",false),"branch flag persisted in state")
	expect(float(s.data.realms[0].resources.gold)==initial_gold,"charter has no invented resource cost")
	await get_tree().create_timer(.45).timeout
	await tap_at(Vector2(578,398));expect(app.ui.selected_province>=0,"map native touch selects province")
	await shot("05_map")
	await tap("Династия");await shot("06_dynasty");app.notification(NOTIFICATION_WM_GO_BACK_REQUEST);await settle();expect(app.ui.modal==null,"Android Back closes genealogy")
	await tap("История");await shot("07_history");await tap("×")
	await tap("Экономика");await tap("Низкие");expect(int(s.data.realms[0].tax)==0,"existing tax command still works by touch");await tap("×")
	await tap("☰");await tap("Сохранить");await tap("Записать");expect(SaveSystem.read_file(SaveSystem.path(1)).ok,"manual UI save")
	await tap("×");await tap("☰");await tap("Главное меню");await tap("Продолжить")
	expect(app.running and NarrativeSystem.active(app.state),"continue restores narrative campaign")
	s=app.state;expect(s.data.narrative.completed.has("n_coronation") and s.data.narrative.decisions.size()==1,"decisions restored")
	expect(s.data.narrative.flags.get("charter",false) and int(s.data.narrative.variables.noble_support)==56,"branch flags and political values restored")
	for day in range(13):app.clock.step(s,app.commands)
	expect(not s.data.events.any(func(e):return e.get("narrative_id","")=="n_coronation"),"completed coronation never repeats")
	expect(s.data.events.any(func(e):return e.get("narrative_id","")=="n_oaths"),"next chapter follows loaded progress and game days")
	var king=NarrativeSystem.actor(s,"alexander");var queen=NarrativeSystem.actor(s,"elizabeth");var child=NarrativeSystem.actor(s,"daniil")
	expect(king.name=="Александр I Ниязов" and int(king.age)==34,"canonical king identity")
	expect(int(s.data.realms[0].capital)==23 and int(s.data.provinces[23].owner)==0,"Highmere is the royal capital")
	expect(int(queen.spouse)==int(king.id) and int(queen.dynasty)!=int(king.dynasty),"queen belongs to another noble house")
	expect(int(child.id) in king.children and child.parents.size()==2 and int(child.parents[0])==int(king.id) and int(child.parents[1])==int(queen.id),"canonical reciprocal parentage")
	for c in s.data.characters:
		for pid in c.parents:expect(int(c.born_day)-int(s.data.characters[int(pid)].born_day)>=16*365,"parent is sufficiently older: "+c.name)
	var probe=GameState.new();probe.data=s.data.duplicate(true)
	var brother=NarrativeSystem.actor(probe,"mikhail");brother.loyalty=80
	expect(NarrativeSystem.possible(probe,NarrativeSystem.event_by_id("n_brothers_oath")) and not NarrativeSystem.possible(probe,NarrativeSystem.event_by_id("n_claimants")),"loyal brother gets peaceful branch")
	brother.alive=false
	expect(NarrativeSystem.possible(probe,NarrativeSystem.event_by_id("n_absent_prince")) and not NarrativeSystem.possible(probe,NarrativeSystem.event_by_id("n_claimants")),"dead brother never conducts negotiations")
	probe.data=s.data.duplicate(true);CharacterSystem.die(probe,int(king.id));NarrativeSystem.daily(probe)
	expect(int(probe.data.realms[0].ruler)==int(child.id) and probe.data.outcome=="","Alexander's death passes crown to Daniil without ending game")
	expect(probe.data.narrative.flags.get("successor_reigned",false),"story recognises succession")
	var baby_mother=NarrativeSystem.actor(probe,"elizabeth");var baby_father=NarrativeSystem.actor(probe,"mikhail");var marriage=DynastySystem.marry(probe,0,int(baby_father.id),int(baby_mother.id));expect(marriage.ok,"widowed adult can marry through existing rules");var count=probe.data.characters.size();DynastySystem.child(probe,baby_mother,baby_father)
	expect(probe.data.characters.size()==count+1 and (probe.data.characters.back().name.ends_with("Ниязов") or probe.data.characters.back().name.ends_with("Ниязова")),"new dynasty members retain gendered surname")
	probe.data=s.data.duplicate(true);var other=probe.data.characters[int(probe.data.realms[0].council.steward)];other.claims=[0];other.title=1;other.diplomacy=20;other.administration=20;other.martial=20;other.loyalty=100;probe.data.realms[0].law="elective";probe.data.realms[0].heir=other.id
	CharacterSystem.die(probe,int(king.id));NarrativeSystem.daily(probe)
	expect(int(probe.data.realms[0].dynasty_id)==int(other.dynasty) and probe.data.narrative.ending=="dynasty_lost","another eligible house can win election and end Niyazov rule")
	var legacy=SaveSystem.read_file("res://tests/fixtures/v0.1.0_save.json");expect(legacy.ok,"0.1 saves remain readable")
	if legacy.ok:
		probe.data=legacy.data;expect(not NarrativeSystem.active(probe) and probe.data.dynasties[0].name=="Валенн","legacy campaign is not renamed or forced into story")
	for resource in GameState.read_json("res://assets_manifest.json").resources:
		var texture=app.map.texture_for(resource.id);expect(texture!=null and texture.get_width()==int(resource.size[0]),"texture loads "+resource.id)
	app.return_to_menu();await tap("Новая игра");await tap("Свободная игра");await tap("Начать кампанию");expect(app.running and not NarrativeSystem.active(app.state),"free play shares engine and has no forced narrative")
	var result={"checks":checks,"failures":failures,"screenshots":screenshots,"input":"native InputEventScreenTouch through Godot GUI, desktop Xvfb","android_device_tested":false,"story_events":NarrativeSystem.book().events.size(),"legacy_save_compatible":legacy.ok,"texture_memory_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)}
	var f=FileAccess.open("res://docs/SMOKE_0.3.0.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print("LEGACY SMOKE: ",JSON.stringify(result));get_tree().quit(0 if failures==0 else 1)

func run_targeted():
	await settle();app.start_campaign(0,1,true);await settle()
	# Verify the single narrow label causing the bad story window now expands.
	var found=false
	for control in app.ui.modal.find_children("*","Label",true,false):
		if control.text.begins_with("Наследие Ниязовых · Акт"):
			found=true;expect(control.size.x>600 and control.size.y<55,"story ribbon has readable horizontal layout")
	expect(found,"story ribbon exists")
	await shot("04_coronation")
	await tap("Подтвердить вольности")
	expect(app.state.data.narrative.completed.has("n_coronation"),"choice works after layout repair")
	var result=SaveSystem.save_game(app.state,3);expect(result.ok,"targeted save")
	SaveSystem.load_game(app.state,3)
	var s=app.state;var king=NarrativeSystem.actor(s,"alexander");var queen=NarrativeSystem.actor(s,"elizabeth");var child=NarrativeSystem.actor(s,"daniil")
	expect(int(child.id) in king.children and child.parents.size()==2 and int(child.parents[0])==int(king.id) and int(child.parents[1])==int(queen.id),"parentage uses numeric IDs after JSON load")
	var victor=NarrativeSystem.actor(s,"victor");var parent=s.data.characters[int(king.parents[0])];var uncle=s.data.characters[int(victor.parents[0])]
	expect(parent.parents.size()>0 and parent.parents==uncle.parents,"cadet branch shares actual ancestors")
	for c in s.data.characters:
		for pid in c.parents:expect(int(c.born_day)-int(s.data.characters[int(pid)].born_day)>=16*365,"genealogical birth dates: "+c.name)
	var f=FileAccess.open("res://docs/TARGETED_0.3.0.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"story ribbon layout, touch choice, numeric IDs after save, connected cadet genealogy","android_device_tested":false},"  "));f.close();print("TARGETED STORY: ",checks," checks, ",failures," failures");get_tree().quit(0 if failures==0 else 1)

func run_ids():
	var result=SaveSystem.load_game(app.state,3);expect(result.ok,"existing targeted save loads")
	var s=app.state;var king=NarrativeSystem.actor(s,"alexander");var queen=NarrativeSystem.actor(s,"elizabeth");var child=NarrativeSystem.actor(s,"daniil")
	expect(int(child.id) in king.children and int(king.id) in child.parents and int(queen.id) in child.parents,"reciprocal family membership survives JSON")
	for c in s.data.characters:
		for key in ["parents","children","claims"]:
			for id in c[key]:expect(typeof(id)==TYPE_INT,"restored numeric ID type")
	expect(s.data.narrative.completed.has("n_coronation") and s.data.narrative.flags.get("charter",false),"narrative state retained")
	var legacy=SaveSystem.read_file("res://tests/fixtures/v0.1.0_save.json");SaveSystem.restore_id_arrays(legacy.data);expect(legacy.data.dynasties[0].name=="Валенн" and not legacy.data.has("narrative"),"legacy identity and campaign unchanged")
	var f=FileAccess.open("res://docs/SAVE_ID_FIX_0.3.0.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"only save ID arrays and legacy identity","android_device_tested":false},"  "));f.close();print("SAVE ID RECHECK: ",checks," checks, ",failures," failures");get_tree().quit(0 if failures==0 else 1)
