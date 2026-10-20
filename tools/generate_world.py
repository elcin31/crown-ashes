#!/usr/bin/env python3
"""Build the reproducible continent of Eldrath, exact clipped Voronoi topology."""
from pathlib import Path
from PIL import Image,ImageDraw
import random,math,json
ROOT=Path(__file__).resolve().parents[1];r=random.Random(1183)
W,H=3072,1792
coast=[(100,520),(220,180),(750,70),(1870,60),(2630,150),(2910,480),(2960,1200),(2700,1560),(1880,1710),(700,1680),(190,1430),(80,990)]
sites=[]
for row in range(6):
 for col in range(10):sites.append((280+col*273+r.randrange(-65,66),240+row*256+r.randrange(-55,56)))
def clip(poly,a,b,c):
 out=[]
 for j,p in enumerate(poly):
  q=poly[(j+1)%len(poly)];vp=a*p[0]+b*p[1]-c;vq=a*q[0]+b*q[1]-c
  if vp<=.00001:out.append(p)
  if (vp<0)!=(vq<0):
   t=vp/(vp-vq);out.append((p[0]+t*(q[0]-p[0]),p[1]+t*(q[1]-p[1])))
 return out
polys=[]
for i,(x,y) in enumerate(sites):
 poly=coast[:]
 for j,(xx,yy) in enumerate(sites):
  if i!=j:poly=clip(poly,2*(xx-x),2*(yy-y),xx*xx+yy*yy-x*x-y*y)
 polys.append(poly)
adj=[[] for _ in sites];edges=[]
for i,p in enumerate(polys):
 for j in range(i):
  common=[v for v in p if any(math.dist(v,w)<.02 for w in polys[j])]
  if len(common)>=2:
   adj[i].append(j);adj[j].append(i);edges.append({'a':j,'b':i,'points':[[round(x,3),round(y,3)] for x,y in common[:2]],'river_crossing':False})
