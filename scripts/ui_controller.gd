class_name UIController
extends CanvasLayer
var app
var root:Control
var hud:Control
var resource_labels={}
var date_label:Label
var realm_label:Label
var notice:Label
var side:PanelContainer
var side_body:VBoxContainer
var modal:Control
var modal_body:VBoxContainer
var modal_previous_speed:int=0
var minimap:Control
var selected_province:int=-1
var selected_army:int=-1
var toast_time:float=0
var chosen_realm:int=12
var chosen_difficulty:int=1
var difficulty_option:OptionButton
var choice_details:VBoxContainer
var last_report:int=-1
const GOLD=Color("#ddc28a")
const MUTED=Color("#91a7a5")
const GREEN=Color("#a4c4a0")
const RED=Color("#e39b88")
const RESOURCE_NAMES={"gold":"Золото","food":"Провиант","wood":"Дерево","stone":"Камень","iron":"Железо","manpower":"Резервы"}
const OFFICE_NAMES={"chancellor":"Канцлер","treasurer":"Казначей","marshal":"Маршал","spymaster":"Тайный советник","steward":"Управляющий"}
func _ready():
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	var theme=Theme.new();theme.default_font=load("res://assets/fonts/DejaVuSans.ttf");theme.default_font_size=17
	for kind in ["Button","OptionButton"]:
		theme.set_stylebox("normal",kind,style("#263b3e","#82714e",1,5));theme.set_stylebox("hover",kind,style("#3a5050","#cab47a",1,5));theme.set_stylebox("pressed",kind,style("#4a5549","#e5ca88",2,5));theme.set_stylebox("disabled",kind,style("#1e2b30","#374746",1,5));theme.set_color("font_color",kind,Color("#eddfb9"));theme.set_color("font_disabled_color",kind,Color("#647775"));theme.set_font_size("font_size",kind,16)
	theme.set_color("font_color","Label",Color("#d9dfcc"));theme.set_stylebox("panel","PanelContainer",style("#13242a","#8c7953",1,6));theme.set_constant("separation","VBoxContainer",9);theme.set_constant("separation","HBoxContainer",8)
	for kind in ["Button","OptionButton"]:
		for state in ["normal","pressed","hover","disabled"]:
			var index={"normal":0,"pressed":1,"hover":2,"disabled":3}[state]
			theme.set_stylebox(state,kind,button_surface(index))
		theme.set_stylebox("focus",kind,style("#00000000","#ebd395",1,0))
	theme.set_stylebox("panel","PanelContainer",frame_surface("ui_province_frame",10))
	root.theme=theme
func style(fill:String,border:String,width:int=1,padding:int=10)->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=Color(fill);s.border_color=Color(border);s.set_border_width_all(width);s.set_content_margin_all(padding);s.set_corner_radius_all(3);return s
func clear_root():
	modal=null;hud=null
	notice=null
	for child in root.get_children():
		if child is Control:child.hide()
		child.queue_free()
func box(parent,vertical:bool=true):
	var b=VBoxContainer.new() if vertical else HBoxContainer.new();b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(b);return b
func label(parent,text:String,font_size:int=17,color:Color=Color("#d9dfcc"),wrap:bool=true)->Label:
	var node=Label.new();node.text=text;node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",color)
	if wrap:node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node);return node
func heading(parent,text:String,size:int=24):
	var l=label(parent,text,size,GOLD);l.add_theme_font_override("font",load("res://assets/fonts/DejaVuSerif-Bold.ttf"));return l
func button(parent,text:String,callback:Callable,icon:String="",disabled:bool=false)->Button:
	var b=Button.new();b.text=text;b.custom_minimum_size.y=44;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.disabled=disabled
	if icon!="":b.icon=app.map.texture_for(icon);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",30)
	if text=="×":b.size_flags_horizontal=Control.SIZE_SHRINK_END
	b.pressed.connect(callback);parent.add_child(b);return b
func image_rect(parent,id:String,dimensions:Vector2)->TextureRect:
	var t=TextureRect.new();t.texture=app.map.texture_for(id);t.custom_minimum_size=dimensions;t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;t.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(t)
	if app.map.texture_metadata.get(id,{}).get("type","")=="portraits":
		var rim=NinePatchRect.new();rim.texture=app.map.texture_for("ui_portrait_frame");rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);rim.set_patch_margin(SIDE_LEFT,17);rim.set_patch_margin(SIDE_RIGHT,17);rim.set_patch_margin(SIDE_TOP,17);rim.set_patch_margin(SIDE_BOTTOM,17);rim.mouse_filter=Control.MOUSE_FILTER_IGNORE;t.add_child(rim)
	return t
func separator(parent):parent.add_child(HSeparator.new())
func kv(parent,key:String,value:String,color:Color=Color("#d9dfcc")):
	var row=box(parent,false);var k=label(row,key,16,MUTED,false);k.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label(row,value,17,color,false)
func cost_text(cost:Dictionary)->String:
	var chunks=[]
	for key in cost:
		if float(cost[key])>0:chunks.append("%d %s"%[int(cost[key]),RESOURCE_NAMES.get(key,key).to_lower()])
	return ", ".join(chunks)
func centered_panel(width:float,height:float)->PanelContainer:
	var panel=PanelContainer.new();panel.anchor_left=0.5;panel.anchor_right=0.5;panel.anchor_top=0.5;panel.anchor_bottom=0.5;panel.offset_left=-width/2;panel.offset_right=width/2;panel.offset_top=-height/2;panel.offset_bottom=height/2;root.add_child(panel);return panel
func shade(parent,alpha:float=0.65):
	var shade_node=ColorRect.new();shade_node.color=Color(0.025,0.055,0.07,alpha);shade_node.mouse_filter=Control.MOUSE_FILTER_IGNORE;shade_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);parent.add_child(shade_node);return shade_node
