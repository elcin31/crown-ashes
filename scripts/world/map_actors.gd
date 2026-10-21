extends Node2D
var map
var pool=[]
var refresh_left=0.0
var density_limit=40
var frame_average=.016
var density_clock=0.0
var actor_clock=0.0
var selected_route:int=-1
func _ready():
	for i in range(56):pool.append({"active":false,"index":i})
func _process(delta):
	frame_average=lerpf(frame_average,delta,.025);density_clock+=delta
	if density_clock>2:
		density_clock=0;density_limit=clampi(density_limit+(-4 if frame_average>.029 else 2 if frame_average<.020 else 0),12,48)
	if map.s==null or map.lod>0 or not map.details_enabled:return
	refresh_left-=delta
	if refresh_left<=0:refresh_left=.25;refresh_population()
	if not map.simulation_running:return
	var speed=map.get_meta("time_speed",1);actor_clock+=delta*speed
	for a in pool:
		if not a.active:continue
		if float(a.wait)>0:a.wait-=delta*speed;continue
		var budget=delta*speed*11
		var pos=a.pos
		while budget>0 and int(a.segment)<a.path.size()-1:
			var next=RouteNetwork.point(a.path[int(a.segment)+1]);var dist=pos.distance_to(next)
			if dist>budget:pos=pos.move_toward(next,budget);budget=0
			else:pos=next;budget-=dist;a.segment+=1
			var diff=next-a.pos
			if diff.length_squared()>0:a.direction=(2 if diff.x>0 else 1) if abs(diff.x)>abs(diff.y) else (0 if diff.y>0 else 3)
		a.pos=pos
		if int(a.segment)>=a.path.size()-1:
			a.phase=(int(a.phase)+1)%a.stops.size();a.path=LivingWorld.routes().local_path(pos,RouteNetwork.point(a.stops[int(a.phase)]));a.segment=0;a.wait=2.0+int(a.index)%4
func refresh_population():
	var view=map.visible_world_rect().grow(50);var active=0;var counts={}
	for a in pool:
		if a.active and LivingWorld.danger(map.s,map.s.data.provinces[int(a.province)]) and a.role not in ["guard","patrol","bandit"]:a.active=false
		if a.active and (not view.has_point(a.pos) or active>=density_limit):a.active=false
		if a.active:active+=1;counts[str(a.province)]=int(counts.get(str(a.province),0))+1
	var spawned=0
	for p in map.s.data.provinces:
		var pid=int(p.id);var center=RouteNetwork.point(p.center)
		if not view.has_point(center):continue
		var cap=5+SettlementSystem.tier(p,map.s.data.realms[int(p.owner)])*2+mini(3,int(p.buildings.get("farm",0)))
		if LivingWorld.danger(map.s,p):cap=3
		if map.s.calendar().m in [11,0,1]:cap=maxi(2,cap-3)
		if float(p.unrest)<20 and float(map.s.data.realms[int(p.owner)].stability)>60:cap+=2
		var slots=RouteNetwork.nav.slots[pid]
		if slots.size()<3:continue
		while int(counts.get(str(pid),0))<cap and active<density_limit and spawned<3:
			var a={}
			for candidate in pool:
				if not candidate.active:a=candidate;break
			if a.is_empty():return
			var idx=int(a.index);var home=RouteNetwork.point(slots[idx%slots.size()])+Vector2(0,12)
			var work=RouteNetwork.point(slots[(idx+3)%slots.size()])+Vector2(0,12)
			var market=center+Vector2(0,16)
			var path=LivingWorld.routes().local_path(home,work)
			if path.is_empty():return
			var roles=["peasant","peasant_woman","farmer","lumberjack","miner","blacksmith","merchant","traveller","priest","monk","guard","patrol","tax_collector","noblewoman","diplomat"]
			var role=roles[(idx+pid)%roles.size()]
			if LivingWorld.danger(map.s,p):role="bandit" if float(p.unrest)>65 and idx%3==0 else "patrol"
			elif role=="miner" and p.terrain not in ["mountains","hills"]:role="farmer"
			elif role=="farmer" and int(p.buildings.get("farm",0))==0:role="traveller"
			a.merge({"active":true,"province":pid,"pos":RouteNetwork.point(path[0]),"path":path,"segment":0,"stops":[[work.x,work.y],[market.x,market.y],[home.x,home.y]],"phase":0,"wait":float(idx%3),"role":role,"direction":0},true)
			active+=1;spawned+=1;counts[str(pid)]=int(counts.get(str(pid),0))+1
