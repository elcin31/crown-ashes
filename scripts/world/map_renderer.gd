class_name MapRenderer
extends Node2D
signal province_selected(id:int)
signal army_selected(id:int)
var s
var camera:Camera2D
var target_position=Vector2(1100,850)
var target_zoom=0.85
var mode:int=0
var selected_province:int=-1
var selected_army:int=-1
var destination_mode:bool=false
var textures={}
var polygons:Array=[]
var bounds:Array=[]
var font:Font
var actors:Node2D
var input_controller
var lod:int=0
var visual_time:float=0.0
var details_enabled:bool=true
var static_sprite:Sprite2D
func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	font=load("res://assets/fonts/DejaVuSans.ttf")
	var manifest=GameState.read_json("res://assets_manifest.json")
	for resource in manifest.resources:textures[resource.id]=load("res://"+resource.path)
	static_sprite=Sprite2D.new();static_sprite.texture=load("res://data/terrain_cache.png");static_sprite.centered=false;static_sprite.z_index=-1;add_child(static_sprite)
	camera=Camera2D.new();camera.position=target_position;camera.zoom=Vector2.ONE*target_zoom;camera.position_smoothing_enabled=false;add_child(camera)
	actors=Node2D.new();actors.set_script(load("res://scripts/world/map_actors.gd"));actors.map=self;add_child(actors)
	input_controller=Node.new();input_controller.set_script(load("res://scripts/world/input_controller.gd"));input_controller.map=self;add_child(input_controller)
func set_state(state):
	s=state;polygons.clear();bounds.clear()
	for p in s.data.provinces:
		var points=PackedVector2Array()
		for a in p.polygon:points.append(Vector2(a[0],a[1]))
		polygons.append(points)
		var rect=Rect2(points[0],Vector2.ZERO)
		for point in points:rect=rect.expand(point)
		bounds.append(rect)
	selected_province=int(s.data.realms[int(s.data.player)].capital);selected_army=-1;destination_mode=false
	focus_capital();queue_redraw()
func focus_capital():
	if s==null:return
	var center=s.data.provinces[int(s.data.realms[int(s.data.player)].capital)].center
	target_position=Vector2(center[0],center[1]);target_zoom=0.9
func _process(delta):
	if s==null:return
	visual_time+=delta
	var fraction=1.0-exp(-delta*14)
	camera.position=camera.position.lerp(target_position,fraction);camera.zoom=camera.zoom.lerp(Vector2.ONE*target_zoom,fraction)
	var margin=get_viewport_rect().size/(target_zoom*2)
	target_position.x=clampf(target_position.x,margin.x-180,3072-margin.x+180)
	target_position.y=clampf(target_position.y,margin.y-120,1792-margin.y+120)
	var next_lod=1 if target_zoom<0.65 else 0
	if lod!=next_lod:lod=next_lod;queue_redraw()
	actors.queue_redraw()
func pick(screen:Vector2):
	if s==null:return
	var world=screen_to_world(screen)
	if not destination_mode:
		var nearest=-1;var distance=28.0/target_zoom
		for a in s.data.armies:
			var d=army_position(a).distance_to(world)
			if d<distance:distance=d;nearest=int(a.id)
		if nearest>=0:selected_army=nearest;army_selected.emit(nearest);queue_redraw();return
	for id in range(polygons.size()):
		if bounds[id].has_point(world) and Geometry2D.is_point_in_polygon(world,polygons[id]):
			selected_province=id;province_selected.emit(id);queue_redraw();return
func screen_to_world(point:Vector2)->Vector2:return get_canvas_transform().affine_inverse()*point
func army_position(a:Dictionary)->Vector2:
	var p=s.data.provinces[int(a.province)].center;var pos=Vector2(p[0],p[1])+Vector2(30,-5)
	if not a.route.is_empty() and int(a.travel_total)>0:
		var dest=s.data.provinces[int(a.route[0])].center;var t=1.0-float(a.travel_left)/float(a.travel_total)
		pos=pos.lerp(Vector2(dest[0],dest[1])+Vector2(30,-5),t)
	return pos
func realm_color(id:int,alpha:float=1.0)->Color:
	var c=Color("#"+s.data.realms[id].color);c.a=alpha;return c
