extends Node
var app
var checks=0
var failures=0
func _ready():call_deferred("run")
func expect(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;push_error("INPUT CHECK: "+message)
func settle():
	await get_tree().process_frame
	await get_tree().process_frame
func buttons(node:Node)->Array:
	var result=[]
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and not child.is_queued_for_deletion():result.append(child)
		result.append_array(buttons(child))
	return result
func find_button(prefix:String)->Button:
	var active=app.ui.modal if is_instance_valid(app.ui.modal) else app.ui.root
	for b in buttons(active):
		if b.text.begins_with(prefix) and not b.disabled:return b
	return null
func tap_at(point:Vector2):
	var press=InputEventScreenTouch.new();press.index=0;press.position=point;press.pressed=true
	Input.parse_input_event(press);Input.flush_buffered_events()
	await get_tree().process_frame
	var release=InputEventScreenTouch.new();release.index=0;release.position=point;release.pressed=false
	Input.parse_input_event(release);Input.flush_buffered_events()
	await settle()
func tap(prefix:String):
	var b=find_button(prefix)
	expect(b!=null,"visible button: "+prefix)
	if b!=null:await tap_at(b.get_global_rect().get_center())
func snapshot(name:String):
	if not "--art-check" in OS.get_cmdline_user_args():return
	await settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/0.2/"+name+".png")
func run():
	await settle()
	if "--art-check" in OS.get_cmdline_user_args():
		var manifest=GameState.read_json("res://assets_manifest.json")
		for resource in manifest.resources:
			var texture=app.map.texture_for(resource.id)
			expect(texture!=null and texture.get_width()==int(resource.size[0]) and texture.get_height()==int(resource.size[1]),"Godot texture "+resource.id)
		var legacy=SaveSystem.read_file("res://tests/fixtures/v0.1.0_save.json")
		expect(legacy.ok and legacy.metadata.version=="0.1.0","0.1 save format is still accepted")
		DirAccess.make_dir_recursive_absolute(SaveSystem.DIRECTORY)
		var file=FileAccess.open(SaveSystem.path(2),FileAccess.WRITE);file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.1.0_save.json"));file.close()
	await snapshot("01_main_menu")
	if "--reproduce-input-bug" in OS.get_cmdline_user_args():
		Input.emulate_mouse_from_touch=false
		await tap("Новая кампания")
		expect(not is_instance_valid(app.ui.choice_details),"old disabled emulation reproduces blocked menu")
		Input.emulate_mouse_from_touch=true
	await tap("Настройки");expect(is_instance_valid(app.ui.modal),"settings receives native touch")
	await tap("×");expect(app.ui.modal==null,"modal closes by touch")
	await tap("Загрузить кампанию");expect(is_instance_valid(app.ui.modal),"load slots open")
	await tap("×")
	await tap("Новая кампания");expect(is_instance_valid(app.ui.choice_details),"touch opens country selection")
	await snapshot("02_realm_selection")
	await tap("Вейрмарк");expect(app.ui.chosen_realm==1,"touch selects another realm")
	await tap("Хаймир");expect(app.ui.chosen_realm==12,"touch selects Highmere")
	await tap("Начать летопись");expect(app.running and app.ui.hud!=null,"touch enters campaign")
	await get_tree().create_timer(0.35).timeout
	await snapshot("03_campaign")
	var cp=app.state.data.provinces[23].center
	var screen=app.map.get_canvas_transform()*Vector2(cp[0]-50,cp[1]+10)
	await tap_at(screen);expect(app.ui.selected_province==23 and app.ui.side.visible,"touch selects province")
	await tap("Экономика");expect(is_instance_valid(app.ui.modal),"game panel opens")
	await snapshot("04_economy")
	await tap("Низкие");expect(int(app.state.data.realms[12].tax)==0,"touch executes real tax command")
	await tap("×")
	if "--art-check" in OS.get_cmdline_user_args():
		await tap("Династия");await snapshot("05_dynasty")
		app.notification(NOTIFICATION_WM_GO_BACK_REQUEST);await settle();expect(app.ui.modal==null,"Android Back notification closes panel")
		# Pinch passes through the actual input pipeline; synthetic mouse must not double-pan.
		var old_zoom=app.map.target_zoom
		var first=InputEventScreenTouch.new();first.index=0;first.position=Vector2(500,400);first.pressed=true;Input.parse_input_event(first)
		var second=InputEventScreenTouch.new();second.index=1;second.position=Vector2(700,400);second.pressed=true;Input.parse_input_event(second);Input.flush_buffered_events();await settle()
		var drag=InputEventScreenDrag.new();drag.index=1;drag.position=Vector2(760,400);drag.relative=Vector2(60,0);Input.parse_input_event(drag);Input.flush_buffered_events();await settle()
		first.pressed=false;second.pressed=false;second.position=drag.position;Input.parse_input_event(first);Input.parse_input_event(second);Input.flush_buffered_events();await settle()
		expect(app.map.target_zoom>old_zoom,"native two-finger pinch zoom")
		var army=app.state.army_by_id(12);var at=app.map.get_canvas_transform()*app.map.army_position(army)
		await tap_at(at);expect(app.ui.selected_army==12,"touch chooses army")
		await snapshot("06_army")
		app.notification(NOTIFICATION_WM_GO_BACK_REQUEST);await settle();expect(app.ui.selected_army==-1,"Back deselects army")
	await tap("☰");await tap("Сохранить");await tap("Записать")
	expect(SaveSystem.read_file(SaveSystem.path(1)).ok,"manual save by UI touch")
	await tap("×");await tap("☰");await tap("Загрузить")
	await tap("Загрузить");expect(app.running and app.ui.modal==null,"load returns to campaign")
	await tap("☰");await tap("Главное меню");expect(not app.running,"return to main menu by touch")
	await tap("Продолжить");expect(app.running,"continue loads latest save")
	if "--art-check" in OS.get_cmdline_user_args():
		var evidence={"checks":checks,"failures":failures,"textures_loaded":app.map.textures.size(),"texture_memory_desktop_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),"static_memory_desktop_bytes":OS.get_static_memory_usage(),"android_hardware_test":false}
		var out=FileAccess.open("res://docs/SMOKE_0.2.0.json",FileAccess.WRITE);out.store_string(JSON.stringify(evidence,"  "));out.close()
	print("INPUT SMOKE: %d checks, %d failures; native ScreenTouch → Controls → selection → campaign → province → action → save → load → menu → continue."%[checks,failures])
	get_tree().quit(0 if failures==0 else 1)
