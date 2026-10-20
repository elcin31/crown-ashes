class_name ProvinceSystem
extends RefCounted
static func neighbors(s,realm:int)->Array:
	var found=[]
	for p in s.provinces_of(realm):
		for n in p.neighbors:
			var other=int(s.data.provinces[int(n)].owner)
			if other!=realm and not other in found:found.append(other)
	return found
static func path(s,realm:int,start:int,target:int)->Array:
	if start==target:return []
	var queue=[start];var prev={start:-1}
	while not queue.is_empty():
		var current=int(queue.pop_front())
		for nn in s.data.provinces[current].neighbors:
			var n=int(nn)
			if prev.has(n):continue
			var owner=int(s.data.provinces[n].owner)
			if not can_enter(s,realm,owner):continue
			prev[n]=current
			if n==target:
				var route=[target];var node=target
				while int(prev[node])!=start:
					node=int(prev[node]);route.push_front(node)
				return route
			queue.append(n)
	return []
static func can_enter(s,realm:int,owner:int)->bool:
	if realm==owner or s.sovereign(realm)==s.sovereign(owner):return true
	if s.at_war(realm,owner):return true
	var rel=s.relation(realm,owner)
	return rel.alliance or owner in rel.access
static func distance(s,a:int,b:int)->float:
	var p=s.data.provinces[a].center;var q=s.data.provinces[b].center
	return Vector2(p[0],p[1]).distance_to(Vector2(q[0],q[1]))