func overlay_color(p:Dictionary)->Color:
	var id=int(p.owner)
	match mode:
		1:return realm_color(id,0.45)
		2:
			if id==int(s.data.player):return Color(0.85,0.7,0.32,0.5)
			if s.at_war(int(s.data.player),id):return Color(0.72,0.15,0.15,0.55)
			var rel=s.relation(int(s.data.player),id)
			if rel.alliance:return Color(0.2,0.64,0.73,0.5)
			var f=(float(rel.value)+100)/200
			return Color(0.65,0.22,0.2,0.4).lerp(Color(0.2,0.68,0.35,0.5),f)
		3:return Color(0.6,0.3,0.15,0.35).lerp(Color(0.65,0.76,0.3,0.48),float(p.development)/100)
		4:return Color(0.15,0.54,0.36,0.42).lerp(Color(0.8,0.18,0.13,0.58),float(p.unrest)/100)
	return Color(0,0,0,0)
func _draw():
	if s==null or polygons.is_empty():return
	for id in range(polygons.size()):
		var p=s.data.provinces[id];var points=polygons[id];var overlay=overlay_color(p)
		if overlay.a>0:draw_colored_polygon(points,overlay)
		var loop=points.duplicate();loop.append(points[0]);draw_polyline(loop,Color(0.19,0.23,0.17,0.55),1.6,false)
		if int(p.occupation)>=0:
			draw_colored_polygon(points,realm_color(int(p.occupation),0.22))
		if id==selected_province:
			draw_colored_polygon(points,Color(0.95,0.81,0.4,0.13));draw_polyline(loop,Color("#efd283"),4.0,false)
	# Sovereign and feudal borders are computed once in world data.
	# Shared edges cached by the controller, avoiding file reads during rendering.
	for e in input_controller.edges:
		var a=s.data.provinces[int(e.a)];var b=s.data.provinces[int(e.b)]
		if int(a.owner)!=int(b.owner):
			var p=e.points;draw_line(Vector2(p[0][0],p[0][1]),Vector2(p[1][0],p[1][1]),Color(0.2,0.19,0.17,0.9),4.0,false);draw_line(Vector2(p[0][0],p[0][1]),Vector2(p[1][0],p[1][1]),realm_color(int(a.owner),0.85),1.5,false)
	for p in s.data.provinces:
		var c=Vector2(p.center[0],p.center[1]);var r=s.data.realms[int(p.owner)]
		var capital=int(p.id)==int(r.capital);var key="grand_castle" if capital and int(r.title)>=2 else "small_castle" if int(p.fort)>0 else "townhouse"
		if int(p.buildings.get("fort",0))>=2:key="citadel"
		var size=Vector2(78,78) if capital else Vector2(62,62)
		draw_texture_rect(textures[key],Rect2(c-size*Vector2(0.5,0.8),size),false)
		if capital or lod==0:
			var shield=textures[r.heraldry];draw_texture_rect(shield,Rect2(c+Vector2(-10,-size.y-2),Vector2(24,28)),false)
		if lod==0 or capital:
			var text=p.name;var fs=16 if capital else 14;var w=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
			var at=c+Vector2(-w/2,30)
			draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,4,Color("#17282b"));draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color("#f0e2b7") if capital else Color("#d8d2b2"))
		if not p.construction.is_empty():draw_rect(Rect2(c+Vector2(-22,36),Vector2(44,5)),Color("#253639"));draw_rect(Rect2(c+Vector2(-22,36),Vector2(44*(1.0-float(p.construction.remaining)/float(p.construction.total)),5)),Color("#dab668"))
		if not p.siege.is_empty():draw_arc(c,42,0,TAU*float(p.siege.progress)/100,28,Color("#d99c67"),4,false)
	if selected_army>=0:
		var a=s.army_by_id(selected_army)
		if not a.is_empty():
			var pos=army_position(a);draw_arc(pos,24,0,TAU,24,Color("#e4cf8c"),2,false)
			var previous=pos
			for pid in a.route:
				var center=s.data.provinces[int(pid)].center;var next=Vector2(center[0],center[1])+Vector2(30,-5);draw_dashed_line(previous,next,Color("#e9ce86"),2,8);previous=next
