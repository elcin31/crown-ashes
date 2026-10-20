extends Control
signal navigated(position:Vector2)
var map
func _ready():
	custom_minimum_size=Vector2(190,112);mouse_filter=Control.MOUSE_FILTER_STOP
func _draw():
	if map==null or map.s==null:return
	var factor=size/Vector2(3072,1792)
	draw_rect(Rect2(Vector2.ZERO,size),Color("#163e54"))
	for i in range(map.polygons.size()):
		var points=PackedVector2Array()
		for p in map.polygons[i]:points.append(p*factor)
		draw_colored_polygon(points,map.realm_color(int(map.s.data.provinces[i].owner),0.9))
	var center=map.camera.position*factor;var extent=map.get_viewport_rect().size/map.camera.zoom.x*factor
	draw_rect(Rect2(center-extent/2,extent),Color("#f3dda1"),false,1.5)
	draw_rect(Rect2(Vector2.ZERO,size),Color("#8f815c"),false,1.0)
func _gui_input(event):
	if (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		map.target_position=event.position/size*Vector2(3072,1792);accept_event()
