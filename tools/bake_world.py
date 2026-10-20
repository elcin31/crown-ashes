#!/usr/bin/env python3
"""Repaint static geography only. Reads the existing 60-province topology unchanged."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
import json,random,math
from atlas_extract import slice_objects
ROOT=Path(__file__).resolve().parents[1];world=json.loads((ROOT/'data/world.json').read_text());r=random.Random(20201183)
W,H=world['width']//2,world['height']//2
im=Image.new('RGBA',(W,H),'#102d43');d=ImageDraw.Draw(im)
# Long ocean swells instead of scattered single-pixel noise.
for y in range(2,H,9):
 for x in range(-20,W,43):
  xx=x+int(7*math.sin(y*.08));d.line([(xx,y),(xx+11,y-1),(xx+24,y)],fill='#173f56',width=1)
  if (x//43+y//9)%7==0:d.line([(xx+2,y-2),(xx+9,y-2)],fill='#265c70')
coast=[(x/2,y/2) for x,y in world['coast']];land=Image.new('L',(W,H));ImageDraw.Draw(land).polygon(coast,fill=255)
# Palette-quantized low-frequency value field controls material patches, not display blur.
ramp=['#4c5d3f','#536341','#5b6945','#637047','#6b754c','#747b50','#7b8153','#858958']
coarse=Image.new('L',(34,22));coarse.putdata([r.randrange(52,195) for _ in range(34*22)]);field=coarse.resize((W,H),Image.Resampling.BILINEAR)
lookup=[]
for value in range(256):
 color=ramp[min(7,value//32)];lookup.extend([int(color[k:k+2],16) for k in [1,3,5]])
# L.point cannot map to RGB with 3-entry LUT, use palette conversion for bounded work.
palette=Image.new('P',(1,1));palette.putpalette(lookup);landscape=field.convert('P');landscape.putpalette(lookup);landscape=landscape.convert('RGBA');im.paste(landscape,(0,0),land)
# Blend biome transition masks well inside the same native pixel grid.
for terrain,color in [('forest','#304b3c'),('mountains','#667773'),('hills','#74815b'),('marsh','#496459')]:
 mask=Image.new('L',(W,H));md=ImageDraw.Draw(mask)
 for p in world['provinces']:
  if p['terrain']==terrain:md.polygon([(x/2,y/2) for x,y in p['polygon']],fill=100 if terrain=='hills' else 155)
 mask=mask.filter(ImageFilter.GaussianBlur(21));mask=Image.composite(mask,Image.new('L',(W,H)),land);im.paste(Image.new('RGBA',(W,H),color),(0,0),mask)
d=ImageDraw.Draw(im)
# Small tuft groups follow terrain patches. Never cover the reserve around town centres.
centres=[(p['center'][0]/2,p['center'][1]/2) for p in world['provinces']]
def reserved(x,y,radius=42):return any(abs(x-cx)<radius and abs(y-cy)<radius*.7 for cx,cy in centres)
for _ in range(7500):
 x,y=r.randrange(W),r.randrange(H)
 if land.getpixel((x,y))<128 or reserved(x,y,33):continue
 if _%7==0:d.line([(x-2,y+1),(x,y-2),(x,y),(x+3,y-1)],fill='#8e905d')
 else:d.line([(x,y),(x+4,y-1)],fill='#6b754c')
# Coastline ledges and surf retain the exact existing land polygon.
for width,color in [(13,'#173f56'),(9,'#265c70'),(5,'#619da1'),(2,'#c9c2a2')]:d.line(coast+[coast[0]],fill=color,width=width,joint='curve')
# Smooth roads: sparse minimum spanning network with selected capital connections.
edges=world['edges'];parents=list(range(60))
def root(x):
 while parents[x]!=x:parents[x]=parents[parents[x]];x=parents[x]
 return x
selected=[]
for e in sorted(edges,key=lambda e:math.dist(centres[e['a']],centres[e['b']])):
 a,b=int(e['a']),int(e['b']);ra,rb=root(a),root(b)
 if ra!=rb:parents[ra]=rb;selected.append(e)
for e in edges:
 if int(e['a']) in [int(k['capital']) for k in world['realms']] and e not in selected and r.random()<.5:selected.append(e)
def bezier(a,b,offset=0):
 ax,ay=a;bx,by=b;mx=(ax+bx)/2-(by-ay)*offset;my=(ay+by)/2+(bx-ax)*offset
 return [((1-t)**2*ax+2*(1-t)*t*mx+t*t*bx,(1-t)**2*ay+2*(1-t)*t*my+t*t*by) for t in [i/18 for i in range(19)]]
roads=[]
for e in selected:
 a,b=centres[int(e['a'])],centres[int(e['b'])];pts=bezier(a,b,r.uniform(-.18,.18));roads.append(pts)
 d.line(pts,fill='#493f30',width=5,joint='curve');d.line(pts,fill='#997f56',width=3,joint='curve');d.line([(x,y-1) for x,y in pts],fill='#b49b6b',width=1,joint='curve')
# Catmull-Rom watercourses follow the saved rivers; only the drawing is refined.
def smooth(points):
 p=[points[0]]+points+[points[-1]];out=[]
 for j in range(1,len(p)-2):
  a,b,c,e=p[j-1:j+3]
  for step in range(14):
   t=step/14;t2=t*t;t3=t2*t
   out.append(tuple(.5*((2*b[k])+(-a[k]+c[k])*t+(2*a[k]-5*b[k]+4*c[k]-e[k])*t2+(-a[k]+3*b[k]-3*c[k]+e[k])*t3) for k in [0,1]))
 out.append(points[-1]);return out
rivers=[]
for idx,river in enumerate(world['rivers']):
 pts=smooth([(x/2,y/2) for x,y in river]);rivers.append(pts)
 for width,color in [(16,'#516773'),(12,'#a3a06d'),(10,'#265c70'),(6,'#327081')]:d.line(pts,fill=color,width=width,joint='curve')
 d.line([(x-2,y) for x,y in pts],fill='#619da1',width=1)
 for j in range(2,len(pts)-3,6):
  x,y=pts[j];d.line([(x-2,y),(x+2,y+1),(x+4,y)],fill='#85b5af')
# Curved fields / orchards belong to settlement economies, not province borders.
asset_cache={}
def a(name):
 if name not in asset_cache:
  found=next(ROOT/x['path'] for x in json.loads((ROOT/'assets_manifest.json').read_text())['resources'] if x['id']==name);asset_cache[name]=Image.open(found).convert('RGBA')
 return asset_cache[name]
# Two landform brushes are derived from the retained decoration atlas; only
# their baked result ships to Android, avoiding another large live texture.
landforms=slice_objects(ROOT/'tools/art_sources/decorations.png',6,6)[34:36]
common_palette=Image.new('P',(1,1));values=[int(c.lstrip('#')[i:i+2],16) for c in json.loads((ROOT/'data/art_palette.json').read_text()) for i in [0,2,4]];common_palette.putpalette(values+[0]*(768-len(values)))
for key,source in zip(['_ridge','_cliff'],landforms):
 alpha=source.getchannel('A');paint=source.convert('RGB').quantize(palette=common_palette,dither=Image.Dither.NONE).convert('RGBA');paint.putalpha(alpha);asset_cache[key]=paint
placements=[]
def place(name,x,y,w=30,layer=1):
 source=a(name);h=round(source.height*w/source.width);placements.append((y,name,round(x-w/2),round(y-h),w,h,layer))
for p in world['provinces']:
 pid=int(p['id']);cx,cy=centres[pid];biome=p['terrain']
 if biome=='plains':
  for dx,dy,name in [(-49,31,'wheat_field_detail'),(40,43,'vegetable_garden'),(-52,-20,'vineyard' if pid>=30 else 'wheat_field')]:place(name,cx+dx,cy+dy,46)
  if pid%3==0:place('apple_orchard',cx+59,cy-23,45)
  if pid%4==0:place('hay_wagon',cx-42,cy+47,22)
  if pid%5==0:place('wildflower_patch',cx+61,cy+18,25)
 # Each biome's brush patches are clipped by their local material footprint, no square tiles.
 brush={'forest':['dense_oak_forest','ancient_pine_forest','autumn_woodland','forest_clearing'],'mountains':['rocky_cliffs','snowy_mountain_ridge','alpine_pass'],'hills':['wild_grassland','rocky_cliffs'],'plains':['flowering_meadow','wild_grassland'],'marsh':['marshland_vegetation']}[biome]
 for k,name in enumerate(brush):
  tile=a(name).resize((44,44),Image.Resampling.NEAREST);mask=Image.new('L',(44,44));md=ImageDraw.Draw(mask);md.polygon([(2,14),(11,3),(30,0),(43,17),(36,36),(18,43),(1,31)],fill=120)
  x=int(cx+(-82 if k%2 else 65));y=int(cy+(-65 if k<2 else 40));local=land.crop((x,y,x+44,y+44));mask=Image.composite(mask,Image.new('L',(44,44)),local);im.paste(tile,(x,y),mask)
 if biome=='forest':
  # Dense overlapping thickets with clearings, not an evenly random carpet.
  for j in range(4):
   gx=cx+r.choice([-1,1])*r.randrange(46,83);gy=cy+r.randrange(-64,65)
   for k in range(19):
    x=gx+r.gauss(0,18);y=gy+r.gauss(0,14)
    if not(0<x<W and 0<y<H) or not land.getpixel((int(x),int(y))) or reserved(x,y,43):continue
    name='ancient_oak' if k%11==0 else 'pine' if (pid+j)%3==0 else 'oak'
    place(name,x,y,23 if name!='ancient_oak' else 31)
  place('fallen_tree',cx-68,cy+48,27)
  if pid%3==0:place('dead_forest_tree',cx+75,cy+48,24)
 elif biome in ['hills','mountains']:
  for k in range(7):
   x=cx+r.randrange(-84,85);y=cy+r.randrange(-70,71)
   if reserved(x,y,38):continue
   place('large_boulder_cluster' if k%2 else 'large_rock',x,y,r.randrange(24,42))
 elif biome=='marsh':
  for k in range(14):
   x=cx+r.randrange(-84,85);y=cy+r.randrange(-70,71)
   if not reserved(x,y,38):place('dead_tree' if k%3==0 else 'bush',x,y,24)
 else:
  for k in range(8):
   x=cx+r.randrange(-90,90);y=cy+r.randrange(-65,65)
   if not reserved(x,y,42):place('oak' if k%3==0 else 'bush',x,y,20)
 # The large landmark remains dynamic; bake only streets, yards and satellite buildings.
 tier=3 if pid in [int(k['capital']) for k in world['realms']] else 2 if p['population']>7300 else 1 if p['development']>34 else 0
 offsets=[(-24,14,'house'),(25,19,'peasant_hut'),(-10,35,'granary')]
 if tier>=1:offsets.extend([(-33,-8,'townhouse'),(33,-5,'market'),(39,35,'well')])
 if tier>=2:offsets.extend([(-38,28,'merchant_guildhall'),(4,43,'medieval_town_hall')])
 if tier>=3:offsets.extend([(-41,-27,'temple'),(45,-20,'noble_estate')])
 for dx,dy,name in offsets:place(name,cx+dx,cy+dy,29 if name not in ['temple','merchant_guildhall'] else 35)
 if p['coastal']:place('fortified_harbor' if tier>=2 else 'port',cx+74,cy+36,44)
 if pid%5==0:place('roadside_shrine',cx+55,cy+30,21)
 if pid%7==0:place('abandoned_cottage',cx-78,cy+35,27)
 if pid%4==0:place('merchant_cart',cx-39,cy+19,21)
 if pid%6==0:place('wooden_fence_corner',cx-40,cy+27,24)
 if pid%8==0:place('stone_fence',cx+33,cy+30,27)
 if pid%3==0:place('village_well',cx+10,cy+36,23)
# Draw painterly pixel ridges and cliff strata as part of the same static layer.
for p in world['provinces']:
 if p['terrain']!='mountains':continue
 cx,cy=centres[int(p['id'])]
 for j in range(4):
  x=cx-83+j*54;y=cy-37+(j%2)*19
  if reserved(x,y,48):continue
  place('_ridge' if j%3 else '_cliff',x,y,77 if j%3 else 43)
# Globally sort pre-baked transparent scenery by its ground contact.
for y,name,x,top,w,h,layer in sorted(placements):
 sprite=a(name).resize((w,h),Image.Resampling.NEAREST);im.alpha_composite(sprite,(x,top))
# Exact intersection of visible roads/rivers determines crossing art.
def intersect(a,b,c,e):
 ax,ay=a;bx,by=b;cx,cy=c;dx,dy=e;den=(ax-bx)*(cy-dy)-(ay-by)*(cx-dx)
 if abs(den)<.001:return None
 t=((ax-cx)*(cy-dy)-(ay-cy)*(cx-dx))/den;u=-((ax-bx)*(ay-cy)-(ay-by)*(ax-cx))/den
 if 0<=t<=1 and 0<=u<=1:return (ax+t*(bx-ax),ay+t*(by-ay))
 return None
crossings=[]
for road in roads:
 for river in rivers:
  for aa,bb in zip(road,road[1:]):
   for cc,ee in zip(river,river[1:]):
    point=intersect(aa,bb,cc,ee)
    if point and all(math.dist(point,q)>18 for q in crossings):crossings.append(point)
for x,y in crossings:
 sprite=a('stone_bridge').resize((34,41),Image.Resampling.NEAREST);im.alpha_composite(sprite,(int(x)-17,int(y)-30))
# All enhanced river/coast variants are visible in appropriate geographic contexts.
for name,pos in [('shallow_river_rapids',rivers[0][35]),('rocky_coastline',coast[2]),('sandy_coastline',coast[8])]:
 x,y=map(int,pos);tile=a(name).resize((28,28),Image.Resampling.NEAREST);mask=Image.new('L',(28,28));ImageDraw.Draw(mask).ellipse((2,3,25,24),fill=120);im.paste(tile,(x-14,y-14),mask)
im=im.resize((world['width'],world['height']),Image.Resampling.NEAREST).convert('RGB');im.save(ROOT/'data/terrain_cache.png',optimize=True)
(ROOT/'data/visual_world.json').write_text(json.dumps({'version':'0.2.0','roads':len(roads),'bridges':len(crossings),'scenery_count':len(placements),'cache_size':list(im.size),'topology_changed':False},indent=2))
print('Reforged geography:',len(placements),'prebaked scenery placements,',len(roads),'curving roads,',len(crossings),'bridges; topology unchanged.')
