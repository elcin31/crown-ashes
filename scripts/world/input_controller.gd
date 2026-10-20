class_name InputController
extends Node
var map
var edges=[]
var touches={}
var touch_origin={}
var dragging=false
var mouse_start=Vector2.ZERO
var mouse_last=Vector2.ZERO
var multi=false
var pinch_distance=0.0
var moved=false
func _ready():edges=GameState.read_json("res://data/world.json").edges
func _unhandled_input(event):
	if map.s==null or not map.visible:return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:zoom_at(event.position,1.13)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:zoom_at(event.position,1.0/1.13)
		elif event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE]:
			if event.pressed:dragging=true;mouse_start=event.position;mouse_last=event.position;moved=false
			else:
				if dragging and not moved and event.button_index==MOUSE_BUTTON_LEFT:map.pick(event.position)
				dragging=false
	elif event is InputEventMouseMotion and dragging:
		var delta=event.position-mouse_last;mouse_last=event.position
		if event.position.distance_to(mouse_start)>10:moved=true
		if moved:map.target_position-=delta/map.target_zoom
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index]=event.position;touch_origin[event.index]=event.position
			if touches.size()==1:multi=false;moved=false
			if touches.size()>1:multi=true;pinch_distance=touch_distance()
		else:
			if touches.has(event.index) and touches.size()==1 and not multi and not moved:map.pick(event.position)
			touches.erase(event.index);touch_origin.erase(event.index)
	elif event is InputEventScreenDrag:
		if not touches.has(event.index):return
		touches[event.index]=event.position
		if touches.size()>=2:
			var dist=touch_distance()
			if pinch_distance>0:zoom_at(touch_midpoint(),dist/pinch_distance)
			pinch_distance=dist;multi=true
		else:
			if event.position.distance_to(touch_origin[event.index])>12:moved=true
			if moved:map.target_position-=event.relative/map.target_zoom
	elif event is InputEventMagnifyGesture:zoom_at(event.position,event.factor)
	elif event is InputEventKey and event.pressed:
		if event.keycode==KEY_HOME:map.focus_capital()
func zoom_at(screen:Vector2,factor:float):
	var old=map.target_zoom;var next=clampf(old*factor,0.45,1.8)
	var offset=screen-map.get_viewport_rect().size/2
	map.target_position+=offset/old-offset/next;map.target_zoom=next
func touch_distance()->float:
	var points=touches.values()
	return points[0].distance_to(points[1]) if points.size()>=2 else 0.0
func touch_midpoint()->Vector2:
	var points=touches.values()
	return (points[0]+points[1])/2 if points.size()>=2 else Vector2.ZERO
