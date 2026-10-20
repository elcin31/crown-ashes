extends Node2D
var map
const TYPES=["peasant_male","peasant_female","noble_male","noble_female","courier","merchant","priest","scout","militia","infantry","spearman","archer","cavalry","crossbowman","siege_engine","bandit"]
func _draw():
	if map.s==null:return
	var s=map.s;var time=map.visual_time;var visible_rect=Rect2(map.camera.position-get_viewport_rect().size/(2*map.camera.zoom.x),get_viewport_rect().size/map.camera.zoom.x).grow(100)
	# All 16 sprite sheets participate: citizens on local roads and soldiers in armies.
	for i in range(16):
		var pid=(i*7+23)%60;var p=s.data.provinces[pid];var center=Vector2(p.center[0],p.center[1]);var phase=fmod(time*0.055+i*0.17,1.0)
		var pos=center+Vector2(sin(phase*TAU)*60,cos(phase*TAU)*30+12)
		if not visible_rect.has_point(pos) or map.lod>0 or not map.details_enabled:continue
		var facing=2 if cos(phase*TAU)>=0 else 1;var walking=fmod(time+i,12.0)<8.0
		var frame=1+int(time*7+i)%4 if walking else 5+int(time*4)%2
		draw_unit(TYPES[i],pos,frame,facing,1.25)
	# Army animation is derived from saved daily movement, with visual frame interpolation.
	for a in s.data.armies:
		var pos=map.army_position(a)
		if not visible_rect.has_point(pos):continue
		var kind="militia";var largest=0
		for unit in a.units:
			if int(a.units[unit])>largest:largest=int(a.units[unit]);kind=s.units[unit].asset
		var moving=not a.route.is_empty();var direction=0
		if moving:
			var target=s.data.provinces[int(a.route[0])].center;var delta=Vector2(target[0],target[1])-pos
			direction=(2 if delta.x>0 else 1) if absf(delta.x)>absf(delta.y) else (0 if delta.y>0 else 3)
		var frame=1+int(time*7)%4 if moving else 5+int(time*5)%2 if a.order=="siege" else 0
		var r=s.data.realms[int(a.realm)];var color=map.realm_color(int(a.realm))
		draw_ellipse_shadow(pos)
		var count=mini(4,maxi(1,ArmySystem.size(a)/80))
		for j in range(count):draw_unit(kind,pos+Vector2((j%2)*17-8,(j/2)*12),frame,direction,1.5)
		draw_line(pos+Vector2(-17,-7),pos+Vector2(-17,-46),Color("#d5bb7a"),2)
		draw_rect(Rect2(pos+Vector2(-16,-46),Vector2(18,24)),color)
		draw_texture_rect(map.textures[r.heraldry],Rect2(pos+Vector2(-15,-46),Vector2(18,22)),false)
		var label=str(ArmySystem.size(a));var fs=14;draw_string_outline(map.font,pos+Vector2(0,29),label,HORIZONTAL_ALIGNMENT_CENTER,-1,fs,4,Color("#17262b"));draw_string(map.font,pos+Vector2(0,29),label,HORIZONTAL_ALIGNMENT_CENTER,-1,fs,Color("#f3dfac"))
		if a.order=="siege" and map.lod==0 and map.details_enabled:
			var effect=map.textures.fire;draw_texture_rect_region(effect,Rect2(pos+Vector2(18,-24),Vector2(32,32)),Rect2(int(time*8)%4*64,0,64,64))
		if moving and map.lod==0 and map.details_enabled:draw_texture_rect_region(map.textures.dust_smoke,Rect2(pos+Vector2(-28,4),Vector2(32,32)),Rect2(int(time*6)%4*64,0,64,64))
	# Two coastal routes add ships; no naval command system is claimed in 0.1.
	for i in range(2):
		var pos=Vector2(100+fmod(time*8+i*131,300),1470+i*80)
		if visible_rect.has_point(pos):draw_texture_rect(map.textures.trade_ship if i==0 else map.textures.warship,Rect2(pos,Vector2(64,64)),false)
func draw_unit(kind:String,pos:Vector2,frame:int,direction:int,scale_value:float):
	draw_texture_rect_region(map.textures[kind],Rect2(pos+Vector2(-16,-30)*scale_value,Vector2(32,40)*scale_value),Rect2(frame*32,direction*40,32,40))
func draw_ellipse_shadow(pos:Vector2):draw_circle(pos+Vector2(0,14),20,Color(0.06,0.12,0.12,0.3))
