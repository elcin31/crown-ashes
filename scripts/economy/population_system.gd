class_name PopulationSystem
extends RefCounted
static func monthly(s):
	for p in s.data.provinces:
		var r=s.data.realms[int(p.owner)];var hungry=float(r.resources.food)<=0
		var growth=0.002+float(p.development)*0.000025-float(p.unrest)*0.000035
		if hungry:growth-=0.024;p.unrest+=5
		if int(p.occupation)>=0:growth-=0.009;p.unrest+=2
		if int(p.epidemic)>0:growth-=0.018;p.epidemic=maxi(0,int(p.epidemic)-30)
		p.population=maxi(500,int(float(p.population)*(1.0+growth)))
		p.unrest=clampf(p.unrest+[-2.0,0.0,3.2][int(r.tax)]-(float(r.stability)-50)*0.035-float(p.buildings.get("temple",0))*0.9,0,100)
		if not hungry and int(p.occupation)<0:p.development=minf(100,p.development+0.10+float(p.buildings.get("market",0))*0.08)
		p.garrison=mini(55+int(p.fort)*45,int(p.garrison)+5) if int(p.occupation)<0 else p.garrison
