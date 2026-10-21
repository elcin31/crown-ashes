extends Control
var map
var time:float=0.0
var accumulator:float=0.0
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(delta):
	time+=delta;accumulator+=delta
	if accumulator>=1.0/12:accumulator=0;queue_redraw()
func _draw():
	if map==null:return
	var picture=map.texture_for("story_palace");var scale_value=maxf(size.x/picture.get_width(),size.y/picture.get_height());var extent=picture.get_size()*scale_value
	draw_texture_rect(picture,Rect2((size-extent)/2,extent),false)
	draw_rect(Rect2(Vector2.ZERO,size),Color(.02,.045,.09,.035))
	# Small embers and torch sprites animate without another input surface or shader.
	if map.details_enabled:
		var anim=map.texture_metadata.fire.animation;var frame=int(time*8)%int(anim.columns)
		for anchor in [Vector2(.805,.725),Vector2(.871,.71)]:
			var pos=anchor*size;draw_texture_rect_region(map.texture_for("fire"),Rect2(pos,Vector2(18,24)),Rect2(frame*80,0,80,80),Color(1,1,1,.6))