func show_main_menu():
	clear_root();app.map.hide();app.map.input_controller.enabled=false
	var backdrop=Control.new();backdrop.set_script(load("res://scripts/menu_backdrop.gd"));backdrop.map=app.map;root.add_child(backdrop)
	var panel=PanelContainer.new();panel.anchor_top=.5;panel.anchor_bottom=.5;panel.offset_left=56;panel.offset_right=504;panel.offset_top=-322;panel.offset_bottom=322;panel.add_theme_stylebox_override("panel",frame_surface("ui_ornate_menu_frame",24));root.add_child(panel)
	var left=box(panel);left.add_theme_constant_override("separation",8)
	image_rect(left,"ui_royal_crown",Vector2(128,74))
	heading(left,"CROWN & ASHES",31)
	label(left,"KINGDOM REFORGED · 0.2.0",15,GOLD)
	label(left,"Королевство перековано.
Судьба династии начинается с вас.",17,Color("#c9c2a2"))
	separator(left)
	button(left,"Новая кампания",show_selection,"ui_dynasty").custom_minimum_size.y=48
	var latest=SaveSystem.latest_slot()
	button(left,"Продолжить",func():app.load_campaign(latest),"ui_military",latest<0).custom_minimum_size.y=48
	button(left,"Загрузить кампанию",func():open_saves(false),"ui_economy").custom_minimum_size.y=48
	button(left,"Настройки",open_settings,"ui_laws").custom_minimum_size.y=48
	button(left,"Выход",func():app.request_quit()).custom_minimum_size.y=48
	label(left,"1183 · ЭЛЬДРАТ · ОФЛАЙН",13,MUTED)
	var caption=Label.new();caption.text="Одна корона. Тысячи судеб.";caption.add_theme_font_override("font",load("res://assets/fonts/DejaVuSerif-Bold.ttf"));caption.add_theme_font_size_override("font_size",24);caption.add_theme_color_override("font_color",GOLD);caption.anchor_left=1;caption.anchor_right=1;caption.anchor_top=1;caption.anchor_bottom=1;caption.offset_left=-525;caption.offset_right=-40;caption.offset_top=-66;caption.offset_bottom=-30;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(caption)
func show_selection():
	clear_root();app.map.show();shade(root,0.44)
	var panel=centered_panel(1060,620);var outer=box(panel);var header=box(outer,false);heading(header,"Выберите свою корону",28).size_flags_horizontal=Control.SIZE_EXPAND_FILL;button(header,"Назад",show_main_menu).size_flags_horizontal=Control.SIZE_SHRINK_END
	var row=box(outer,false);row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var scroll=ScrollContainer.new();scroll.custom_minimum_size.x=390;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_child(scroll);var list=box(scroll);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for id in [12,0,1,2,3,4,5,6,7,8,9,10,11]:
		var r=app.state.data.realms[id]
		button(list,r.name+(" · рекомендуется" if id==12 else ""),func():chosen_realm=id;refresh_selection(),r.heraldry)
	var right=box(row);right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;choice_details=box(right);choice_details.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var difficulty_row=box(right,false);label(difficulty_row,"Сложность",18,GOLD,false);difficulty_option=OptionButton.new();difficulty_option.custom_minimum_size=Vector2(220,44)
	for text in ["Лёгкая","Обычная","Сложная"]:difficulty_option.add_item(text)
	difficulty_option.select(chosen_difficulty);difficulty_option.item_selected.connect(func(index):chosen_difficulty=index);difficulty_row.add_child(difficulty_option)
	button(right,"Начать летопись · 1 января 1183",func():app.start_campaign(chosen_realm,chosen_difficulty),"ui_dynasty")
	refresh_selection()
func refresh_selection():
	for child in choice_details.get_children():child.queue_free()
	var s=app.state;var r=s.data.realms[chosen_realm];var c=s.data.characters[int(r.ruler)]
	var row=box(choice_details,false);image_rect(row,r.heraldry,Vector2(74,90));var col=box(row);heading(col,r.name,28);label(col,"Дом "+r.dynasty,19,GOLD)
	var pr=box(choice_details,false);image_rect(pr,VisualLibrary.portrait(c),Vector2(92,92));var d=box(pr);label(d,"%s, %d лет"%[c.name,c.age],21);label(d,"Военное %d · управление %d · дипломатия %d"%[c.martial,c.administration,c.diplomacy],16,MUTED)
	kv(choice_details,"Личных провинций",str(s.provinces_of(chosen_realm).size()));kv(choice_details,"Казна","%d золота"%int(r.resources.gold));kv(choice_details,"Армия","%d воинов"%int(army_count(chosen_realm)))
	label(choice_details,"Хаймир — графство под короной Аурелии. Развивайте земли, заключайте союзы, добейтесь герцогского титула и оспорьте власть старого короля." if chosen_realm==12 else "Характер правления: "+personality_name(r.personality)+". Укрепите границы, обеспечьте наследование и объедините Эльдрат под своей короной.",18)
	label(choice_details,"Цель: 35 провинций, императорский титул и стабильность ≥50 в течение 180 дней. Первые 180 дней ИИ не начинает внешние войны.",15,MUTED)
	var p=s.data.provinces[int(r.capital)];app.map.target_position=Vector2(p.center[0],p.center[1]);app.map.selected_province=int(p.id);app.map.queue_redraw()
func army_count(id:int)->int:
	var n=0
	for a in app.state.data.armies:
		if int(a.realm)==id:n+=ArmySystem.size(a)
	return n
func personality_name(kind:String)->String:return {"defensive":"Оборона","expansionist":"Завоевания","economic":"Экономика","diplomat":"Дипломатия","opportunist":"Выгодный момент"}.get(kind,kind)
func show_game():
	clear_root();app.map.show();hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(hud)
	resource_labels.clear()
	var top=PanelContainer.new();top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);top.offset_left=10;top.offset_right=-10;top.offset_top=8;top.offset_bottom=101;top.add_theme_stylebox_override("panel",frame_surface("ui_resource_bar",8));hud.add_child(top);var top_row=box(top,false)
	var identity=box(top_row);identity.custom_minimum_size.x=140;realm_label=label(identity,"",17,GOLD,false);button(identity,"Летопись",open_journal).custom_minimum_size.y=44
	for key in ["gold","food","wood","stone","iron","manpower"]:
		var col=box(top_row);col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;col.add_theme_constant_override("separation",0);label(col,RESOURCE_NAMES[key],13,MUTED,false);resource_labels[key]=label(col,"0",19,GOLD,false)
	var stability_col=box(top_row);label(stability_col,"Стабильность",13,MUTED,false);resource_labels.stability=label(stability_col,"0",19,GREEN,false)
	var time_col=box(top_row);date_label=label(time_col,"",16,GOLD,false);var speeds=box(time_col,false);speeds.add_theme_constant_override("separation",3)
	for speed in [0,1,2,4]:
		var b=button(speeds,"Ⅱ" if speed==0 else str(speed)+"×",func():app.set_speed(speed));b.custom_minimum_size=Vector2(44,44);b.add_theme_font_size_override("font_size",15)
	button(top_row,"☰",open_pause).custom_minimum_size=Vector2(46,44)
	var toolbar=HBoxContainer.new();toolbar.position=Vector2(16,111);toolbar.add_theme_constant_override("separation",7);hud.add_child(toolbar)
	var modes=OptionButton.new();modes.custom_minimum_size=Vector2(206,44)
	for name in ["Ландшафт","Политическая","Дипломатическая","Экономическая","Недовольство"]:modes.add_item(name)
	modes.select(app.map.mode);modes.item_selected.connect(func(index):app.map.mode=index;app.map.queue_redraw());toolbar.add_child(modes)
	button(toolbar,"К столице",func():app.map.focus_capital())
	button(toolbar,"−",func():app.map.input_controller.zoom_at(Vector2(640,360),1.0/1.2)).custom_minimum_size.x=44
	button(toolbar,"+",func():app.map.input_controller.zoom_at(Vector2(640,360),1.2)).custom_minimum_size.x=44
	var left=PanelContainer.new();left.anchor_top=1;left.anchor_bottom=1;left.offset_left=16;left.offset_right=235;left.offset_top=-244;left.offset_bottom=-84;hud.add_child(left);var col=box(left);var title_row=box(col,false);var r=app.state.data.realms[int(app.state.data.player)];image_rect(title_row,r.heraldry,Vector2(28,34));label(title_row,"ЭЛЬДРАТ · 1183",13,GOLD,false)
	minimap=Control.new();minimap.set_script(load("res://scripts/world/minimap.gd"));minimap.map=app.map;col.add_child(minimap)
	var bottom=PanelContainer.new();bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bottom.offset_left=10;bottom.offset_right=-10;bottom.offset_top=-74;bottom.offset_bottom=-8;hud.add_child(bottom);var nav=box(bottom,false)
	var callbacks=[open_economy,open_diplomacy,open_military,open_dynasty,open_intrigue,open_laws]
	var names=["Экономика","Дипломатия","Армия","Династия","Интриги","Законы"];var icons=["ui_economy","ui_diplomacy","ui_military","ui_dynasty","ui_intrigue","ui_laws"]
	for i in range(6):button(nav,names[i],callbacks[i],icons[i])
	side=PanelContainer.new();side.anchor_left=1;side.anchor_right=1;side.offset_left=-324;side.offset_right=-16;side.offset_top=111;side.anchor_bottom=1;side.offset_bottom=-84;hud.add_child(side)
	var side_scroll=ScrollContainer.new();side_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;side.add_child(side_scroll);side_body=box(side_scroll);side_body.custom_minimum_size.x=272;side_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var tip_panel=PanelContainer.new();tip_panel.anchor_left=0.5;tip_panel.anchor_right=0.5;tip_panel.anchor_top=1;tip_panel.anchor_bottom=1;tip_panel.offset_left=-325;tip_panel.offset_right=300;tip_panel.offset_top=-126;tip_panel.offset_bottom=-84;hud.add_child(tip_panel);notice=label(tip_panel,"",15,GOLD)
	selected_province=int(r.capital);selected_army=-1;refresh_side();refresh_hud();toast("Начните с фермы, рынка или найма. Откройте летопись для подсказок.",9)
