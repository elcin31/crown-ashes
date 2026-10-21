extends Node
# One campaign and one short set of aspect-ratio checks. No long simulation.
var app
var checks:int=0
var failures:int=0
var sizes=[]
var captures=[]
func _ready():call_deferred("recheck_hit_areas" if "--hit-check" in OS.get_cmdline_user_args() else "recheck_layout" if "--layout-recheck" in OS.get_cmdline_user_args() else "run")
func expect(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;push_error("MOBILE CHECK: "+message)
func settle():
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
func buttons(node:Node)->Array:
	var result=[]
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and not child.is_queued_for_deletion():result.append(child)
		result.append_array(buttons(child))
	return result
func tap_at(at:Vector2):
	var event=InputEventScreenTouch.new();event.index=0;event.position=get_viewport().get_final_transform()*at;event.pressed=true;Input.parse_input_event(event);Input.flush_buffered_events();await get_tree().process_frame
	event=InputEventScreenTouch.new();event.index=0;event.position=get_viewport().get_final_transform()*at;event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events();await settle()
func tap(prefix:String):
	var active=app.ui.modal if is_instance_valid(app.ui.modal) else app.ui.root
	for b in buttons(active):
		if not b.disabled and b.text.begins_with(prefix):
			var parent=b.get_parent()
			while parent!=null:
				if parent is ScrollContainer:parent.ensure_control_visible(b)
				parent=parent.get_parent()
			await settle();await tap_at(b.get_global_rect().get_center());return
	expect(false,"visible touch target: "+prefix)
func screenshot(name:String):
	await settle();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/0.3.1/"+name+".png");captures.append(name)
func within(child:Control,parent:Control,margin:float=2.0)->bool:
	return parent.get_global_rect().grow(margin).encloses(child.get_global_rect())
func check_layout(width:int):
	var viewport=get_viewport().get_visible_rect().size;var root=app.ui.root;var side=app.ui.side
	expect(absf(viewport.x/viewport.y-float(width)/1080)<.015,"expanded viewport matches display aspect: "+str(width))
	expect(root.size.x>=1270,"logical landscape width remains available")
	for panel in [app.ui.top_bar,app.ui.bottom_bar,side,app.ui.minimap_panel,app.ui.notice_panel]:expect(within(panel,root),"HUD panel stays inside safe canvas "+str(width)+" "+str(panel.get_global_rect()))
	expect(app.ui.top_bar.size.y<=102,"top bar remains compact")
	expect(app.ui.bottom_bar.size.y<=82,"navigation remains compact")
	expect(side.size.x/root.size.x<=.30,"selected panel leaves map dominant")
	expect(not app.ui.top_bar.get_global_rect().intersects(app.ui.map_toolbar.get_global_rect()),"toolbar below resources")
	expect(not app.ui.bottom_bar.get_global_rect().intersects(app.ui.notice_panel.get_global_rect()),"hint does not overlap bottom actions")
	for b in app.ui.navigation.get_children():
		expect(within(b,app.ui.bottom_bar),"navigation button fits: "+b.text)
		expect(b.get_theme_font_size("font_size")>=20,"readable navigation font")
	for key in app.ui.resource_labels:
		var l=app.ui.resource_labels[key];expect(within(l,app.ui.top_bar),"resource stays inside header "+key);expect(l.get_theme_font_size("font_size")>=26,"larger resource value "+key)
	var centre=app.state.data.provinces[23].center;var logical=app.map.get_canvas_transform()*Vector2(centre[0]-28,centre[1]+8)
	expect(root.get_global_rect().has_point(logical) and not app.ui.blocks_world_at(logical),"capital remains tappable in map area")
	sizes.append({"physical":[get_window().size.x,get_window().size.y],"content_scale_aspect":get_window().content_scale_aspect,"logical":[viewport.x,viewport.y],"safe_position":[root.position.x,root.position.y],"safe_size":[root.size.x,root.size.y],"top_height":app.ui.top_bar.size.y,"bottom_height":app.ui.bottom_bar.size.y,"sidebar_width":side.size.x,"resource_font":app.ui.resource_labels.gold.get_theme_font_size("font_size"),"navigation_font":app.ui.navigation.get_child(0).get_theme_font_size("font_size")})
func run():
	await settle();DirAccess.make_dir_recursive_absolute("res://docs/screenshots/0.3.1")
	await screenshot("01_menu_1920")
	await tap("Настройки");expect(is_instance_valid(app.ui.modal),"settings still receives touch");await tap("×")
	await tap("Новая игра");await tap("Сюжетная кампания");await screenshot("02_selection")
	await tap("Начать кампанию");expect(app.running and NarrativeSystem.active(app.state),"new story starts through native touch")
	await tap("Подтвердить вольности");expect(app.state.data.narrative.completed.has("n_coronation"),"story choice still applies")
	await get_tree().create_timer(.4).timeout
	expect(not app.ui.side.visible,"map opens without permanent details overlay")
	for width in [1920,2340,2400,2460]:
		get_window().size=Vector2i(width,1080);await settle();await get_tree().create_timer(.12).timeout
		app.map.focus_capital();await get_tree().create_timer(.25).timeout
		var cp=app.state.data.provinces[23].center;var at=app.map.get_canvas_transform()*Vector2(cp[0]-28,cp[1]+8)
		await tap_at(at);expect(app.ui.selected_province==23 and app.ui.side.visible,"touch province at "+str(width));check_layout(width)
		await screenshot("map_"+str(width))
	# Simulate cutout/system-edge insets in logical units without changing input scale.
	app.ui.safe_insets_override=Vector4(28,0,12,12);app.ui._fit_layout();await settle();check_layout(2460)
	expect(app.ui.root.position.x==28 and app.ui.root.size.y==get_viewport().get_visible_rect().size.y-12,"safe area insets only UI")
	await screenshot("map_2460_safe_area")
	app.ui.safe_insets_override=Vector4.ZERO;app.ui._fit_layout();await settle()
	# All six existing menus must open and close after resize.
	for name in ["Экономика","Дипломатия","Армия","Династия","Интриги","Законы"]:
		await tap(name);expect(is_instance_valid(app.ui.modal),"opens "+name)
		if name=="Экономика":await tap("Низкие");expect(int(app.state.data.realms[0].tax)==0,"real tax action")
		if name=="Династия":await screenshot("03_dynasty_wide")
		app.notification(NOTIFICATION_WM_GO_BACK_REQUEST);await settle();expect(app.ui.modal==null,"Back closes "+name)
	# Pinch touches on the unobstructed world, ignoring the emulated mouse copy.
	var old_zoom=app.map.target_zoom
	var first=InputEventScreenTouch.new();first.index=0;first.position=get_viewport().get_final_transform()*Vector2(470,330);first.pressed=true
	var second=InputEventScreenTouch.new();second.index=1;second.position=get_viewport().get_final_transform()*Vector2(650,330);second.pressed=true
	Input.parse_input_event(first);Input.parse_input_event(second);Input.flush_buffered_events();await settle()
	var drag=InputEventScreenDrag.new();drag.index=1;drag.position=get_viewport().get_final_transform()*Vector2(710,330);drag.relative=get_viewport().get_final_transform()*Vector2(60,0)-get_viewport().get_final_transform()*Vector2.ZERO;Input.parse_input_event(drag);Input.flush_buffered_events();await settle()
	first.pressed=false;second.pressed=false;second.position=drag.position;Input.parse_input_event(first);Input.parse_input_event(second);Input.flush_buffered_events();await settle();expect(app.map.target_zoom>old_zoom,"native pinch still zooms")
	await tap("2×");await get_tree().create_timer(.65).timeout;await tap("Ⅱ");expect(int(app.state.data.day)>=1 and app.clock.speed==0,"time controls remain interactive")
	await tap("☰");await tap("Сохранить");await tap("Записать");expect(SaveSystem.read_file(SaveSystem.path(1)).ok,"UI manual save")
	await tap("×");await tap("☰");await tap("Главное меню");await tap("Продолжить");expect(app.running and app.state.data.narrative.completed.has("n_coronation"),"continue restores campaign and story")
	# Decode only the architecture changed in this patch; old animation library is untouched.
	for id in ["peasant_hut","house","townhouse","farm","granary","market","small_castle","wooden_fort","fortified_manor","stone_keep","noble_estate","windmill","village_cluster","town_quarter","walled_town"]:expect(app.map.texture_for(id)!=null,"updated building loads "+id)
	var report={"version":"0.3.1","checks":checks,"failures":failures,"resolutions":sizes,"screenshots":captures,"touch_source":"native InputEventScreenTouch/ScreenDrag through Godot GUI in desktop Xvfb","android_device_tested":false}
	var f=FileAccess.open("res://docs/SMOKE_0.3.1.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();print("MOBILE SMOKE: ",JSON.stringify(report));get_tree().quit(0 if failures==0 else 1)

func recheck_layout():
	await settle();app.start_campaign(0,1,false);await settle()
	for width in [1920,2340,2400,2460]:
		get_window().size=Vector2i(width,1080);await settle();await get_tree().create_timer(.1).timeout
		app.map.focus_capital();await get_tree().create_timer(.2).timeout
		var cp=app.state.data.provinces[23].center;var at=app.map.get_canvas_transform()*Vector2(cp[0]-28,cp[1]+8);await tap_at(at)
		var viewport=get_viewport().get_visible_rect().size
		expect(get_window().size==Vector2i(width,1080),"actual Window size "+str(width))
		expect(absf(viewport.x/viewport.y-float(width)/1080)<.015,"wide canvas follows actual Window")
		expect(app.ui.selected_province==23 and app.ui.side.visible,"native hit testing after resize")
		for control in [app.ui.top_bar,app.ui.bottom_bar,app.ui.side,app.ui.map_toolbar,app.ui.notice_panel]:expect(within(control,app.ui.root),"panel fits safe root")
		expect(not app.ui.top_bar.get_global_rect().intersects(app.ui.map_toolbar.get_global_rect()),"toolbar no longer overlaps resource bar")
		expect(app.ui.map_toolbar.size.y<=52,"toolbar does not wrap vertically")
		expect(app.ui.top_bar.size.y<=94,"speed controls no longer wrap")
		for control in app.ui.top_bar.find_children("*","Button",true,false):expect(control.size.y<=app.ui.top_bar.size.y-16 and control.size.y>=44 and control.size.x>=44,"top control has readable hit area")
		sizes.append({"physical":[get_window().size.x,get_window().size.y],"logical":[viewport.x,viewport.y],"content_scale_aspect":get_window().content_scale_aspect,"top_height":app.ui.top_bar.size.y,"toolbar_height":app.ui.map_toolbar.size.y,"sidebar_width":app.ui.side.size.x,"resource_font":app.ui.resource_labels.gold.get_theme_font_size("font_size"),"navigation_font":app.ui.navigation.get_child(0).get_theme_font_size("font_size")})
		await screenshot("map_"+str(width))
	app.ui.safe_insets_override=Vector4(28,0,12,12);app.ui._fit_layout();await settle()
	for panel in [app.ui.top_bar,app.ui.bottom_bar,app.ui.side,app.ui.notice_panel]:expect(within(panel,app.ui.root),"cutout safe area fits")
	await screenshot("map_2460_safe_area")
	var f=FileAccess.open("res://docs/LAYOUT_RECHECK_0.3.1.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"only resized layout, touch coordinates and safe area","resolutions":sizes,"android_device_tested":false},"  "));f.close();print("LAYOUT RECHECK: ",checks," checks, ",failures," failures; ",JSON.stringify(sizes));get_tree().quit(0 if failures==0 else 1)

func recheck_hit_areas():
	await settle();app.start_campaign(0,1,false);await settle()
	var bounds=[]
	for control in app.ui.top_bar.find_children("*","Button",true,false):
		expect(control.size.x>=44 and control.size.y>=44,"top button minimum touch area: "+control.text)
		expect(within(control,app.ui.top_bar),"top button fits header: "+control.text)
		bounds.append({"button":control.text,"size":[control.size.x,control.size.y]})
	await tap("☰");expect(is_instance_valid(app.ui.modal),"larger pause button is interactive");await tap("×");expect(app.ui.modal==null,"pause closes")
	var f=FileAccess.open("res://docs/HIT_AREAS_0.3.1.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"only top button bounds and pause hit area; prior test's arbitrary 52 px upper bound removed","buttons":bounds,"android_device_tested":false},"  "));f.close();print("HIT AREA RECHECK: ",checks," checks, ",failures," failures");get_tree().quit(0 if failures==0 else 1)