func pick_agent(world:Vector2)->int:
	var found=-1;var distance=28.0/map.target_zoom
	for a in map.s.data.living.agents:
		var pos=LivingWorld.interpolated(a,map.movement_fraction if map.simulation_running else 0)
		var d=pos.distance_to(world)
		if d<distance:distance=d;found=int(a.id)
	if found<0 and map.lod==0 and map.details_enabled:
		for a in pool:
			if not a.active or a.role not in ["guard","patrol","tax_collector","priest","noblewoman"]:continue
			var d=a.pos.distance_to(world)
			if d<distance:distance=d;found=1000000+int(a.index)
	return found
func _draw():
	if map.s==null:return
	var s=map.s;var time=map.visual_time;var view=map.visible_world_rect().grow(120)
	if map.details_enabled and map.lod==0:
		# A few drifting highlights on saved rivers, no shader or world rebuild.
		for river in map.rivers:
			for step in range(1,river.size()):
				var a=Vector2(river[step-1][0],river[step-1][1]);var b=Vector2(river[step][0],river[step][1]);var t=fmod(time*.10+step*.23,1.0);var pos=a.lerp(b,t)
				if view.has_point(pos):draw_line(pos-Vector2(3,0),pos+Vector2(5,0),Color(.65,.9,.95,.30+.20*sin(t*PI)),1,false)
	if map.details_enabled and map.lod==0:
		for a in pool:
			if not a.active or not view.has_point(a.pos):continue
			var action="walk" if float(a.wait)<=0 and int(a.segment)<a.path.size()-1 else "work" if a.role in ["farmer","blacksmith","lumberjack","miner"] else "interact"
			if a.role=="bandit" and float(a.wait)>0 and int(a.phase)==2:action="attack"
			living_unit("lk_actor_"+a.role,a.pos,action,int(a.direction),.38,actor_clock+int(a.index)*.17)
	for a in s.data.living.agents:
		var pos=LivingWorld.interpolated(a,map.movement_fraction if map.simulation_running else 0)
		if not view.has_point(pos):continue
		var direction=0
		if int(a.segment)<a.path.size()-1:
			var diff=RouteNetwork.point(a.path[int(a.segment)+1])-pos
			direction=(2 if diff.x>0 else 1) if abs(diff.x)>abs(diff.y) else (0 if diff.y>0 else 3)
		if int(a.id)==selected_route:
			var points=PackedVector2Array([pos])
			for i in range(int(a.segment)+1,a.path.size()):points.append(RouteNetwork.point(a.path[i]))
			if points.size()>1:draw_polyline(points,Color("#efd179"),2,false)
		if map.lod>0:
			draw_circle(pos,5 if a.kind=="merchant" else 4,Color("#e1bc68") if a.kind=="merchant" else Color("#a8d9e6"));continue
		if a.kind=="merchant":draw_texture_rect(map.texture_for("merchant_cart"),Rect2(pos+Vector2(-22,-24),Vector2(34,34)),false)
		living_unit("lk_actor_"+a.kind,pos+Vector2(10,0) if a.kind=="merchant" else pos,"walk" if a.status=="travel" else "idle",direction,.50,map.army_time)
		if a.quest!="":
			draw_circle(pos+Vector2(0,-44),8,Color("#e6bd57"));draw_string(map.font,pos+Vector2(-3,-39),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#233647"))
	for p in s.data.provinces:
		var pos=RouteNetwork.point(p.center)
		if not view.has_point(pos):continue
		if float(p.heritage.damage)>35 and map.details_enabled:effect("dust_smoke",pos+Vector2(-23,-66),48,time)
		var marker=QuestSystem.marker(s,int(p.id),map.lod)
		if marker!="":draw_circle(pos+Vector2(44,-72),9,Color("#a9d574") if marker=="✓" else Color("#edc35c"));draw_string(map.font,pos+Vector2(39,-67),marker,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#203447"))
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
			var sprite="lk_actor_"+{"militia":"guard","infantry":"infantry","spearman":"spearman","archer":"archer","cavalry":"cavalry","crossbowman":"crossbowman","siege":"engineer"}.get(dominant,"infantry");var count=mini(3,maxi(1,int(ArmySystem.size(a)/110)))
			draw_circle(pos+Vector2(0,7),23,Color(0.04,.09,.1,.28))
			var action="hurt" if frame>=8 else "walk" if moving else "attack" if a.order=="siege" else "idle"
			for i in range(count):living_unit(sprite,pos+Vector2((i%2)*15-7,int(i/2)*10),action,direction,.60,map.army_time)
			var banner="rebel_army_banner" if realm.get("is_rebel",false) else "niyazov_standard" if realm.heraldry=="niyazov" else "royal_army_banner"
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
func living_unit(kind:String,pos:Vector2,action:String,direction:int,scale_value:float,clock:float):
	var anim=map.texture_metadata[kind].animation;var frames=anim.get(action,anim.idle)
	if frames.is_empty():frames=anim.idle
	var frame=int(frames[int(clock*anim.fps)%frames.size()]);draw_unit(kind,pos,frame,direction,scale_value)
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