func refresh_hud():
	if hud==null or not is_instance_valid(hud):return
	var s=app.state;var r=s.data.realms[int(s.data.player)]
	for key in RESOURCE_NAMES:
		resource_labels[key].text=format_number(float(r.resources[key]));resource_labels[key].add_theme_color_override("font_color",RED if float(r.resources[key])<=0 else GOLD)
	resource_labels.stability.text="%d%%"%int(r.stability);resource_labels.stability.add_theme_color_override("font_color",RED if r.stability<40 else GREEN)
	date_label.text=s.date_text()+" · "+("пауза" if app.clock.speed==0 else "%d×"%app.clock.speed);realm_label.text=r.name
	if minimap!=null:minimap.queue_redraw()
func format_number(value:float)->String:
	return "%.1fк"%(value/1000.0) if absf(value)>=10000 else str(int(value))
func toast(text:String,duration:float=5):
	if notice!=null and is_instance_valid(notice):notice.text=text;toast_time=duration
func _process(delta):
	if toast_time>0:
		toast_time-=delta
		if toast_time<=0 and notice!=null and is_instance_valid(notice):
			var count=app.state.data.events.size();notice.text="Событий ожидает решения: %d · Летопись"%count if count>0 else "Выберите провинцию или армию. Победа: 35 земель и империя."
func select_province(id:int):
	if app.map.destination_mode and selected_army>=0:
		app.map.destination_mode=false;act("move",{"army":selected_army,"province":id});return
	selected_province=id;selected_army=-1;app.map.selected_army=-1;side.visible=true;refresh_side()
func select_army(id:int):
	selected_army=id;app.map.selected_army=id;side.visible=true;refresh_side()
func refresh_side():
	if side==null or not is_instance_valid(side):return
	for child in side_body.get_children():child.queue_free()
	var head=box(side_body,false);heading(head,"Армия" if selected_army>=0 else "Владение",20).size_flags_horizontal=Control.SIZE_EXPAND_FILL;button(head,"×",func():side.hide();app.map.destination_mode=false).custom_minimum_size=Vector2(44,36)
	if selected_army>=0:army_side();return
	if selected_province<0:return
	var s=app.state;var p=s.data.provinces[selected_province];var r=s.data.realms[int(p.owner)]
	var row=box(side_body,false);image_rect(row,r.heraldry,Vector2(44,52));var col=box(row);heading(col,p.name,21);label(col,r.name,16,GOLD)
	label(side_body,{"plains":"Равнины","forest":"Леса","hills":"Холмы","mountains":"Горы","marsh":"Болота"}[p.terrain]+(" · Побережье" if p.coastal else ""),15,MUTED)
	image_rect(side_body,VisualLibrary.settlement(p,r),Vector2(128,102))
	kv(side_body,"Население",format_number(p.population));kv(side_body,"Развитие","%d / 100"%p.development);kv(side_body,"Недовольство","%d%%"%p.unrest,RED if p.unrest>55 else GREEN);kv(side_body,"Гарнизон",str(int(p.garrison)))
	var prod=EconomySystem.production(s,p);kv(side_body,"Производство еды","+%.0f / мес."%prod.food)
	var tax=float(p.population)/340.0*(0.65+float(p.development)/100.0)*[0.65,1.0,1.4][int(r.tax)]*(1.0-float(p.unrest)/130.0)
	kv(side_body,"Налоги","+%.1f / мес."%tax)
	if not p.siege.is_empty():label(side_body,"Осада: %d%% · прочность %d%%"%[p.siege.progress,p.siege.fort_health],16,RED)
	if int(p.occupation)>=0:label(side_body,"Оккупация: "+s.realm_name(int(p.occupation)),16,RED)
	separator(side_body);label(side_body,"Постройки",17,GOLD)
	for key in p.buildings:label(side_body,"• %s · ур. %d"%[s.buildings[key].name,p.buildings[key]],15)
	if not p.construction.is_empty():label(side_body,"Строится %s: %d дн."%[s.buildings[p.construction.type].name,p.construction.remaining],15,GOLD)
	if int(p.owner)==int(s.data.player):
		button(side_body,"Строительство",func():open_buildings(selected_province),"ui_economy")
		button(side_body,"Нанять войска",func():open_recruit(selected_province),"ui_military")
		button(side_body,"Развитие +5 · 65 зол.",func():act("develop",{"province":selected_province}))
		if int(p.id)!=int(r.capital):button(side_body,"Передать вассалу",func():open_land_grant(selected_province))
	else:button(side_body,"Переговоры",func():open_diplomacy(int(p.owner)),"ui_diplomacy")
