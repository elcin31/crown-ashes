#!/usr/bin/env python3
"""Crown & Ashes original pixel workshop. Pillow only, deterministic, no external art."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import random, math, json
ROOT=Path(__file__).resolve().parents[1]
AS=ROOT/'assets'; rng=random.Random(1183); manifest=[]
INK='#141e22'; GOLD='#d9b968'; LIGHT='#ebd7a0'; STONE='#818b8d'; SHADOW='#36474b'; ROOF='#693e3c'
COLORS=['#427298','#943f46','#426955','#75849a','#766843','#9a784c','#734e59','#b2974d','#57866b','#434351','#72949e','#4d7b80']
def canvas(w,h): return Image.new('RGBA',(w,h),(0,0,0,0))
def save(im,cat,name,purpose,animation=None,scale=1):
 if scale>1: im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
 p=AS/cat/(name+'.png'); p.parent.mkdir(parents=True,exist_ok=True); im.save(p,optimize=True)
 item={'id':name,'path':str(p.relative_to(ROOT)),'purpose':purpose,'size':[im.width,im.height],'type':cat}
 if animation:item['animation']=animation
 manifest.append(item)
 return im
def rect(d,box,fill,outline=None):d.rectangle(tuple(map(int,box)),fill=fill,outline=outline)
def texture(im,base,colors,n=110):
 d=ImageDraw.Draw(im);d.rectangle((0,0,im.width,im.height),fill=base)
 for _ in range(n):
  x=rng.randrange(im.width); y=rng.randrange(im.height); c=rng.choice(colors)
  d.line((x,y,x+rng.randrange(1,4),y),fill=c)
def tree(d,x,y,kind=0,s=1):
 def P(points,c):d.polygon([(int(x+a*s),int(y+b*s)) for a,b in points],fill=c)
 P([(-1,0),(2,0),(2,-11),(-1,-12)],'#684d38')
 if kind==1:
  for j in range(3):
   yy=-22+j*6; P([(-9+j,yy+12),(0,yy),(9-j,yy+12)],['#1d3935','#294c3e','#365c45'][j])
  P([(-1,-20),(0,-22),(5,-12),(1,-13)],'#628059')
 elif kind==2:
  d.line((x,y,x,y-19*s),fill='#786e58',width=max(1,int(s*2)))
  for a,b,c,e in [(-1,-8,-7,-13),(0,-13,6,-18),(0,-18,-3,-22)]:d.line((x+a*s,y+b*s,x+c*s,y+e*s),fill='#786e58',width=max(1,int(s)))
 else:
  for xx,yy,r,c in [(-5,-13,8,'#263f32'),(5,-15,8,'#36573c'),(-2,-20,9,'#496b43'),(-6,-22,5,'#607b49'),(3,-24,4,'#788950')]:
   d.ellipse((int(x+(xx-r)*s),int(y+(yy-r)*s),int(x+(xx+r)*s),int(y+(yy+r)*s)),fill=c)
def mountain(d,x,y,s=1,snow=False):
 def P(p,c):d.polygon([(int(x+a*s),int(y+b*s)) for a,b in p],fill=c)
 P([(-24,0),(-8,-31),(0,-43),(8,-30),(25,0)],'#3f525c');P([(-24,0),(-8,-31),(0,-43),(-1,-9),(8,0)],'#8e9c9c');P([(-24,0),(-8,-31),(-13,-9),(-8,-12),(-13,0)],'#647878');P([(0,-43),(8,-30),(18,-8),(5,-17)],'#586d78')
 if snow:
  P([(-12,-25),(0,-43),(11,-25),(3,-29),(1,-22),(-3,-30),(-8,-26)],'#c7d3cb');P([(-10,-26),(0,-43),(-3,-31)],'#ecede0')
terrains=['grass_plain','grass_lush','dry_grass','soil','farmland','forest_floor','pine_forest_floor','deciduous_forest_floor','grassy_hills','rocky_hills','mountain_base','snow_mountains','river_straight','river_bend','river_junction','coastline_straight','coastline_corner','shallow_water','deep_water','marsh','dirt_road','stone_road']
for i,n in enumerate(terrains):
 im=canvas(64,64);d=ImageDraw.Draw(im)
 base=['#747b49','#607c45','#99945c','#72654b','#777444','#3c563b','#354d3e','#4d603b','#778052','#73785b','#687777','#77888d'][min(i,11)] if i<12 else '#747b49'
 texture(im,base,['#6a7345','#87905a','#54653d'] if i<10 else ['#61716d','#86928a'],140)
 if n=='farmland':
  for x in range(-48,70,8): d.line((x,0,x+60,64),fill='#ae9c56',width=3);d.line((x+2,0,x+62,64),fill='#4c5934',width=1)
 if n in ['grassy_hills','rocky_hills']:
  for x,y in [(19,30),(44,51)]:
   d.ellipse((x-18,y-14,x+18,y+5),fill='#859062' if i==8 else '#838c7a');d.arc((x-18,y-14,x+18,y+5),180,320,fill='#a0a078',width=2)
 if i in [10,11]:mountain(d,31,61,1.1,i==11)
 if n.startswith('river'):
  pts={'river_straight':[(32,0),(30,20),(34,43),(32,64)],'river_bend':[(32,0),(32,21),(40,32),(64,32)],'river_junction':[(32,0),(30,32),(32,64)]}[n]
  d.line(pts,fill='#b1ac78',width=18);d.line(pts,fill='#397e91',width=13);d.line(pts,fill='#6ea7aa',width=2)
  if n=='river_junction':d.line([(30,32),(48,32),(64,32)],fill='#397e91',width=13)
 if n.startswith('coast'):
  if i==15:d.polygon([(0,0),(28,0),(31,18),(27,42),(32,64),(0,64)],fill='#1c4f69');d.line([(29,0),(32,18),(28,42),(33,64)],fill='#d3bc7b',width=3)
  else:d.polygon([(0,0),(64,0),(64,24),(45,28),(30,39),(24,64),(0,64)],fill='#235a70');d.arc((-32,-32,80,80),0,90,fill='#bfbb8b',width=3)
 if n in ['shallow_water','deep_water']:
  texture(im,'#2a6a80' if i==17 else '#163c56',['#32798c','#24576f'] if i==17 else ['#1c4862','#204e66'],55)
 if n=='marsh':
  for _ in range(12):
   x,y=rng.randrange(54),rng.randrange(54);d.ellipse((x,y,x+12,y+5),fill='#426b66');d.line((x+4,y,x+4,y-5),fill='#98a070')
 if n.endswith('road'):
  d.rectangle((23,0,40,64),fill='#8c805c' if i==20 else '#899181');d.line((23,0,23,64),fill='#b0a177');d.line((40,0,40,64),fill='#4f593e')
  if i==21:
   for y in range(0,64,8):
    d.line((24,y,39,y),fill='#525e59');d.line((31+(y//8%2)*4,y,31+(y//8%2)*4,y+8),fill='#525e59')
 save(im,'terrain',n,n.replace('_',' '))
# Buildings are drawn at native 48px with common north-west light, then doubled.
buildings=['wooden_fort','stone_keep','small_castle','grand_castle','citadel','watchtower','palisade','peasant_hut','house','townhouse','manor','royal_palace','farm','windmill','granary','sawmill','quarry','iron_mine','smithy','market','tavern','barracks','temple','port']
def building(n):
 im=canvas(48,48);d=ImageDraw.Draw(im);d.ellipse((4,38,45,46),fill='#24332b99')
 def wall(x,y,w,h,wood=False):
  c='#957552' if wood else '#83918b';rect(d,(x,y,x+w,y+h),c,INK);rect(d,(x+w-4,y+1,x+w-1,y+h-1),'#5c655f' if not wood else '#674d37')
  for yy in range(y+4,y+h,5):
   d.line((x+1,yy,x+w-5,yy),fill='#606f69' if not wood else '#6c533c')
   if not wood:
    for xx in range(x+3+(yy//5%2)*3,x+w-4,7):d.line((xx,yy-3,xx,yy),fill='#66766f')
 def roof(x,y,w):
  d.polygon([(x-2,y),(x+w//2,y-10),(x+w+2,y)],fill=INK);d.polygon([(x,y-1),(x+w//2,y-9),(x+w,y-1)],fill=ROOF);d.line((x,y-1,x+w//2,y-9),fill='#b77454')
  for j in range(3):d.line((x+3+j*3,y-2-j*2,x+w-3-j*3,y-2-j*2),fill='#8c5144')
 def window(x,y):rect(d,(x,y,x+3,y+4),INK);rect(d,(x+1,y+1,x+2,y+3),'#eac578')
 def tower(x,y,w=10,h=20):
  wall(x,y,w,h)
  for xx in range(x,x+w+1,4):rect(d,(xx,y-3,xx+2,y),STONE,INK)
  window(x+3,y+5)
 def hut(x,y,w=16,h=13):
  wall(x,y,w,h,True);roof(x,y,w);rect(d,(x+w//2-2,y+h-6,x+w//2+2,y+h),INK);window(x+3,y+3)
  d.line((x+1,y+1,x+w-5,y+h-1),fill='#c3a474');d.line((x+w-4,y+1,x+2,y+h-2),fill='#c3a474')
 if n in buildings[:6]:
  if n=='watchtower':tower(18,14,13,28);roof(18,14,13)
  elif n=='stone_keep':
   tower(13,12,23,31);rect(d,(21,33,28,44),INK);window(18,27);window(28,27);roof(13,12,23)
  elif n=='wooden_fort':
   wall(8,25,31,16,True);hut(15,20,17,19)
   for x in range(6,43,5):d.polygon([(x,44),(x,28),(x+2,24),(x+4,28),(x+4,44)],fill='#8b704d',outline=INK)
   rect(d,(21,34,28,44),INK)
  else:
   wall(8,27,32,16);tower(5,19,10,25);tower(34,19,10,25);tower(18,11,13,29);roof(18,11,13)
   rect(d,(21,33,28,44),INK);d.arc((21,29,28,37),180,360,fill=INK,width=2)
   if n in ['grand_castle','citadel']:tower(12,14,8,17);tower(30,12,8,19);roof(30,12,8)
  if n=='citadel':
   wall(2,34,44,11);rect(d,(20,37,29,45),INK)
   for xx in range(2,47,5):rect(d,(xx,31,xx+2,34),'#a1aaa0',INK)
  d.line((28,10,28,1),fill='#c9b879');d.polygon([(29,1),(37,2),(34,7),(29,6)],fill='#9f4849')
 elif n=='palisade':
  for x in range(5,44,4):d.polygon([(x,43),(x,21),(x+2,17),(x+3,21),(x+3,43)],fill='#947149',outline=INK)
  d.line((6,28,43,28),fill='#c49e69',width=2)
 elif n in ['peasant_hut','house','townhouse','manor','royal_palace','tavern','barracks']:
  if n=='peasant_hut':
   hut(14,29,19,13);d.polygon([(12,28),(23,19),(35,28)],fill='#b5a16b',outline=INK);d.line((15,27,23,21),fill='#d5c18b')
  else:hut(10,24,27,18)
  if n not in ['peasant_hut','house']:hut(15,12,18,14)
  if n=='townhouse':rect(d,(11,28,36,30),'#d8c18a');window(21,15)
  if n=='royal_palace':
   d.line((3,20,14,13,25,5,37,13,46,20),fill=GOLD,width=2);rect(d,(19,31,29,43),GOLD,INK);rect(d,(21,33,27,43),INK);d.line((16,25,35,25),fill=LIGHT,width=2)
  if n in ['manor','royal_palace']:tower(3,23,9,20);roof(3,23,9);tower(36,22,9,21);roof(36,22,9)
  if n=='tavern':rect(d,(36,26,45,33),'#d4b97a',INK);d.ellipse((38,27,42,31),outline='#67452d')
  if n=='barracks':d.line((8,9,8,35),fill=GOLD);d.polygon([(9,9),(17,10),(15,16),(9,15)],fill='#8e3f41')
 elif n in ['farm','granary','sawmill','smithy','market']:
  hut(13,22,23,20)
  if n=='farm':
   for x in range(3,43,5):d.line((x,38,x,45),fill='#d1b25f');d.line((x-2,40,x+2,42),fill='#d1b25f')
  if n=='sawmill':
   for y in [35,39,43]:d.line((2,y,20,y),fill='#ad8451',width=3);d.ellipse((2,y-1,5,y+1),fill='#dec58a')
  if n=='smithy':rect(d,(33,12,38,32),'#72746e',INK);rect(d,(15,34,24,42),'#e78c45');rect(d,(18,38,26,42),'#e3c079')
  if n=='market':
   for x in range(7,42,6):d.polygon([(x,27),(x+4,27),(x+7,35),(x,35)],fill='#b9824e' if x%2 else '#d0bb8a')
   d.line((8,35,8,44),fill='#c09b68');d.line((41,35,41,44),fill='#c09b68')
 elif n=='windmill':
  wall(18,15,14,28);roof(18,15,14)
  d.line((8,6,41,34),fill='#baa97e',width=4);d.line((8,34,41,6),fill='#baa97e',width=4)
  for x,y in [(10,7),(30,24),(9,28),(30,8)]:rect(d,(x,y,x+7,y+5),'#e1d2a5',INK)
  d.ellipse((23,17,27,21),fill=INK)
 elif n in ['quarry','iron_mine']:
  for x,y in [(13,40),(24,31),(37,41)]:mountain(d,x,y,.43,False)
  if n=='iron_mine':rect(d,(18,29,31,44),'#3b3832');d.line((17,45,17,27,31,27,31,45),fill='#b18e59',width=3);d.line((20,44,13,48),fill=STONE,width=2)
 elif n=='temple':
  wall(9,27,31,17);roof(9,27,31);tower(20,12,10,28);roof(20,12,10);d.line((25,2,25,9),fill=GOLD,width=2);d.line((22,5,28,5),fill=GOLD,width=2);window(23,29)
 elif n=='port':
  for y in [35,40,45]:d.line((3,y,44,y),fill='#a28a60',width=3)
  hut(9,20,20,17);d.line((36,13,36,42),fill='#b8a071',width=2);d.line((34,14,44,25),fill='#d6c897');rect(d,(36,22,45,30),'#bcaa77',INK)
 return im
for n in buildings:save(building(n),'buildings',n,n.replace('_',' '),scale=2)
decors=['oak','pine','dead_tree','bush','small_boulder','large_rock','wheat_field','haystack','fence','stone_wall','wood_bridge','stone_bridge','well','cart','campfire','signpost','ruins','torch']
for n in decors:
 im=canvas(32,40);d=ImageDraw.Draw(im)
 if n in ['oak','pine','dead_tree']:tree(d,16,37,decors.index(n),.9)
 elif n=='bush':
  for x,y,c in [(9,31,'#2c4a38'),(20,30,'#466241'),(15,26,'#637d46')]:d.ellipse((x-7,y-5,x+7,y+5),fill=c)
 elif n in ['small_boulder','large_rock']:
  if n=='small_boulder':
   d.polygon([(7,37),(10,30),(18,27),(25,32),(23,38)],fill='#748077',outline=INK);d.polygon([(10,30),(18,28),(18,33),(8,37)],fill='#a1aa95')
  else:d.polygon([(3,36),(7,23),(18,17),(28,28),(26,37)],fill='#626f6c',outline=INK);
  if n=='large_rock':d.polygon([(7,24),(18,18),(17,29),(3,36)],fill='#a1aa95');d.line((18,19,22,29,18,36),fill='#4a5956')
 elif n=='wheat_field':
  for y in range(8,38,5):
   for x in range(4,30,5):d.line((x,y+4,x+1,y-1),fill='#d1b66a');d.line((x-1,y,x+3,y+2),fill='#e1cb82')
 elif n=='haystack':d.polygon([(4,36),(7,23),(15,15),(25,24),(29,36)],fill='#c4a454',outline='#705b32');d.arc((5,24,28,41),175,360,fill='#e1ca79',width=2)
 elif n in ['fence','stone_wall','wood_bridge','stone_bridge']:
  stone='stone' in n; col='#89938b' if stone else '#ae8b57'
  if 'bridge' in n:
   d.polygon([(0,26),(26,18),(31,25),(4,35)],fill=col,outline=INK)
   for x in range(2,30,4):d.line((x,27,x+4,31),fill='#5c665e' if stone else '#6b5138')
   d.line((1,22,27,15),fill=LIGHT,width=2);d.line((5,34,31,27),fill=col,width=3)
  else:
   for y in [23,29]:d.line((2,y,30,y-4),fill=col,width=3)
   for x in [4,14,26]:d.line((x,20,x,36),fill=col,width=3)
 elif n=='well':
  d.ellipse((6,26,26,37),fill='#85918a',outline=INK);d.ellipse((8,24,24,31),fill='#253c43');d.line((9,27,9,13,24,13,24,27),fill='#b49766',width=2);d.polygon([(4,14),(16,5),(29,14)],fill=ROOF)
 elif n=='cart':
  rect(d,(6,23,27,32),'#9c7749',INK);d.line((2,34,29,34),fill='#d0ab6d',width=2)
  for x in [10,25]:d.ellipse((x-3,31,x+3,37),fill=INK,outline='#ad9263')
  for x in [10,17,23]:d.ellipse((x-3,18,x+3,26),fill='#b7a26a')
 elif n in ['campfire','torch']:
  if n=='torch':rect(d,(14,21,17,38),'#9b774c',INK)
  else:d.line((5,37,26,29),fill='#94764b',width=3);d.line((6,29,26,37),fill='#94764b',width=3)
  d.polygon([(10,30),(9,21),(14,25),(16,12),(24,27),(22,33),(13,34)],fill='#d27142');d.polygon([(13,30),(16,22),(20,31)],fill='#f1cb73')
 elif n=='signpost':rect(d,(14,14,17,38),'#9a794e',INK);d.polygon([(4,14),(25,14),(30,18),(25,22),(4,22)],fill='#c3a471',outline=INK)
 elif n=='ruins':
  rect(d,(5,26,27,37),STONE,INK);rect(d,(5,17,11,37),STONE,INK);rect(d,(21,22,27,37),STONE,INK);rect(d,(13,30,18,37),'#32463d');d.line((7,18,8,33,22,35),fill='#647851',width=2)
 save(im,'decorations',n,n.replace('_',' '),scale=2)
portraits=['king_young','king_mature','king_old','queen_young','queen_mature','queen_old','noble_young','noble_mature','noble_old','noblewoman_young','noblewoman_mature','noblewoman_old','priest_male','priest_female','commander_young','commander_veteran','steward','spymaster']
for i,n in enumerate(portraits):
 im=canvas(48,48);d=ImageDraw.Draw(im)
 texture(im,'#26353c',['#293b42','#2f4146'],70);d.ellipse((4,1,44,50),fill='#3c4c4c');d.polygon([(2,48),(6,34),(17,28),(31,28),(42,35),(47,48)],fill=COLORS[i%12],outline=INK)
 d.polygon([(15,30),(23,37),(33,30),(30,44),(19,44)],fill='#bbb18b');rect(d,(21,26,28,34),'#b48360')
 female=i in [3,4,5,9,10,11,13];old=i in [2,5,8,11,15];hair='#c7c7b1' if old else ['#4c302c','#916a3f','#c1a36a','#2a282a'][i%4]
 if female:d.ellipse((12,7,36,38),fill=hair,outline=INK)
 d.ellipse((14,7,34,31),fill='#d3a57b',outline=INK);d.polygon([(29,10),(33,13),(33,24),(29,30),(25,30),(28,23)],fill='#ac7357')
 d.polygon([(13,18),(13,10),(18,5),(29,6),(35,12),(34,18),(29,10),(20,10),(17,17)],fill=hair)
 d.line((17,18,21,18),fill='#5b463b');d.line((27,18,31,18),fill='#5b463b');rect(d,(18,19,20,20),'#253037');rect(d,(28,19,30,20),'#253037');d.point((18,19),fill='#ddd7ba');d.line((24,19,23,24,26,24),fill='#a56c50');d.line((21,27,28,27),fill='#784c43')
 if old:
  d.line((15,21,18,23),fill='#a67a5e');d.line((29,23,32,21),fill='#a67a5e');d.line((19,14,29,14),fill='#b58565')
 if not female and i%3!=0:d.polygon([(15,23),(20,28),(28,28),(33,22),(31,30),(25,35),(18,31)],fill=hair);d.line((22,27,28,27),fill='#7b4f40')
 if i<6:
  d.polygon([(14,11),(13,3),(18,6),(23,1),(28,6),(34,3),(33,11)],fill=GOLD,outline='#59452d');rect(d,(15,9,32,11),'#f3d98c');rect(d,(23,7,25,9),'#98454b')
 elif i in [12,13]:d.polygon([(15,10),(17,2),(24,0),(31,3),(34,11)],fill='#cbbf8a',outline=INK);d.line((24,2,24,9),fill=GOLD)
 elif i in [14,15]:d.arc((11,4,36,29),180,350,fill='#a2aca9',width=4);rect(d,(12,13,16,22),'#77858a');d.line((7,37,16,34),fill='#a1a9a0',width=4)
 elif i==17:d.polygon([(9,25),(12,7),(23,1),(36,9),(38,28),(31,18),(31,10),(18,10),(17,23)],fill='#20272d');d.polygon([(7,48),(17,29),(23,38),(30,29),(43,48)],fill='#273038')
 else:d.line((10,36,22,46),fill=GOLD,width=2)
 rect(d,(0,0,47,47),None,'#a18b59');rect(d,(2,2,45,45),None,'#4b534d')
 save(im,'portraits',n,n.replace('_',' '),scale=2)
# 7 columns: idle, walk 0..3, action 0..1. Rows: down, left, right, up.
characters=['peasant_male','peasant_female','noble_male','noble_female','courier','merchant','priest','scout','militia','infantry','spearman','archer','cavalry','crossbowman','siege_engine','bandit']
for idx,n in enumerate(characters):
 sheet=canvas(32*7,40*4)
 for direction in range(4):
  for frame in range(7):
   im=canvas(32,40);d=ImageDraw.Draw(im);phase=(frame-1)%4;walk=1<=frame<=4;act=frame>=5;bob=-1 if walk and phase%2 else 0;cx=16;cy=20+bob
   d.ellipse((7,32,26,36),fill='#13282a77')
   if n=='siege_engine':
    for x in [6,24]:d.ellipse((x-3,29,x+3,36),fill='#2d3030',outline='#c3a171');d.line((x-2 if walk and phase%2 else x,31,x+2 if walk and phase%2 else x,34),fill='#a68b5c');d.point((x-1,30+(phase if walk else 0)),fill=LIGHT)
    d.polygon([(5,29),(12,18),(25,29)],fill='#80653f',outline=INK);d.line((7,27,25,27),fill='#c6a570',width=3);d.line((17,26,23-(frame%2)*5 if act else 25,8+(frame%2)*6),fill='#c7a66f',width=3);d.ellipse((21,5,26,10),fill=STONE)
    if direction==1:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT);d=ImageDraw.Draw(im)
    if direction in [0,3]:d.line((11,20 if direction==0 else 17,22,20 if direction==0 else 17),fill='#e1c48a',width=2)
   else:
    if n=='cavalry':
     d.ellipse((4,23,28,33),fill='#88684c',outline=INK);d.polygon([(23,28),(24,15),(29,13),(31,22),(28,28)],fill='#987a55',outline=INK)
     for x in [8,22]:d.line((x,30,x+(2 if phase%2 else -2),38),fill='#5e493a',width=3)
     cy-=5
    leg=(2 if phase in [0,1] else -2) if walk else 0
    for x,s in [(12,1),(20,-1)]:d.line((x,cy+8,x+leg*s,cy+14),fill='#3b3936',width=3);rect(d,(x+leg*s-1,cy+13,x+leg*s+2,cy+15),'#baa07c')
    coat=COLORS[idx%12] if idx in [2,3,4,8,12] else ['#998361','#7e8b65','#596e6b','#866746'][idx%4]
    d.polygon([(11,cy-3),(21,cy-3),(24,cy+9),(8,cy+9)],fill=coat,outline=INK);d.line((12,cy-1,12,cy+6),fill='#c1b289');d.line((9,cy+7,23,cy+7),fill='#614d34',width=2)
    d.ellipse((12,cy-12,21,cy-3),fill='#d1a37a',outline=INK);d.polygon([(11,cy-9),(12,cy-13),(19,cy-14),(22,cy-9)],fill='#685039' if idx<8 else '#8b9c98')
    if direction!=3:
     eye=15 if direction==1 else 19;d.point((eye,cy-7),fill=INK)
     if direction==0:d.point((14,cy-7),fill=INK)
    else:rect(d,(12,cy-10,20,cy-5),'#71644d' if idx<8 else '#6d8383')
    hand=cy+2+(3 if act and frame==6 else -3 if act else leg)
    d.line((10,cy-2,7,cy+3-leg),fill='#d0a17b',width=3);d.line((22,cy-2,25,hand),fill='#d0a17b',width=3)
    if idx>=8:
     if n in ['archer','crossbowman']:d.arc((22,cy-10,32,cy+10),70,290,fill='#cfb27d',width=2);d.line((27,cy-8,27,cy+9),fill='#d5d0af');d.line((22,hand,32 if act else 27,hand-1),fill=STONE)
     elif n=='spearman':d.line((26,cy+12,26,cy-17),fill='#bca072',width=2);d.polygon([(23,cy-17),(26,cy-23),(29,cy-17)],fill='#c3d0c1')
     else:d.line((25,hand,31 if act and frame==6 else 27,hand-13),fill='#dae0ce',width=2);d.line((22,hand-1,29,hand+1),fill=GOLD,width=2);d.ellipse((2,cy-1,10,cy+9),fill=coat,outline=GOLD)
    elif n=='priest':d.line((26,cy+12,26,cy-15),fill=GOLD,width=2);d.line((23,cy-12,29,cy-12),fill=GOLD)
    elif n=='merchant':rect(d,(3,cy+1,9,cy+9),'#a7824e',INK);d.ellipse((4,cy-2,8,cy+3),fill='#be9f65')
    elif n=='courier':rect(d,(23,hand-2,30,hand+3),'#e0cf9c',INK);d.line((24,hand-1,28,hand+1,29,hand-1),fill='#8e5143')
    elif n in ['noble_male','noble_female']:d.polygon([(11,cy-11),(11,cy-16),(14,cy-13),(17,cy-17),(20,cy-13),(22,cy-16),(21,cy-11)],fill=GOLD)
    elif act:d.line((25,hand,29,hand-7),fill='#a8956b',width=2)
   if act and idx>=8 and frame==6:d.arc((20,2,31,22),255,345,fill='#efdfa6',width=1)
   sheet.alpha_composite(im,(frame*32,direction*40))
 save(sheet,'characters',n,n.replace('_',' '),{'frame_width':32,'frame_height':40,'columns':7,'rows':4,'directions':['down','left','right','up'],'idle':[0],'walk':[1,2,3,4],'action':[5,6],'fps':7})
# Individually designed heraldic charges.
for i,n in enumerate(['aurelian','veyrmark','thornsreach','greyshore','harrowfen','duncrest','ashlands','sunmarch','velden','blackridge','frostholm','marrow_coast']):
 im=canvas(48,56);d=ImageDraw.Draw(im);d.polygon([(4,4),(43,4),(41,34),(35,45),(24,53),(12,45),(6,34)],fill=INK);d.polygon([(7,7),(40,7),(38,33),(32,42),(24,48),(15,42),(10,33)],fill=COLORS[i],outline=GOLD);d.line((9,9,37,9),fill='#edcd84',width=2)
 x,y=24,27;c='#eed498'
 if i==0:
  d.polygon([(19,37),(17,27),(22,23),(19,18),(25,14),(30,18),(27,22),(30,25),(26,29),(28,37),(24,38),(23,30),(22,38)],fill=c);d.line((18,30,12,33,11,24,15,20),fill=c,width=2);d.line((28,24,34,21),fill=c,width=3)
 elif i==1:
  d.polygon([(23,13),(27,21),(34,22),(29,28),(30,36),(24,32),(17,36),(18,28),(13,22),(21,21)],fill=c)
 elif i==2:
  for x in [17,24,31]:d.line((24,39,x,16),fill=c,width=2);d.line((x-4,20,x+3,26),fill=c,width=2)
 elif i==3:
  for y in [20,27,34]:d.line((12,y,18,y-2,25,y+2,34,y),fill=c,width=2)
 elif i==4:
  d.ellipse((15,18,33,33),outline=c,width=2);d.line((24,14,24,38),fill=c,width=2);d.line((17,20,31,32),fill=c,width=2)
 elif i==5:
  d.polygon([(12,35),(24,14),(36,35)],fill=c);d.polygon([(20,22),(24,14),(28,22),(25,20),(23,23)],fill='#fff0c1')
 elif i==6:
  d.polygon([(17,37),(14,26),(21,29),(24,12),(33,27),(30,37)],fill=c);d.polygon([(22,36),(24,25),(28,35)],fill=COLORS[i])
 elif i==7:
  d.ellipse((18,22,30,34),fill=c)
  for a in range(8):xx=24+math.cos(a*math.pi/4)*12;yy=28+math.sin(a*math.pi/4)*12;d.line((24,28,xx,yy),fill=c,width=2)
 elif i==8:
  d.line((24,39,24,15),fill=c,width=2)
  for y in [21,27,33]:d.ellipse((13,y-5,23,y+1),fill=c);d.ellipse((25,y-5,35,y+1),fill=c)
 elif i==9:rect(d,(16,20,32,37),c);rect(d,(21,29,26,37),INK);[rect(d,(x,16,x+4,22),c) for x in [16,22,28]]
 elif i==10:
  for a in range(6):d.line((24,28,24+math.cos(a*math.pi/3)*13,28+math.sin(a*math.pi/3)*13),fill=c,width=2)
 else:
  d.line((24,15,24,35),fill=c,width=2);d.arc((13,24,35,39),0,180,fill=c,width=2);d.line((13,31,12,27),fill=c,width=2);d.line((35,31,36,27),fill=c,width=2);d.ellipse((21,12,27,18),outline=c,width=2)
 save(im,'heraldry',n,'Герб государства',scale=2)
for i,n in enumerate(['economy','diplomacy','military','dynasty','intrigue','laws']):
 im=canvas(32,32);d=ImageDraw.Draw(im)
 if i==0:
  for x,y in [(7,21),(16,17),(23,24)]:d.rectangle((x-5,y-5,x+5,y+2),fill='#ac8446',outline=INK);d.ellipse((x-5,y-8,x+5,y-2),fill=GOLD,outline=INK);d.line((x-3,y-6,x+2,y-6),fill=LIGHT)
 elif i==1:
  d.polygon([(4,7),(27,7),(26,25),(5,25)],fill='#c8b984',outline=INK);d.line((6,9,16,18,26,9),fill='#716747');d.ellipse((13,16,19,22),fill='#9c4545')
 elif i==2:
  for a,b in [(5,4),(27,4)]:d.line((a,b,30-a,26),fill=STONE,width=4);d.line((a,b,30-a,26),fill=LIGHT,width=1)
  d.line((4,20,12,28),fill=GOLD,width=3);d.line((19,28,28,20),fill=GOLD,width=3)
 elif i==3:d.polygon([(4,24),(3,8),(11,16),(16,5),(21,16),(29,8),(28,24)],fill=GOLD,outline=INK);d.line((5,26,27,26),fill=LIGHT,width=2)
 elif i==4:
  d.polygon([(6,29),(7,13),(16,3),(25,13),(27,29)],fill='#5c6b71',outline=GOLD);d.ellipse((11,12,21,25),fill=INK);d.line((12,17,14,17),fill=LIGHT);d.line((18,17,20,17),fill=LIGHT)
 else:
  d.line((16,4,16,27),fill=GOLD,width=2);d.line((5,10,27,10),fill=GOLD,width=2);d.line((6,10,3,22,11,22,6,10),fill=GOLD);d.line((26,10,21,22,30,22,26,10),fill=GOLD);d.line((8,28,24,28),fill=GOLD,width=3)
 save(im,'heraldry','ui_'+n,'Навигация: '+n,scale=2)
effects=['trade_wagon','trade_ship','warship','siege_tower','battering_ram','arrow','stone_projectile','sword_impact','fire','dust_smoke']
for i,n in enumerate(effects):
 frames=4 if i>=7 else 1;sheet=canvas(64*frames,64)
 for f in range(frames):
  im=canvas(64,64);d=ImageDraw.Draw(im)
  if i==0:
   d.polygon([(9,29),(47,29),(53,43),(10,43)],fill='#ae8a56',outline=INK);d.polygon([(12,30),(17,16),(43,16),(49,30)],fill='#d1c399',outline=INK)
   for x in [17,43]:d.ellipse((x-6,39,x+6,51),fill=INK,outline='#ac9664');d.line((x,40,x,50),fill=GOLD)
  elif i in [1,2]:
   d.polygon([(4,43),(58,43),(49,54),(17,54)],fill='#7e6348',outline=INK);d.line((31,11,31,44),fill='#bba270',width=2);d.polygon([(33,12),(53,36),(33,37)],fill='#cebfa0' if i==1 else '#8d4548');d.polygon([(29,18),(12,37),(29,37)],fill='#e1d0a3');d.line((7,49,54,49),fill=GOLD)
  elif i==3:
   d.polygon([(12,51),(17,13),(43,13),(50,51)],fill='#906d43',outline=INK)
   for y in [19,29,39]:d.line((17,y,44,y),fill='#c3a06a',width=3)
   d.line((17,16,43,48),fill='#614b34',width=3)
   for x in [16,46]:d.ellipse((x-5,48,x+5,58),fill=INK,outline='#bfa16d')
  elif i==4:
   d.polygon([(9,28),(31,13),(55,28)],fill=ROOF,outline=INK);d.line((13,29,13,49),fill='#b39461',width=4);d.line((49,29,49,49),fill='#b39461',width=4);d.line((7,39,56,39),fill='#a68655',width=8);d.polygon([(53,33),(60,36),(60,43),(53,45)],fill=STONE)
   for x in [14,48]:d.ellipse((x-4,47,x+4,55),fill=INK,outline=GOLD)
  elif i==5:d.line((8,53,51,12),fill='#bda26d',width=2);d.polygon([(48,11),(57,7),(53,17)],fill='#e0d9b6');d.line((9,48,9,55,16,55),fill='#d0c193',width=2)
  elif i==6:d.polygon([(18,16),(39,13),(50,31),(40,48),(17,46),(10,30)],fill='#7c8987',outline=INK);d.polygon([(19,17),(38,14),(29,30),(12,30)],fill='#abb2a1')
  elif i==7:
   r=6+f*5;d.arc((32-r,32-r,32+r,32+r),220+f*12,340+f*12,fill='#f8e1a1',width=max(1,4-f));d.line((17+f*2,47-f*2,46-f,16+f),fill='#ebd48f',width=max(1,3-f))
  elif i==8:
   for j in range(5):
    x=15+j*8;h=18+((j*7+f*5)%20);d.polygon([(x-8,54),(x-5,35),(x,54-h),(x+4,35),(x+8,54)],fill='#ba5540');d.polygon([(x-4,53),(x,36-(f+j)%8),(x+5,53)],fill='#efba61');d.point((x,22+f*3),fill='#ecc175')
  else:
   for j in range(6):
    x=16+j*6+f*2;y=48-j*4-f*4;r=4+f;d.ellipse((x-r,y-r,x+r,y+r),fill=(141+f*9,139+f*7,117+f*8,210-f*40))
  sheet.alpha_composite(im,(f*64,0))
 save(sheet,'effects',n,n.replace('_',' '),{'frame_width':64,'frame_height':64,'columns':frames,'rows':1,'fps':8,'frames':frames} if frames>1 else None)
events=['coronation','royal_wedding','ruler_death','rich_harvest','epidemic','peasant_revolt','castle_siege','diplomatic_feast','betrayal','military_victory']
for i,n in enumerate(events):
 im=canvas(160,80);d=ImageDraw.Draw(im)
 for y in range(80):
  c=(27+y//5,40+y//4,51+y//7) if i not in [3,9] else (69+y//3,82+y//3,84+y//4);d.line((0,y,160,y),fill=c)
 d.ellipse((119,8,133,22),fill='#cfba83' if i in [3,9] else '#a2afa4')
 for x in range(0,160,16):mountain(d,x,51,.7,i==2)
 d.polygon([(0,55),(26,46),(53,53),(85,44),(124,51),(160,47),(160,80),(0,80)],fill='#364d3f')
 for x in range(0,160,19):tree(d,x,67,1,.55)
 b=building('grand_castle' if i in [0,2,6,9] else 'temple' if i==1 else 'farm' if i==3 else 'tavern').resize((60,60),Image.Resampling.NEAREST);im.alpha_composite(b,(82,17))
 if i in [0,1,7,8]:
  d=ImageDraw.Draw(im);d.polygon([(0,15),(8,15),(8,65),(0,73)],fill='#7d3e3d');d.polygon([(52,10),(59,10),(59,69),(52,64)],fill='#7d3e3d');d.line((0,13,61,13),fill=GOLD,width=2)
 for j in range(5 if i in [5,6,9] else 3):
  col=COLORS[(i+j)%12];x=20+j*15;y=59+(j%2)*7;d.ellipse((x-3,y-13,x+3,y-7),fill='#cfaa7d');d.polygon([(x-4,y-7),(x+4,y-7),(x+6,y+6),(x-6,y+6)],fill=col,outline=INK);d.line((x-2,y+6,x-3,y+13),fill=INK,width=2);d.line((x+2,y+6,x+3,y+13),fill=INK,width=2)
  if i in [5,6,9]:d.line((x+6,y+6,x+6,y-23),fill=GOLD);d.polygon([(x+7,y-23),(x+17,y-21),(x+14,y-14),(x+7,y-15)],fill=col)
 if i==3:
  for x in range(8,80,4):d.line((x,79,x+2,68-(x%7)),fill='#c6ab60');d.line((x,71,x+4,74),fill='#dfc580')
 if i in [4,5,6,8]:
  for x in [94,107,120]:d.polygon([(x-3,57),(x-6,43),(x-1,47),(x+2,31),(x+7,49),(x+5,59)],fill='#ce7845');d.polygon([(x,57),(x+2,46),(x+4,57)],fill='#e7bf6e')
 if i==2:rect(d,(16,58,69,70),'#4f463d',GOLD);d.line((41,61,41,67),fill=GOLD);d.line((37,63,45,63),fill=GOLD)
 if i==7:rect(d,(14,64,74,70),'#a78756',INK);[d.ellipse((x,60,x+5,65),fill=GOLD) for x in range(18,70,12)]
 if i==8:d.line((45,56,55,42),fill='#e0ddbf',width=2);d.line((46,55,50,59),fill=GOLD,width=2)
 rect(d,(0,0,159,79),None,'#9c895a');rect(d,(2,2,157,77),None,'#354444')
 save(im,'events',n,n.replace('_',' '),scale=2)
assert len(manifest)==136,len(manifest)
(ROOT/'assets_manifest.json').write_text(json.dumps({'version':1,'license':'Original project artwork; CC0-1.0','seed':1183,'resources':manifest},ensure_ascii=False,indent=2))
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',10)
cat=Image.new('RGB',(12*144,12*124),'#17262c');d=ImageDraw.Draw(cat)
for idx,it in enumerate(manifest):
 x=(idx%12)*144;y=(idx//12)*124;img=Image.open(ROOT/it['path']);
 if it['type']=='characters':img=img.crop((0,0,32,40))
 elif it.get('animation'):img=img.crop((0,0,64,64))
 img.thumbnail((126,92),Image.Resampling.NEAREST);cat.paste(img,(x+(144-img.width)//2,y+6),img);d.text((x+4,y+101),it['id'][:22],font=font,fill='#d7c796')
cat.save(ROOT/'docs/asset_catalog.png',optimize=True)
print('Created 136 original resources, 16 animated sheets, 448 character frames and catalog.')