blocks=[[10,1,9,3],[2,0,5,11],[4,8,6,7]]
names=['Нортхоллоу','Рэйвенвотч','Гленфорд','Белый перевал','Фростгейт','Эйзенхольм','Каменистый кряж','Чёрная вершина','Грейпорт','Солёный мыс','Винтерфелл','Элденвуд','Вейрхейм','Тернфорд','Окридж','Данхольм','Скайрич','Обсидиан','Серый берег','Мыс маяков','Торнвуд','Глубокая чаща','Тихий бор','Хаймир','Люменхольм','Стоунвейл','Данкрест','Восточный брод','Мэрроу','Старый порт','Воронья роща','Харроу','Меребрук','Розовый холм','Аурель','Ривергард','Пепельный мост','Редстоун','Рыбачий берег','Южный маяк','Туманный дол','Вересковый край','Велден','Зелёная долина','Пшеничный дол','Эшфорд','Эшленд','Янтарный путь','Санмарч','Солнечный форт','Седое болото','Чёрная топь','Лесной приют','Южный Велден','Изумруд','Пепельный край','Старая кузня','Златополье','Солнечная гавань','Последний берег']
countries=['Аурелия','Вейрмарк','Терновый предел','Серый берег','Харроуфен','Данкрест','Пепельные земли','Санмарч','Велден','Блэкридж','Фростхольм','Побережье Мэрроу']
english=['Aurelian Kingdom','Veyrmark','Thornsreach','Greyshore','Harrowfen','Duncrest','Ashlands','Sunmarch','Velden','Blackridge','Frostholm','Marrow Coast']
herald=['aurelian','veyrmark','thornsreach','greyshore','harrowfen','duncrest','ashlands','sunmarch','velden','blackridge','frostholm','marrow_coast']
colors=['427298','943f46','426955','75849a','766843','9a784c','734e59','b2974d','57866b','434351','72949e','4d7b80']
provs=[]
for i,poly in enumerate(polys):
 row,col=divmod(i,10);block=0 if col<3 else 1 if col<5 else 2 if col<8 else 3;owner=blocks[row//2][block]
 terrain='mountains' if (row==0 and col>=3) or (col in [6,7] and row<3) else 'forest' if col<3 or (row>=4 and col<6) else 'marsh' if row==5 and col<2 else 'hills' if col in [5,8] else 'plains'
 if i==23:terrain='plains'
 provs.append({'id':i,'name':names[i],'country':owner,'owner':12 if i==23 else owner,'center':list(sites[i]),'polygon':[[round(x,3),round(y,3)] for x,y in poly],'neighbors':sorted(adj[i]),'terrain':terrain,'coastal':any(any(math.dist(v,w)<.1 for w in coast) for v in poly) or col in [0,9] or row in [0,5],'population':r.randrange(3800,9200),'development':r.randrange(24,49),'unrest':r.randrange(4,15),'fort':1,'garrison':60,'buildings':{'farm':1,'fort':1},'construction':{},'occupation':-1,'siege':{},'holder':-1,'epidemic':0})
realmdata=[]
for i,n in enumerate(countries):
 owned=[p['id'] for p in provs if p['country']==i and p['owner']==i];cap=owned[len(owned)//2]
 realmdata.append({'id':i,'name':n,'english_name':english[i],'heraldry':herald[i],'color':colors[i],'capital':cap,'personality':['defensive','expansionist','diplomat','economic','opportunist'][i%5],'dynasty':['Валенн','Вейр','Терн','Грейв','Харроу','Данвик','Эшборн','Солари','Вельд','Блэквуд','Фрост','Мэрроу'][i],'stability':46 if i==0 else 64,'legitimacy':73,'title':2,'suzerain':-1})
realmdata.append({'id':12,'name':'Хаймир','english_name':'Highmere','heraldry':'aurelian','color':'628ca3','capital':23,'personality':'diplomat','dynasty':'Эшвик','stability':70,'legitimacy':68,'title':0,'suzerain':0})
world={'seed':1183,'width':W,'height':H,'coast':coast,'provinces':provs,'realms':realmdata,'edges':edges,'start_province':23}
(ROOT/'data/world.json').write_text(json.dumps(world,ensure_ascii=False,separators=(',',':')))
# Bake only static geography. Settlements, banners, armies and overlays remain interactive.
w,h=W//2,H//2;im=Image.new('RGBA',(w,h),'#173e55');d=ImageDraw.Draw(im)
for _ in range(7500):
 x,y=r.randrange(w),r.randrange(h);d.line((x,y,x+r.randrange(2,8),y),fill=r.choice(['#1b465e','#1e4a60','#214c61']))
c=[(x/2,y/2) for x,y in coast];d.polygon(c,fill='#70804b');d.line(c+[c[0]],fill='#3c8190',width=15);d.line(c+[c[0]],fill='#79a39b',width=6);d.line(c+[c[0]],fill='#b5b18a',width=2)
for p in provs:
 mask=Image.new('L',(w,h));md=ImageDraw.Draw(mask);md.polygon([(x/2,y/2) for x,y in p['polygon']],fill=255)
 tile=Image.open(ROOT/'assets/terrain'/({'mountains':'rocky_hills','forest':'forest_floor','marsh':'marsh','hills':'grassy_hills','plains':'grass_plain'}[p['terrain']]+'.png')).convert('RGBA')
 layer=Image.new('RGBA',(w,h));ld=ImageDraw.Draw(layer)
 xs=[x/2 for x,y in p['polygon']];ys=[y/2 for x,y in p['polygon']]
 for y in range(int(min(ys))//64*64,int(max(ys))+64,64):
  for x in range(int(min(xs))//64*64,int(max(xs))+64,64):layer.paste(tile,(x,y))
 im.paste(layer,(0,0),mask)
d=ImageDraw.Draw(im)
for e in edges:
 a=sites[e['a']];b=sites[e['b']];pts=[(a[0]/2,a[1]/2),((a[0]+b[0])/4+6,(a[1]+b[1])/4-5),(b[0]/2,b[1]/2)]
 d.line(pts,fill='#5a6346',width=5);d.line(pts,fill='#a19164',width=2)
rivers=[[(1040,120),(1080,300),(1030,480),(1130,650),(1080,850),(1190,1060),(1160,1240),(1310,1440),(1240,1680)],[(2280,130),(2170,330),(2290,530),(2170,720),(2300,930),(2220,1140),(2380,1360),(2320,1600)]]
for line in rivers:
 pts=[(x/2,y/2) for x,y in line];d.line(pts,fill='#b7ae79',width=10);d.line(pts,fill='#285f76',width=7);d.line(pts,fill='#64a2a5',width=2)
# Crossings use actual edge/river segment intersection.
def cross(a,b,c,d):
 def orient(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
 return orient(a,b,c)*orient(a,b,d)<0 and orient(c,d,a)*orient(c,d,b)<0
for e in edges:
 a,b=sites[e['a']],sites[e['b']]
 for river in rivers:
  for c1,c2 in zip(river,river[1:]):
   if cross(a,b,c1,c2):
    e['river_crossing']=True
    # Exact line intersection for placing bridge on both features.
    ax,ay=a;bx,by=b;cx,cy=c1;dx,dy=c2;den=(ax-bx)*(cy-dy)-(ay-by)*(cx-dx)
    px=((ax*by-ay*bx)*(cx-dx)-(ax-bx)*(cx*dy-cy*dx))/den;py=((ax*by-ay*bx)*(cy-dy)-(ay-by)*(cx*dy-cy*dx))/den
    art=Image.open(ROOT/'assets/decorations/stone_bridge.png').resize((32,40),Image.Resampling.NEAREST);im.alpha_composite(art,(int(px/2)-16,int(py/2)-24))
for p in provs:
 cx,cy=[v/2 for v in p['center']];bounds=[(x/2,y/2) for x,y in p['polygon']];mask=Image.new('L',(w,h));ImageDraw.Draw(mask).polygon(bounds,fill=255)
 for _ in range(48 if p['terrain']=='forest' else 16):
  x=int(cx+r.randrange(-96,97));y=int(cy+r.randrange(-89,90))
  if not(0<=x<w and 0<=y<h) or not mask.getpixel((x,y)) or math.hypot(x-cx,y-cy)<34:continue
  name=r.choice(['oak','pine']) if p['terrain']=='forest' else r.choice(['large_rock','small_boulder']) if p['terrain']=='mountains' else r.choice(['oak','bush','small_boulder'])
  if p['terrain']=='mountains' and _%3==0:
   a=Image.open(ROOT/'assets/terrain/snow_mountains.png');im.alpha_composite(a,(x-32,y-40))
  else:
   art=Image.open(ROOT/'assets/decorations'/(name+'.png')).resize((32,40),Image.Resampling.NEAREST);im.alpha_composite(art,(x-16,y-30))
 if p['terrain']=='plains':
  a=Image.open(ROOT/'assets/terrain/farmland.png').resize((40,40),Image.Resampling.NEAREST);im.alpha_composite(a,(int(cx)-52,int(cy)+14))
 for dx,dy,n in [(-33,5,'house'),(28,15,'peasant_hut'),(-23,32,'farm')]:
  art=Image.open(ROOT/'assets/buildings'/(n+'.png')).resize((32,32),Image.Resampling.NEAREST);im.alpha_composite(art,(int(cx)+dx-16,int(cy)+dy-25))
world['rivers']=rivers;(ROOT/'data/world.json').write_text(json.dumps(world,ensure_ascii=False,separators=(',',':')))
im=im.resize((W,H),Image.Resampling.NEAREST).convert('RGB');im.save(ROOT/'data/terrain_cache.png',optimize=True)
print('Baked 60 non-overlapping provinces, 12 sovereign realms + Highmere fief,',len(edges),'real shared borders.')
# Keep the established topology generator; the current art bake replaces only its picture.
if (ROOT/'tools/art_sources/architecture.png').exists():
 import subprocess,sys
 subprocess.run([sys.executable,str(ROOT/'tools/bake_world.py')],check=True)
