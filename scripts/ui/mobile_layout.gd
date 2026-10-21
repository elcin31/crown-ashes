class_name MobileLayout
extends RefCounted
# CanvasItems + expand keeps 720 logical pixels high and reveals extra map width.
# Insets are layout only. Input stays in Godot's viewport coordinates.
const TOP_HEIGHT=90.0
const BOTTOM_HEIGHT=72.0
static func safe_rect(viewport:Viewport,insets:Vector4=Vector4.ZERO)->Rect2:
	var extent=viewport.get_visible_rect().size
	var margins=insets
	if OS.get_name()=="Android" and insets==Vector4.ZERO:
		var safe=DisplayServer.get_display_safe_area();var window=DisplayServer.window_get_size()
		if window.x>0 and window.y>0 and safe.size.x>0 and safe.size.y>0:
			var factor=extent/Vector2(window)
			margins=Vector4(maxf(0,safe.position.x)*factor.x,maxf(0,safe.position.y)*factor.y,maxf(0,window.x-safe.end.x)*factor.x,maxf(0,window.y-safe.end.y)*factor.y)
	return Rect2(Vector2(margins.x,margins.y),Vector2(maxf(320,extent.x-margins.x-margins.z),maxf(240,extent.y-margins.y-margins.w)))
static func sidebar_width(width:float)->float:return clampf(width*.235,346,374)
static func fit_panel(panel:Control,requested:Vector2,available:Vector2):
	var dimensions=Vector2(minf(requested.x,available.x-32),minf(requested.y,available.y-32))
	panel.anchor_left=.5;panel.anchor_right=.5;panel.anchor_top=.5;panel.anchor_bottom=.5
	panel.offset_left=-dimensions.x/2;panel.offset_right=dimensions.x/2;panel.offset_top=-dimensions.y/2;panel.offset_bottom=dimensions.y/2
