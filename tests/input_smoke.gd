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
func run():
	await settle()
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
	await tap("Вейрмарк");expect(app.ui.chosen_realm==1,"touch selects another realm")
	await tap("Хаймир");expect(app.ui.chosen_realm==12,"touch selects Highmere")
	await tap("Начать летопись");expect(app.running and app.ui.hud!=null,"touch enters campaign")
	await get_tree().create_timer(0.35).timeout
	var cp=app.state.data.provinces[23].center
	var screen=app.map.get_canvas_transform()*Vector2(cp[0]-50,cp[1]+10)
	await tap_at(screen);expect(app.ui.selected_province==23 and app.ui.side.visible,"touch selects province")
	await tap("Экономика");expect(is_instance_valid(app.ui.modal),"game panel opens")
	await tap("Низкие");expect(int(app.state.data.realms[12].tax)==0,"touch executes real tax command")
	await tap("×")
	await tap("☰");await tap("Сохранить");await tap("Записать")
	expect(SaveSystem.read_file(SaveSystem.path(1)).ok,"manual save by UI touch")
	await tap("×");await tap("☰");await tap("Загрузить")
	await tap("Загрузить");expect(app.running and app.ui.modal==null,"load returns to campaign")
	await tap("☰");await tap("Главное меню");expect(not app.running,"return to main menu by touch")
	await tap("Продолжить");expect(app.running,"continue loads latest save")
	print("INPUT SMOKE: %d checks, %d failures; native ScreenTouch → Controls → selection → campaign → province → action → save → load → menu → continue."%[checks,failures])
	get_tree().quit(0 if failures==0 else 1)