func army_side():
	var s=app.state;var a=s.army_by_id(selected_army)
	if a.is_empty():label(side_body,"Армия расформирована.");return
	var r=s.data.realms[int(a.realm)];var row=box(side_body,false);image_rect(row,r.heraldry,Vector2(44,52));heading(row,r.name,20)
	kv(side_body,"Численность",str(ArmySystem.size(a)));kv(side_body,"Мораль","%d%%"%a.morale);kv(side_body,"Снабжение","%d%%"%a.supply)
	label(side_body,"В провинции "+s.data.provinces[int(a.province)].name,16,MUTED)
	if int(a.commander)>=0:label(side_body,"Командует: "+s.data.characters[int(a.commander)].name,16)
	for unit in a.units:kv(side_body,s.units[unit].name,str(int(a.units[unit])))
	if not a.route.is_empty():label(side_body,"Цель: %s\nБлижайший переход: %d дн."%[s.data.provinces[int(a.route[-1])].name,a.travel_left],16,GOLD)
	elif a.order=="siege":label(side_body,"Осаждает укрепления",17,RED)
	if int(a.realm)!=int(s.data.player):return
	button(side_body,"Указать цель на карте",func():app.map.destination_mode=true;side.hide();toast("Коснитесь провинции назначения. Отмена — кнопкой «Назад».",9))
	button(side_body,"Отменить приказ",func():act("cancel",{"army":selected_army}))
	var row2=box(side_body,false);button(row2,"Разделить",func():act("split",{"army":selected_army}));button(row2,"Объединить",func():act("merge",{"army":selected_army}))
	button(side_body,"Назначить командира",func():open_commander(selected_army))
	button(side_body,"Отступить",func():act("retreat",{"army":selected_army}));button(side_body,"Распустить",func():act("disband",{"army":selected_army}))
func act(command:String,args:Dictionary={},refresh:Callable=Callable()):
	var result=app.commands.execute(int(app.state.data.player),command,args);toast(result.message,7);refresh_hud();refresh_side();app.map.queue_redraw()
	if refresh.is_valid():refresh.call()
	return result
func open_window(title:String,width:float=900,height:float=580):
	if modal!=null and is_instance_valid(modal):
		modal.hide();modal.queue_free()
	else:modal_previous_speed=app.clock.speed
	app.clock.speed=0
	app.map.input_controller.enabled=false;app.map.input_controller.reset_gestures()
	modal=Control.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.mouse_filter=Control.MOUSE_FILTER_STOP;root.add_child(modal);shade(modal,0.74)
	var panel=PanelContainer.new();panel.anchor_left=0.5;panel.anchor_right=0.5;panel.anchor_top=0.5;panel.anchor_bottom=0.5;panel.offset_left=-width/2;panel.offset_right=width/2;panel.offset_top=-height/2;panel.offset_bottom=height/2;modal.add_child(panel)
	var outer=box(panel);var row=box(outer,false);heading(row,title,25).size_flags_horizontal=Control.SIZE_EXPAND_FILL;button(row,"×",close_window).custom_minimum_size=Vector2(46,44)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;outer.add_child(scroll);modal_body=box(scroll);modal_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	refresh_hud()
func close_window():
	if modal!=null and is_instance_valid(modal):modal.queue_free();modal=null
	app.clock.speed=modal_previous_speed if app.running else 0;app.map.input_controller.enabled=app.running;refresh_hud();refresh_side()
func open_buildings(pid:int):
	open_window("Строительство · "+app.state.data.provinces[pid].name)
	var s=app.state;var p=s.data.provinces[pid]
	if not p.construction.is_empty():label(modal_body,"Работы: %s, осталось %d дней."%[s.buildings[p.construction.type].name,p.construction.remaining],18,GOLD)
	label(modal_body,"Одна стройка на провинцию. Уровни повышают стоимость и эффект. Число мест растёт с развитием.",16,MUTED)
	for key in s.buildings:
		var b=s.buildings[key];var level=int(p.buildings.get(key,0));var cost={}
		for k in b.cost:cost[k]=b.cost[k]*(level+1)
		var row=box(modal_body,false);image_rect(row,VisualLibrary.building(key,mini(3,level+1),p),Vector2(72,72));var info=box(row);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		label(info,"%s · уровень %d → %d"%[b.name,level,mini(3,level+1)],19,GOLD);label(info,cost_text(cost)+" · %d дн."%(int(b.days)*(level+1)),15);label(info,building_effect(b),14,MUTED)
		button(row,"Строить",func():act("build",{"province":pid,"kind":key},func():open_buildings(pid))).custom_minimum_size.x=110
		separator(modal_body)
func building_effect(b:Dictionary)->String:
	var effects=[]
	for key in b.effect:
		var names={"fort":"укрепления","unrest":"недовольство","legitimacy":"легитимность","speed":"скорость пути","storage":"вместимость"}
		effects.append("%s %s"%[("+" if float(b.effect[key])>0 else "")+str(b.effect[key]),RESOURCE_NAMES.get(key,names.get(key,key)).to_lower()])
	return "; ".join(effects)+" · содержание %.1f зол./мес."%b.upkeep
func open_recruit(pid:int):
	open_window("Набор войск · "+app.state.data.provinces[pid].name)
	var s=app.state
	label(modal_body,"Отряд: 40 воинов. Обучение — 8 дней. Сильные части требуют казарм. Пища расходуется каждый день.",17,MUTED)
	for q in s.data.recruitments:
		if int(q.province)==pid:label(modal_body,"Обучается %s · %d дн."%[s.units[q.unit].name,q.days],17,GOLD)
	for key in s.units:
		var u=s.units[key];var row=box(modal_body,false)
		var atlas=AtlasTexture.new();atlas.atlas=app.map.texture_for(u.asset);atlas.region=Rect2(0,0,40,56);var img=TextureRect.new();img.texture=atlas;img.custom_minimum_size=Vector2(48,60);img.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;img.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;img.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(img)
		var info=box(row);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label(info,u.name,19,GOLD);label(info,cost_text(u.cost),15);label(info,"Атака %.1f · защита %.1f · содержание %.1f / мес."%[u.attack,u.defense,u.upkeep],14,MUTED)
		button(row,"Нанять",func():act("recruit",{"province":pid,"unit":key},func():open_recruit(pid))).custom_minimum_size.x=110;separator(modal_body)
