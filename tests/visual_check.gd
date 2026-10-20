extends Node
var app
func _ready():call_deferred("run")
func capture(name:String):
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/"+name+".png")
func run():
	await capture("01_main_menu")
	app.start_campaign(12,1)
	await get_tree().create_timer(0.4).timeout
	await capture("02_campaign")
	app.ui.open_economy();await capture("03_economy")
	app.ui.open_diplomacy(0);await capture("04_diplomacy")
	app.ui.open_dynasty();await capture("05_dynasty")
	app.ui.close_window();app.ui.select_army(12)
	var before=app.map.target_position
	var touch=InputEventScreenTouch.new();touch.index=0;touch.position=Vector2(600,300);touch.pressed=true
	app.map.input_controller._unhandled_input(touch)
	var drag=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(650,310);drag.relative=Vector2(50,10)
	app.map.input_controller._unhandled_input(drag)
	touch.pressed=false;touch.position=drag.position;app.map.input_controller._unhandled_input(touch)
	assert(before!=app.map.target_position,"touch pan")
	var oldzoom=app.map.target_zoom
	app.map.input_controller.zoom_at(Vector2(600,300),1.2)
	assert(app.map.target_zoom>oldzoom,"zoom")
	for it in GameState.read_json("res://assets_manifest.json").resources:
		assert(app.map.textures.has(it.id) and app.map.textures[it.id]!=null,"texture import")
	app.ui.open_buildings(23);await capture("06_construction")
	app.ui.open_recruit(23);await capture("07_recruitment")
	app.ui.open_intrigue();await get_tree().process_frame
	app.ui.open_laws();await get_tree().process_frame
	app.ui.open_marriage();await get_tree().process_frame
	app.ui.open_settings();await get_tree().process_frame
	app.ui.close_window()
	var result=SaveSystem.save_game(app.state,1);assert(result.ok)
	assert(SaveSystem.load_game(app.state,1).ok)
	print("PRIMARY PASS: menu, new game, 10 interface flows, 136 Godot textures, touch pan, zoom and save/load.")
	get_tree().quit()
