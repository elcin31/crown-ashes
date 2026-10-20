extends Node
var state:GameState
var commands:GameCommands
var clock=GameClock.new()
var map:MapRenderer
var ui:UIController
var running=false
var outcome_shown=false
var event_hint_day=-1
func _ready():
	get_tree().auto_accept_quit=false
	get_tree().quit_on_go_back=false
	Engine.max_fps=60
	state=GameState.new();state.new_campaign(12,1);commands=GameCommands.new(state)
	map=MapRenderer.new();add_child(map);map.set_state(state)
	ui=UIController.new();ui.app=self;add_child(ui)
	map.province_selected.connect(func(id):if running:ui.select_province(id))
	map.army_selected.connect(func(id):if running:ui.select_army(id))
	map.input_controller.ui_blocks_world=ui.blocks_world_at
	load_settings();ui.show_main_menu()
	if "--input-smoke" in OS.get_cmdline_user_args():
		var runner=load("res://tests/input_smoke.gd").new();runner.app=self;add_child(runner)
	elif "--visual-check" in OS.get_cmdline_user_args():
		var runner=load("res://tests/visual_check.gd").new();runner.app=self;add_child(runner)
func start_campaign(realm:int,difficulty:int):
	state.new_campaign(realm,difficulty);commands=GameCommands.new(state);clock=GameClock.new();clock.speed=0;running=true;outcome_shown=false
	map.set_state(state);map.input_controller.reset_gestures();map.input_controller.enabled=true;ui.show_game()
func load_campaign(slot:int):
	var result=SaveSystem.load_game(state,slot)
	if not result.ok:ui.toast(result.message);return
	commands=GameCommands.new(state);clock=GameClock.new();running=true;outcome_shown=false;map.set_state(state);map.input_controller.reset_gestures();map.input_controller.enabled=true;ui.show_game();ui.toast("Кампания загружена: "+state.date_text())
func return_to_menu():
	running=false;clock.speed=0;outcome_shown=false;map.input_controller.enabled=false;map.input_controller.reset_gestures();ui.show_main_menu()
func set_speed(speed:int):
	if ui.modal!=null and is_instance_valid(ui.modal):return
	clock.speed=speed;ui.refresh_hud()
func _process(delta):
	if not running:return
	if state.data.outcome!="" and not outcome_shown:
		clock.speed=0;outcome_shown=true;ui.show_outcome();return
	if state.data.outcome!="" and state.data.outcome!="victory":return
	var days=clock.advance(delta,state,commands)
	if days>0:
		map.queue_redraw();ui.refresh_hud();ui.refresh_side()
		if int(state.data.day)-int(state.data.last_autosave)>=int(state.balance.autosave_days):
			state.data.last_autosave=state.data.day
			var result=SaveSystem.save_game(state,0)
			if not result.ok:ui.toast(result.message)
		if state.data.events.size()>0 and event_hint_day!=int(state.data.day)/24:
			event_hint_day=int(state.data.day)/24;ui.toast("Двор ожидает решения: откройте «Летопись».",8)
func _unhandled_key_input(event):
	if not event.pressed or event.echo:return
	if event.keycode==KEY_ESCAPE:ui.handle_back();get_viewport().set_input_as_handled()
	elif running and event.keycode==KEY_SPACE:set_speed(1 if clock.speed==0 else 0)
	elif running and event.keycode==KEY_F5:var result=SaveSystem.save_game(state,1);ui.toast(result.message)
func _notification(what):
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and ui!=null:ui.handle_back()
	elif what==NOTIFICATION_APPLICATION_PAUSED:
		if running:clock.speed=0;SaveSystem.save_game(state,0)
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:request_quit()
func request_quit():
	if running:SaveSystem.save_game(state,0)
	get_tree().quit()
func save_settings():
	var config=ConfigFile.new();config.set_value("display","max_fps",Engine.max_fps);config.set_value("display","details",map.details_enabled);config.save("user://settings.cfg")
func load_settings():
	var config=ConfigFile.new()
	if config.load("user://settings.cfg")==OK:
		Engine.max_fps=int(config.get_value("display","max_fps",60));map.details_enabled=bool(config.get_value("display","details",true))