func open_economy():
	open_window("Казна и хозяйство")
	var s=app.state;var id=int(s.data.player);var r=s.data.realms[id];var b=EconomySystem.forecast(s,id)
	heading(modal_body,"Бюджет на 30 дней",21)
	for key in ["tax","trade","vassals","army","buildings","court"]:kv(modal_body,{"tax":"Налоги","trade":"Рынки и порты","vassals":"Вассальные платежи (сальдо)","army":"Содержание армии","buildings":"Содержание построек","court":"Двор"}[key],"%.1f"%b[key])
	kv(modal_body,"Чистый доход","%+.1f золота"%b.net,GREEN if b.net>=0 else RED)
	separator(modal_body);heading(modal_body,"Налоги",20);var taxes=box(modal_body,false)
	for level in range(3):button(taxes,["Низкие · спокойствие","Обычные","Высокие · недовольство"][level]+(" ✓" if int(r.tax)==level else ""),func():act("tax",{"level":level},open_economy))
	separator(modal_body);heading(modal_body,"Рынок ресурсов",20);label(modal_body,"Сделки по 50 ед.; цена меняется от спроса. Продажа дешевле покупки.",16,MUTED)
	for key in ["food","wood","stone","iron"]:
		var row=box(modal_body,false);label(row,"%s: %d"%[RESOURCE_NAMES[key],r.resources[key]],18,GOLD).size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var price=s.data.market[key];button(row,"Купить · %.0f"%(price*50*1.18),func():act("trade",{"resource":key,"buy":true,"amount":50},open_economy));button(row,"Продать · %.0f"%(price*50*0.82),func():act("trade",{"resource":key,"buy":false,"amount":50},open_economy))
	separator(modal_body);heading(modal_body,"Провинции",20)
	for p in s.provinces_of(id):button(modal_body,"%s · развитие %d · население %d"%[p.name,p.development,p.population],func():close_window();select_province(int(p.id));app.map.selected_province=int(p.id);app.map.target_position=Vector2(p.center[0],p.center[1]);app.map.queue_redraw())
func open_diplomacy(target:int=-1):
	var s=app.state;var id=int(s.data.player)
	if target<0:
		if selected_province>=0 and int(s.data.provinces[selected_province].owner)!=id:target=int(s.data.provinces[selected_province].owner)
		else:
			var neighbors=ProvinceSystem.neighbors(s,id);target=int(neighbors[0]) if not neighbors.is_empty() else (0 if id!=0 else 1)
	open_window("Дипломатия",1030,610)
	var row=box(modal_body,false);var list=box(row);list.custom_minimum_size.x=240
	for realm in s.data.realms:
		var other=int(realm.id)
		if other==id or s.provinces_of(other).is_empty():continue
		button(list,realm.name+" (%+d)"%int(s.relation(id,other).value),func():open_diplomacy(other),realm.heraldry)
	var content=box(row);content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var r=s.data.realms[target];var rel=s.relation(id,target);var header=box(content,false);image_rect(header,r.heraldry,Vector2(62,74));var caption=box(header);heading(caption,r.name,25);label(caption,"Дом "+r.dynasty+" · "+personality_name(r.personality),16,MUTED)
	var ruler=s.data.characters[int(r.ruler)];label(content,"Правитель: %s, %d лет"%[ruler.name,ruler.age],18)
	kv(content,"Отношения","%+d"%int(rel.value));kv(content,"Армия","%d воинов"%army_count(target));kv(content,"Провинции",str(s.provinces_of(target).size()))
	if int(r.suzerain)>=0:label(content,"Сюзерен: "+s.realm_name(int(r.suzerain)),15,MUTED)
	if rel.alliance:label(content,"Действует союз: доступ через земли и дружественная дипломатия.",16,GREEN)
	if int(rel.truce_until)>int(s.data.day):label(content,"Перемирие: ещё %d дней."%(int(rel.truce_until)-int(s.data.day)),16,GOLD)
	if int(rel.nap_until)>int(s.data.day):label(content,"Пакт о ненападении: ещё %d дней."%(int(rel.nap_until)-int(s.data.day)),16,GOLD)
	separator(content)
	if s.at_war(id,target):
		var w=s.war_between(id,target);heading(content,"Состояние войны",22);label(content,"Основание: "+reason_name(w.reason),17);kv(content,"Военный счёт","%+.1f"%(w.score*(1 if int(w.a)==id else -1)))
		label(content,"Для требований: счёт +20; одна провинция за каждые 20 очков. Передаются только занятые земли.",16,MUTED)
		for term in ["white","land","gold","independence","throne"]:
			button(content,{"white":"Предложить белый мир","land":"Потребовать занятые земли","gold":"Потребовать выплату золота","independence":"Признание независимости","throne":"Передача престола (+55)"}[term],func():act("peace",{"target":target,"terms":term},func():open_diplomacy(target)))
	else:
		var actions=[["improve","Улучшить отношения · 12 зол."],["worsen","Ухудшить отношения"],["gift","Отправить подарок · 35 зол."],["break_alliance" if rel.alliance else "alliance","Расторгнуть союз" if rel.alliance else "Предложить союз"],["nap","Пакт о ненападении"],["tribute","Потребовать дань"],["grant_access","Предоставить проход"],["request_access","Запросить проход"]]
		for item in actions:
			var action=item[0];var title=item[1]
			if action in ["alliance","nap","tribute","request_access"]:title+=" · %d%%"%DiplomacySystem.acceptance(s,id,target,action)
			button(content,title,func():act("diplomacy",{"target":target,"action":action},func():open_diplomacy(target)))
		button(content,"Династический брак",open_marriage,"ui_dynasty")
		separator(content);label(content,"Объявить войну (40 зол., 50 провианта)",17,RED)
		button(content,"Территориальная претензия",func():act("war",{"target":target,"reason":"claim"},func():open_diplomacy(target)),"ui_military")
		if int(s.data.realms[id].suzerain)==target:button(content,"Война за независимость",func():act("war",{"target":target,"reason":"independence"},func():open_diplomacy(target)))
		if target in s.data.realms[id].claims:button(content,"Борьба за престол",func():act("war",{"target":target,"reason":"throne"},func():open_diplomacy(target)))
		if rel.value<=-45:button(content,"Ответ на провокации",func():act("war",{"target":target,"reason":"retaliation"},func():open_diplomacy(target)))
func reason_name(reason:String)->String:return {"claim":"Территориальная претензия","independence":"Независимость","throne":"Борьба за престол","retaliation":"Ответ на провокации"}.get(reason,reason)
func open_military():
	open_window("Армия и войны")
	var s=app.state;var id=int(s.data.player)
	label(modal_body,"Армии потребляют еду ежедневно, содержание оплачивается каждые 30 дней. Перемещение требует связного доступного пути. Для штурма крепости дождитесь завершения осады.",17,MUTED)
	for a in s.data.armies:
		if int(a.realm)!=id:continue
		var row=box(modal_body,false);var info=box(row);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading(info,"Армия №%d · %d воинов"%[int(a.id)+1,ArmySystem.size(a)],21);label(info,"%s · мораль %d · припасы %d"%[s.data.provinces[int(a.province)].name,a.morale,a.supply],16)
		button(row,"Выбрать",func():close_window();select_army(int(a.id));app.map.target_position=app.map.army_position(a)).custom_minimum_size.x=130
	separator(modal_body)
	for p in s.provinces_of(id):button(modal_body,"Набор: "+p.name,func():open_recruit(int(p.id)),"ui_military")
	separator(modal_body);heading(modal_body,"Текущие войны",21)
	var count=0
	for w in s.data.wars:
		if int(w.a)!=id and int(w.b)!=id:continue
		count+=1;var enemy=int(w.b) if int(w.a)==id else int(w.a);button(modal_body,"%s · %s · счёт %+.1f"%[s.realm_name(enemy),reason_name(w.reason),w.score*(1 if int(w.a)==id else -1)],func():open_diplomacy(enemy))
	if count==0:label(modal_body,"Ваше владение пребывает в мире.",17,GREEN)
	separator(modal_body);heading(modal_body,"Боевые донесения",21)
	for report in s.data.reports:
		if int(report.winner)==id or int(report.loser)==id:
			button(modal_body,"%s · %s"%[s.data.provinces[int(report.province)].name,"Победа" if int(report.winner)==id else "Поражение"],func():open_battle_report(report))
