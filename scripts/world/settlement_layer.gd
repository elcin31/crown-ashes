extends Node2D
var map
var province:int
var stamp=""
func _process(_delta):
	if map.s==null:return
	var p=map.s.data.provinces[province];var at=RouteNetwork.point(p.center)
	visible=map.visible_world_rect().grow(180).has_point(at)
	if not visible:return
	var next="%s:%s:%s:%s"%[p.heritage.revision,p.owner,p.buildings,map.lod]
	if next!=stamp:stamp=next;queue_redraw()
func _draw():
	if map.s==null:return
	var s=map.s;var p=s.data.provinces[province];var r=s.data.realms[int(p.owner)];var slots=RouteNetwork.nav.slots[province]
	var sprites=[];var houses=mini(p.settlement_houses.size(),slots.size())
	for i in range(houses):
		var h=p.settlement_houses[i];var slot=(i+int(p.heritage.layout))%slots.size()
		sprites.append({"at":RouteNetwork.point(slots[slot]),"id":"lk_"+h.style+"_"+h.type,"width":37.0 if h.type=="peasant" else 42.0})
	var index=12
	for kind in p.buildings:
		if kind in ["road","niyazov_palace"] or int(p.buildings[kind])<=0:continue
		var at=RouteNetwork.point(slots[index%slots.size()]) if not slots.is_empty() else RouteNetwork.point(p.center)
		sprites.append({"at":at,"id":SettlementSystem.asset(p,kind),"width":49.0 if kind not in SettlementSystem.book().projects else 57.0})
		index+=1
	if not SettlementSystem.latest(p,"residence").is_empty():sprites.append({"at":RouteNetwork.point(p.center)+Vector2(0,-27),"id":SettlementSystem.asset(p,"residence"),"width":100.0 if int(p.id)==int(r.capital) else 76.0})
	sprites.sort_custom(func(a,b):return a.at.y<b.at.y)
	for item in sprites:
		var texture=map.texture_for(item.id)
		if texture==null:continue
		var size=Vector2(item.width,item.width*texture.get_height()/texture.get_width())
		var color=Color.WHITE.lerp(Color("#927b78"),float(p.heritage.damage)/130)
		draw_texture_rect(texture,Rect2(item.at-size*Vector2(.5,.90),size),false,color)
		if float(p.heritage.damage)>30:
			draw_line(item.at+Vector2(-7,-13),item.at+Vector2(4,-19),Color("#383340"),3)
			if float(p.heritage.damage)>60:draw_texture_rect(map.texture_for("battlefield_ruins"),Rect2(item.at+Vector2(-17,-12),Vector2(34,29)),false)
	var center=RouteNetwork.point(p.center)
	if int(p.id)==int(r.capital):
		draw_texture_rect(map.texture_for("niyazov_standard" if r.heraldry=="niyazov" else "royal_army_banner"),Rect2(center+Vector2(-45,-112),Vector2(24,46)),false)
