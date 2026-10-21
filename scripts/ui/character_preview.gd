extends Control
var map
var sprite:String="lk_actor_peasant"
var clock=0.0
var tick=0.0
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta):
	if not is_visible_in_tree():return
	clock+=delta;tick+=delta
	if tick>.125:tick=0;queue_redraw()
func _draw():
	var anim=map.texture_metadata[sprite].animation;var action=["idle","walk","interact","work","attack","hurt"][int(clock/3)%6]
	var frames=anim.get(action,anim.idle)
	if frames.is_empty():frames=anim.idle
	var frame=int(frames[int(clock*8)%frames.size()]);var direction=int(clock/4)%4
	var w=int(anim.frame_width);var h=int(anim.frame_height);var dimensions=Vector2(w,h)*1.5
	draw_texture_rect_region(map.texture_for(sprite),Rect2(Vector2((size.x-dimensions.x)/2,0),dimensions),Rect2(frame*w,direction*h,w,h))