func open_battle_report(report:Dictionary):
	open_window("Битва у "+app.state.data.provinces[int(report.province)].name,720,530)
	image_rect(modal_body,"event_great_battle",Vector2(512,256));heading(modal_body,"Победа: "+app.state.realm_name(int(report.winner)),23)
	kv(modal_body,"Силы наступающих",str(int(report.before_a)));kv(modal_body,"Силы защитников",str(int(report.before_d)));kv(modal_body,"Потери победителя",str(int(report.winner_loss)));kv(modal_body,"Потери проигравшего",str(int(report.loser_loss)))
	label(modal_body,"Учтены состав, снабжение, мораль, командир и рельеф. Проигравшая армия отступила в безопасное владение либо уничтожена.",16,MUTED)
func open_commander(army:int):
	open_window("Назначение командующего",720,550)
	var s=app.state;var id=int(s.data.player)
	for c in s.data.characters:
		if c.alive and int(c.realm)==id and c.age>=16:
			button(modal_body,"%s · военное дело %d · верность %d"%[c.name,c.martial,c.loyalty],func():act("commander",{"army":army,"character":int(c.id)});close_window(),VisualLibrary.portrait(c))
func open_dynasty():
	open_window("Династия и королевский совет",1000,610)
	var s=app.state;var r=s.data.realms[int(s.data.player)];var c=s.data.characters[int(r.ruler)]
	var row=box(modal_body,false);image_rect(row,VisualLibrary.portrait(c),Vector2(120,120));var info=box(row);heading(info,"%s из дома %s"%[c.name,r.dynasty],25);label(info,"%s · %d лет · легитимность %d"%[["Граф","Герцог","Король","Император"][int(r.title)],c.age,r.legitimacy],18,GOLD);label(info,"Военное %d · управление %d · дипломатия %d · интрига %d"%[c.martial,c.administration,c.diplomacy,c.intrigue],16);label(info,", ".join(c.traits),16,MUTED)
	if c.age<16:label(modal_body,"Регентство: совет управляет владением до 16-летия правителя.",17,RED)
	separator(modal_body);heading(modal_body,"Семья",21);image_rect(modal_body,"ui_dynasty_tree",Vector2(256,68))
	if int(c.spouse)>=0:
		var spouse=s.data.characters[int(c.spouse)];button(modal_body,"Супруг(а): %s · %d лет"%[spouse.name,spouse.age],func():open_character(int(spouse.id)),VisualLibrary.portrait(spouse))
	else:label(modal_body,"Правитель не состоит в браке.",16,MUTED)
	if int(r.heir)>=0:
		var heir=s.data.characters[int(r.heir)];button(modal_body,"Наследник: %s · %d лет"%[heir.name,heir.age],func():open_character(int(heir.id)),VisualLibrary.portrait(heir))
	else:label(modal_body,"Нет законного наследника: династия под угрозой.",17,RED)
	var alive_children=0
	for cid in c.children:
		var child=s.data.characters[int(cid)]
		if child.alive:alive_children+=1;button(modal_body,"└ %s · %d лет"%[child.name,child.age],func():open_character(int(child.id)),VisualLibrary.portrait(child))
	if alive_children==0:label(modal_body,"Детей пока нет. Допустимые родственники могут продолжить род.",16,MUTED)
	button(modal_body,"Заключить династический брак",open_marriage,"ui_dynasty")
	separator(modal_body);heading(modal_body,"Королевский совет",21)
	for slot in OFFICE_NAMES:
		var cid=int(r.council.get(slot,-1));var text=OFFICE_NAMES[slot]+": "+(s.data.characters[cid].name if cid>=0 else "вакансия")
		if cid>=0:text+=" · бонус %.1f"%CharacterSystem.bonus(s,int(r.id),slot)
		button(modal_body,text,func():open_appointment(slot),VisualLibrary.portrait(s.data.characters[cid]) if cid>=0 else "ui_dynasty")
	separator(modal_body);heading(modal_body,"Вассалы и землевладельцы",21)
	for realm in s.data.realms:
		if int(realm.suzerain)==int(r.id):button(modal_body,"Вассал: "+realm.name,func():open_diplomacy(int(realm.id)),realm.heraldry)
	var listed=[]
	for p in s.provinces_of(int(r.id)):
		var holder=int(p.holder)
		if holder==int(r.ruler) or holder in listed:continue
		listed.append(holder);var noble=s.data.characters[holder];var holdings=0
		for pp in s.provinces_of(int(r.id)):
			if int(pp.holder)==holder:holdings+=1
		button(modal_body,"%s · %d провинц. · верность %d"%[noble.name,holdings,noble.loyalty],func():open_character(holder),VisualLibrary.portrait(noble))
	if listed.is_empty():label(modal_body,"Все земли пока принадлежат вам лично. При расширении появятся влиятельные землевладельцы.",16,MUTED)
func open_character(cid:int):
	open_window("Персонаж",760,560)
	var s=app.state;var c=s.data.characters[cid];var row=box(modal_body,false);image_rect(row,VisualLibrary.portrait(c),Vector2(128,128));var info=box(row);heading(info,c.name+" · "+s.data.dynasties[int(c.dynasty)].name,25);label(info,"Возраст %d · %s"%[c.age,"жив(а)" if c.alive else "умер(ла)"],18);label(info,"Принадлежность: "+s.realm_name(int(c.realm)),17);label(info,", ".join(c.traits),16,MUTED)
	for key in ["martial","administration","diplomacy","intrigue","loyalty","ambition","health"]:kv(modal_body,{"martial":"Военное дело","administration":"Управление","diplomacy":"Дипломатия","intrigue":"Интрига","loyalty":"Верность","ambition":"Амбиции","health":"Здоровье"}[key],str(int(c[key])))
	for secret in c.secrets:label(modal_body,"Сведения: "+secret,16,GOLD)
	if c.alive:button(modal_body,"Тайные действия",func():open_intrigue(cid),"ui_intrigue")
	if int(c.realm)==int(s.data.player) and c.alive:button(modal_body,"Поддержать наследником (выборы)",func():act("heir",{"character":cid}))
