extends Node2D
var map
func _draw():
	if map.s==null:return
	var s=map.s;var time=map.visual_time;var view=map.visible_world_rect().grow(120)
	var cast=VisualLibrary.OLD_ACTORS+VisualLibrary.NEW_ACTORS
	if map.details_enabled and map.lod==0:
		for i in range(cast.size()):
			var p=s.data.provinces[(i*7+23)%60];var center=Vector2(p.center[0],p.center[1]);var phase=fmod(time*.022+i*.17,1.0)
			var worker=cast[i] in ["village_farmer","lumberjack","blacksmith","miner","siege_engineer","court_priest"]
			var walking=not worker and fmod(time+i,14)<9
			var pos=center+Vector2(sin(phase*TAU)*72,cos(phase*TAU)*32+15)
			if worker:pos=center+Vector2(-63+(i%3)*23,25+(i%2)*12)
			if not view.has_point(pos):continue
			var direction=(2 if cos(phase*TAU)>=0 else 1) if walking else i%4
			var frame=1+int(time*8+i)%4 if walking else 5+int(time*5+i)%3 if worker else 0
			draw_unit(cast[i],pos,frame,direction,.85)
	for a in s.data.armies:
		var pos=map.army_position(a)
		if not view.has_point(pos):continue
		var dominant="militia";var largest=0
		for kind in a.units:
			if int(a.units[kind])>largest:largest=int(a.units[kind]);dominant=kind
		var moving=not a.route.is_empty();var direction=0
		if moving:
			var to=s.data.provinces[int(a.route[0])].center;var delta=Vector2(to[0],to[1])-pos
			direction=(2 if delta.x>0 else 1) if absf(delta.x)>absf(delta.y) else (0 if delta.y>0 else 3)
		var frame=1+int(map.army_time*8)%4 if moving else 5+int(map.army_time*6)%3 if a.order=="siege" else 0
		if int(s.data.day)-int(a.last_battle)<=1:frame=8+int(map.army_time*5)%2
		var realm=s.data.realms[int(a.realm)];var friendly=int(a.realm)==int(s.data.player);var hostile=s.at_war(int(s.data.player),int(a.realm))
		var color=Color("#87b5ce") if friendly else Color("#cb8476") if hostile else map.realm_color(int(a.realm))
		if map.lod>0:
			draw_texture_rect(map.texture_for(VisualLibrary.formation(dominant)),Rect2(pos+Vector2(-25,-27),Vector2(50,44)),false)
			draw_texture_rect(map.texture_for(realm.heraldry),Rect2(pos+Vector2(-30,-35),Vector2(20,24)),false)
		else:
			var sprite=VisualLibrary.army_sprite(s,a,dominant);var count=mini(3,maxi(1,int(ArmySystem.size(a)/110)))
			draw_circle(pos+Vector2(0,7),23,Color(0.04,.09,.1,.28))
			for i in range(count):draw_unit(sprite,pos+Vector2((i%2)*15-7,int(i/2)*10),frame,direction,1.0)
			var banner="rebel_army_banner" if realm.get("is_rebel",false) else "royal_army_banner"
			draw_texture_rect(map.texture_for(banner),Rect2(pos+Vector2(-31,-56),Vector2(37,42)),false)
			draw_texture_rect(map.texture_for(realm.heraldry),Rect2(pos+Vector2(-18,-51),Vector2(17,20)),false)
			if a.order=="siege":
				draw_texture_rect(map.texture_for("siege_camp"),Rect2(pos+Vector2(19,-15),Vector2(66,58)),false)
				draw_texture_rect(map.texture_for("war_tent"),Rect2(pos+Vector2(-55,8),Vector2(38,34)),false)
				if int(a.units.get("siege",0))>0:draw_texture_rect(map.texture_for("trebuchet"),Rect2(pos+Vector2(21,-57),Vector2(54,48)),false)
				if map.details_enabled:effect("fire",pos+Vector2(25,-14),30,time)
			if moving and map.details_enabled:effect("dust_smoke",pos+Vector2(-30,6),32,time)
		if int(a.id)==map.selected_army:draw_arc(pos+Vector2(0,6),29,0,TAU,32,Color("#ebd395"),2,false)
		var number=str(ArmySystem.size(a));var fs=16;var width=map.font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
		var offset=Vector2(-width/2,30)
		draw_style_box(marker_box(color),Rect2(pos+Vector2(-width/2-6,14),Vector2(width+12,22)))
		draw_string(map.font,pos+offset,number,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color("#f1e2b0"))
	# Recent real battle results leave a visible field marker and short combat sparks.
	for report in s.data.reports:
		if int(s.data.day)-int(report.day)>30:continue
		var p=s.data.provinces[int(report.province)];var pos=Vector2(p.center[0],p.center[1])+Vector2(-58,-4)
		if view.has_point(pos) and map.lod==0:
			draw_texture_rect(map.texture_for("battlefield_ruins"),Rect2(pos,Vector2(57,50)),false)
			if int(s.data.day)-int(report.day)<=1 and map.details_enabled:effect("sword_impact",pos+Vector2(20,0),38,time)
	for i in range(2):
		var pos=Vector2(100+fmod(time*7+i*131,300),1470+i*80)
		if view.has_point(pos):draw_texture_rect(map.texture_for("trade_ship" if i==0 else "warship"),Rect2(pos,Vector2(78,78)),false)
var marker_styles={}
func marker_box(color:Color)->StyleBoxFlat:
	var key=color.to_html()
	if not marker_styles.has(key):
		var style=StyleBoxFlat.new();style.bg_color=Color("#17252c");style.border_color=color;style.set_border_width_all(1);style.set_corner_radius_all(2);marker_styles[key]=style
	return marker_styles[key]
func draw_unit(kind:String,pos:Vector2,frame:int,direction:int,scale_value:float):
	var anim=map.texture_metadata[kind].animation;var w=int(anim.frame_width);var h=int(anim.frame_height)
	draw_texture_rect_region(map.texture_for(kind),Rect2(pos+Vector2(-w/2.0,-h*.83)*scale_value,Vector2(w,h)*scale_value),Rect2(frame*w,direction*h,w,h))
func effect(id:String,pos:Vector2,extent:float,time:float):
	var anim=map.texture_metadata[id].animation;var frame=int(time*anim.fps)%int(anim.columns)
	draw_texture_rect_region(map.texture_for(id),Rect2(pos,Vector2.ONE*extent),Rect2(frame*int(anim.frame_width),0,int(anim.frame_width),int(anim.frame_height)))
