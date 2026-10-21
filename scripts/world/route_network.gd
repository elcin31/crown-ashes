class_name RouteNetwork
extends RefCounted
static var nav:Dictionary={}
var grid=AStarGrid2D.new()
var routes={}
var road_paths={}
var graph={}
var occupied=[]
func _init():
	if nav.is_empty():nav=GameState.read_json("res://data/navigation.json")
	grid.region=Rect2i(0,0,int(nav.width),int(nav.height));grid.cell_size=Vector2.ONE*8;grid.offset=Vector2(4,4)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	for y in range(int(nav.height)):
		for x in range(int(nav.width)):
			if nav.mask[y][x]=="0":grid.set_point_solid(Vector2i(x,y))
	for edge in nav.roads:
		for id in [int(edge.a),int(edge.b)]:
			if not graph.has(id):graph[id]=[]
			graph[id].append(edge)
		for point in edge.points:
			var cell=cell_at(Vector2(point[0],point[1]))
			if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):grid.set_point_weight_scale(cell,.55)
func cell_at(p:Vector2)->Vector2i:return Vector2i(floori(p.x/8),floori(p.y/8))
func safe_cell(p:Vector2)->Vector2i:
	var start=cell_at(p)
	for radius in range(14):
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				if radius>0 and abs(x)!=radius and abs(y)!=radius:continue
				var c=start+Vector2i(x,y)
				if grid.is_in_boundsv(c) and not grid.is_point_solid(c):return c
	return Vector2i(-1,-1)
func local_path(a:Vector2,b:Vector2)->Array:
	var from=safe_cell(a);var to=safe_cell(b)
	if from.x<0 or to.x<0:return []
	var key="%s:%s"%[from,to]
	if routes.has(key):return routes[key]
	var path=[]
	for p in grid.get_point_path(from,to):path.append([p.x,p.y])
	routes[key]=path
	return path
func block_buildings(s):
	for c in occupied:
		if nav.mask[c.y][c.x]=="1":grid.set_point_solid(c,false)
	occupied.clear();routes.clear();road_paths.clear()
	for p in s.data.provinces:
		for slot in nav.slots[int(p.id)]:
			var base=cell_at(Vector2(slot[0],slot[1]))
			for y in range(-1,1):
				for x in range(-2,2):
					var c=base+Vector2i(x,y)
					if grid.is_in_boundsv(c) and not grid.is_point_solid(c):grid.set_point_solid(c);occupied.append(c)
func passage(s,realm:int,owner:int,kind:String)->bool:
	if owner==realm:return true
	if s.at_war(realm,owner):return false
	if s.data.realms[owner].get("is_rebel",false):return false
	if kind=="merchant" and float(s.data.realms[owner].stability)<25:return false
	return true
func journey(s,realm:int,start:int,target:int,kind:String)->Array:
	if start==target:return []
	var queue=[start];var prev={str(start):-1}
	while not queue.is_empty():
		var current=int(queue.pop_front())
		if current==target:break
		for edge in graph.get(current,[]):
			var n=int(edge.b) if int(edge.a)==current else int(edge.a)
			if prev.has(str(n)) or not passage(s,realm,int(s.data.provinces[n].owner),kind):continue
			if kind=="merchant" and (float(s.data.provinces[n].unrest)>65 or int(s.data.provinces[n].occupation)>=0):continue
			prev[str(n)]=current;queue.append(n)
	if not prev.has(str(target)):return []
	var ids=[target];var at=target
	while int(prev[str(at)])>=0:at=int(prev[str(at)]);ids.push_front(at)
	var result=[]
	for i in range(ids.size()-1):
		var a=int(ids[i]);var b=int(ids[i+1]);var key="%d:%d"%[a,b]
		if not road_paths.has(key):
			var edge={}
			for e in graph[a]:
				if int(e.a)==b or int(e.b)==b:edge=e;break
			var points=edge.points.duplicate(true)
			if int(edge.a)!=a:points.reverse()
			var path=[]
			for j in range(points.size()-1):
				var part=local_path(Vector2(points[j][0],points[j][1]),Vector2(points[j+1][0],points[j+1][1]))
				if part.is_empty():path=[];break
				if not path.is_empty():part=part.slice(1)
				path.append_array(part)
			road_paths[key]=path
		if road_paths[key].is_empty():return []
		result.append_array(road_paths[key])
	return result
static func point(pair)->Vector2:return Vector2(pair[0],pair[1])