func open_appointment(slot:String):
	open_window(OFFICE_NAMES[slot]+": кандидаты",780,560)
	var s=app.state;var id=int(s.data.player)
	label(modal_body,"Советник занимает одну должность. Новый получает +10 верности, отстранённый теряет 8. Бонусы умеренны и зависят от компетенции.",16,MUTED)
	for c in s.data.characters:
		if not c.alive or int(c.realm)!=id or c.age<16 or int(c.id)==int(s.data.realms[id].ruler):continue
		button(modal_body,"%s · упр. %d · дипл. %d · воен. %d · интр. %d"%[c.name,c.administration,c.diplomacy,c.martial,c.intrigue],func():act("appoint",{"slot":slot,"character":int(c.id)},open_dynasty),VisualLibrary.portrait(c))
func open_marriage():
	open_window("Династический брак",900,560)
	var s=app.state;var id=int(s.data.player)
	label(modal_body,"Брак стоит 45 золота, повышает легитимность и отношения между домами. Дети рождаются в браке у родителей от 18 лет; возраст матери — до 44. Близкое родство исключено.",17,MUTED)
	var ours=OptionButton.new();var theirs=OptionButton.new();ours.custom_minimum_size.y=48;theirs.custom_minimum_size.y=48;modal_body.add_child(ours);modal_body.add_child(theirs)
	for c in s.data.characters:
		if not c.alive or c.age<16 or int(c.spouse)>=0:continue
		var control=ours if int(c.realm)==id else theirs
		control.add_item("%s %s · %d · %s"%[c.name,s.data.dynasties[int(c.dynasty)].name,c.age,"муж." if c.gender=="m" else "жен."],int(c.id))
	button(modal_body,"Предложить брак · 45 зол.",func():
		if ours.item_count==0 or theirs.item_count==0:toast("Нет свободных взрослых кандидатов.");return
		act("marry",{"a":ours.get_selected_id(),"b":theirs.get_selected_id()},open_marriage))
	label(modal_body,"Соседи чаще соглашаются при отношениях не ниже −10. Враждующие семьи сначала должны заключить мир. Политические последствия наступают сразу.",16,MUTED)
func open_intrigue(target:int=-1):
	open_window("Тайные дела",920,580)
	var s=app.state;var id=int(s.data.player);var options=OptionButton.new();options.custom_minimum_size.y=46;modal_body.add_child(options)
	for c in s.data.characters:
		if not c.alive or c.age<16:continue
		options.add_item("%s · %s · верность %d"%[c.name,s.realm_name(int(c.realm)),c.loyalty],int(c.id))
		if int(c.id)==target:options.select(options.item_count-1)
	label(modal_body,"Результат зависит от тайного советника и навыка цели. Неудача может раскрыть операцию и повредить репутации. Параллельно против одной цели действует одна операция.",16,MUTED)
	for kind in IntrigueSystem.SPECS:
		var spec=IntrigueSystem.SPECS[kind];button(modal_body,"%s · %d зол. · %d дн."%[spec.name,spec.gold,spec.days],func():
			if options.item_count>0:act("intrigue",{"character":options.get_selected_id(),"kind":kind},func():open_intrigue(options.get_selected_id())),"ui_intrigue")
	separator(modal_body);heading(modal_body,"Текущие операции",20)
	for op in s.data.intrigues:
		if int(op.actor)==id:label(modal_body,"%s → %s · осталось %d дн."%[IntrigueSystem.SPECS[op.kind].name,s.data.characters[int(op.target)].name,op.remaining],17,GOLD)
func open_laws():
	open_window("Законы и притязания")
	var s=app.state;var r=s.data.realms[int(s.data.player)]
	kv(modal_body,"Титул",["Граф","Герцог","Король","Император"][int(r.title)]);kv(modal_body,"Легитимность",str(int(r.legitimacy)))
	if int(r.suzerain)>=0:label(modal_body,"Сюзерен: "+s.realm_name(int(r.suzerain))+". Вы платите 12% налогов и торговли. Герцогский титул требует 3 провинции; королевский — 8 и освобождает от вассальной зависимости.",17,MUTED)
	button(modal_body,"Повысить титул",func():act("title",{},open_laws),"ui_dynasty")
	label(modal_body,"Герцог: 3 земли / 180 зол. Король: 8 / 420. Император: 35 / 900. Для каждого нужна легитимность ≥60.",16,MUTED)
	separator(modal_body);heading(modal_body,"Наследование",21);label(modal_body,"Сейчас: "+("Первородство" if r.law=="primogeniture" else "Выборное наследование"),19,GOLD)
	label(modal_body,"Первородство отдаёт корону старшему допустимому ребёнку или родственнику. При выборах учитываются навыки, лояльность и поддержка кандидата. Смена закона: 50 золота, −8 стабильности, −5 легитимности.",17,MUTED)
	button(modal_body,"Принять первородство",func():act("law",{"law":"primogeniture"},open_laws));button(modal_body,"Принять выборное наследование",func():act("law",{"law":"elective"},open_laws))
	separator(modal_body);heading(modal_body,"Путь к империи",21)
	kv(modal_body,"Провинции","%d / 35"%s.provinces_of(int(s.data.player)).size());kv(modal_body,"Удержание условий","%d / 180 дней"%int(s.data.victory_days));label(modal_body,"После победы можно продолжить свободную игру. Смерть правителя сама по себе не завершает кампанию при наличии наследника.",16,MUTED)
func open_journal():
	open_window("Летопись и поручения",950,610)
	var s=app.state;var id=int(s.data.player);var r=s.data.realms[id]
	heading(modal_body,"Первые шаги",21)
	label(modal_body,"1. Постройте ферму или рынок в своей провинции.\n2. Развивайте земли и держите положительный бюджет.\n3. Наберите войска, оставив деньги на содержание.\n4. Подарками и посольствами подготовьте союз.\n5. Объявите обоснованную войну, выиграйте осаду и потребуйте землю при мире.\n6. Соберите 3 провинции и провозгласите герцогство.\n7. Получите претензию на престол через события и бросьте вызов королю.",17)
	separator(modal_body)
	if not s.data.events.is_empty():button(modal_body,"Решить событие (%d)"%s.data.events.size(),open_event,"ui_dynasty")
	for entry in s.data.log:label(modal_body,"День %d · %s"%[int(entry.day)+1,entry.text],16,GOLD if int(entry.day)>int(s.data.day)-15 else MUTED)
func open_event():
	var s=app.state
	if s.data.events.is_empty():toast("Нет ожидающих событий.");return
	var entry=s.data.events[0];var e=EventSystem.definition(s,entry)
	open_window(e.title,820,590);image_rect(modal_body,VisualLibrary.event_picture(e.get("id",entry.get("event_id","")),e.get("illustration","coronation")),Vector2(512,256));label(modal_body,e.description,19)
	if entry.has("special"):button(modal_body,"Продолжить",func():act("event",{"index":0,"choice":0});close_window())
	else:
		for index in range(e.choices.size()):
			var choice=e.choices[index];var text=choice.label+"\n"+effect_text(choice.effects)
			var b=button(modal_body,text,func():act("event",{"index":0,"choice":index});close_window());b.custom_minimum_size.y=62
func effect_text(effects:Dictionary)->String:
	var parts=[]
	var names={"unrest":"недовольство","development":"развитие","stability":"стабильность","legitimacy":"легитимность","population":"население","loyalty":"верность","morale":"мораль","health":"здоровье","relation":"отношения","epidemic":"эпидемия (дни)","army_losses":"потери армии","claim":"претензия","birth":"новый ребёнок","marriage":"брак","advisor_death":"смерть советника","commander":"новый командир"}
	for key in effects:parts.append("%s %s"%[("+" if float(effects[key])>0 else "")+str(effects[key]),RESOURCE_NAMES.get(key,names.get(key,key)).to_lower()])
	return "; ".join(parts)
func open_pause():
	open_window("Кампания на паузе",600,510)
	button(modal_body,"Вернуться к карте",close_window)
	button(modal_body,"Сохранить",func():open_saves(true))
	button(modal_body,"Загрузить",func():open_saves(false))
	button(modal_body,"События и летопись",open_journal)
	button(modal_body,"Настройки",open_settings)
	button(modal_body,"Главное меню (автосохранение)",func():SaveSystem.save_game(app.state,0);close_window();app.return_to_menu())
func open_saves(saving:bool):
	open_window("Сохранение кампании" if saving else "Загрузка кампании",850,550)
	label(modal_body,"3 ручных слота и отдельное автосохранение. Запись проверяется контрольной суммой и сохраняет предыдущую исправную копию.",17,MUTED)
	for item in SaveSystem.slots():
		var slot=int(item.slot);var row=box(modal_body,false);label(row,("Авто" if slot==0 else "Слот %d"%slot)+" · "+item.label,18,GOLD).size_flags_horizontal=Control.SIZE_EXPAND_FILL
		if saving:
			if slot>0:button(row,"Записать",func():var result=SaveSystem.save_game(app.state,slot);toast(result.message);open_saves(true)).custom_minimum_size.x=140
		else:button(row,"Загрузить",func():close_window();app.load_campaign(slot),"",not item.exists).custom_minimum_size.x=140
		separator(modal_body)
func open_settings():
	open_window("Настройки и управление",820,550)
	label(modal_body,"Android: один палец — движение карты; два — масштаб; короткое касание — выбор. Для похода выберите армию, затем «Указать цель». Кнопка Back закрывает окно, отменяет выбор цели или открывает паузу.",18)
	label(modal_body,"Desktop: перетаскивание левой/средней кнопкой, колесо — масштаб, Home — столица, пробел — пауза, Esc — назад, F5 — быстрое сохранение.",17,MUTED)
	button(modal_body,"Ограничение кадров: %d FPS"%Engine.max_fps,func():Engine.max_fps=30 if Engine.max_fps==60 else 60;app.save_settings();open_settings())
	button(modal_body,"Жители и эффекты: "+("включены" if app.map.details_enabled else "выключены"),func():app.map.details_enabled=not app.map.details_enabled;app.save_settings();open_settings())
	if OS.get_name()!="Android":button(modal_body,"Полноэкранный режим",func():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED))
	separator(modal_body);label(modal_body,"Графика: единый High-Detail Pixel Art, 246 ресурсов. В версии 0.2.0 — сухопутная стратегия; корабли показывают торговые маршруты. Звуковая дорожка пока отсутствует.",16,MUTED)
func show_outcome():
	var result=app.state.data.outcome
	open_window("Империя основана" if result=="victory" else "Летопись завершена",800,560);modal_previous_speed=0
	image_rect(modal_body,"event_empire_foundation" if result=="victory" else "event_royal_funeral",Vector2(512,256))
	if result=="victory":image_rect(modal_body,"ui_victory_ornament",Vector2(256,128))
	label(modal_body,"Ваша династия удержала 35 провинций под императорской короной. Эльдрат признаёт вашу власть." if result=="victory" else "Последнее владение потеряно." if result=="defeat_land" else "Династия пресеклась: допустимых наследников не осталось.",20,GOLD)
	if result=="victory":button(modal_body,"Продолжить свободную игру",func():app.state.data.freeplay=true;app.state.data.outcome="";app.outcome_shown=false;close_window())
	button(modal_body,"Главное меню",func():close_window();app.return_to_menu())
func handle_back():
	if modal!=null and is_instance_valid(modal):close_window();return
	if app.running:
		if app.map.destination_mode:app.map.destination_mode=false;toast("Приказ перемещения отменён.");return
		if selected_army>=0:selected_army=-1;app.map.selected_army=-1;app.map.queue_redraw();side.hide();return
		open_pause()
	else:show_main_menu()

func open_land_grant(pid:int):
	open_window("Передача владения",800,550)
	label(modal_body,"Вассал получает землю и +16 верности. Лишение владения снижает лояльность прежнего владельца и легитимность. Провинции одного непокорного дворянина могут совместно поднять восстание.",17,MUTED)
	for c in app.state.data.characters:
		if c.alive and int(c.realm)==int(app.state.data.player) and c.age>=16:
			button(modal_body,"%s · верность %d · управление %d"%[c.name,c.loyalty,c.administration],func():act("grant",{"province":pid,"character":int(c.id)});close_window(),VisualLibrary.portrait(c))

func blocks_world_at(point:Vector2)->bool:
	if not app.running or (modal!=null and is_instance_valid(modal)):return true
	if hud==null or not is_instance_valid(hud):return true
	for child in hud.get_children():
		if child is Control and child.is_visible_in_tree() and child.mouse_filter!=Control.MOUSE_FILTER_IGNORE and child.get_global_rect().has_point(point):return true
	return false

func frame_surface(id:String,padding:int=10)->StyleBoxTexture:
	var surface=StyleBoxTexture.new();surface.texture=app.map.texture_for(id)
	for side_index in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		surface.set_texture_margin(side_index,28 if id in ["ui_ornate_menu_frame","ui_province_frame"] else 12)
		surface.set_content_margin(side_index,padding)
	return surface
func button_surface(index:int)->StyleBoxTexture:
	var source=AtlasTexture.new();source.atlas=app.map.texture_for("ui_medieval_buttons");source.region=Rect2(0,index*64,192,64)
	var surface=StyleBoxTexture.new();surface.texture=source
	for side_index in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:surface.set_texture_margin(side_index,12)
	surface.set_content_margin(SIDE_LEFT,13);surface.set_content_margin(SIDE_RIGHT,13);surface.set_content_margin(SIDE_TOP,7);surface.set_content_margin(SIDE_BOTTOM,7)
	return surface
