#!/usr/bin/env python3
"""Vibrant 0.3 art workshop. Deterministic extraction + material-aware pixel composition.
Sources: three original image-generation atlases (retained alongside this script).
Never changes world topology, gameplay data or save schemas.
"""
from PIL import Image, ImageDraw, ImageFont, ImageOps
from pathlib import Path
import json, random, math, hashlib, csv, colorsys
from atlas_extract import slice_objects
ROOT=Path(__file__).resolve().parents[1];AS=ROOT/'assets';SRC=ROOT/'tools/art_sources'
R=random.Random(20201183);OUT=[]
BASE=json.loads((SRC/'baseline_assets.json').read_text())['resources']
OLD={x['id']:x for x in BASE}
P={'ink': ['#111e2c', '#182b3b', '#253c4d', '#37566a'], 'stone': ['#403c37', '#59564a', '#7c7a65', '#a2a28a', '#c1bfa0', '#ddd0a9', '#f5e5bf'], 'wood': ['#30231e', '#41291f', '#623c24', '#89502b', '#aa6c38', '#cd9651', '#e8b96d'], 'roof': ['#392335', '#622b32', '#92372f', '#b64a32', '#d26238', '#e88b51'], 'slate': ['#172e49', '#234364', '#365f8a', '#5b8faf', '#9dc2d1'], 'gold': ['#4c3719', '#7d551e', '#b28227', '#d9a837', '#f6d361', '#ffe7a0'], 'leaf': ['#102f2b', '#154832', '#216b47', '#298344', '#3e9e4b', '#65ad4e', '#91c65a', '#c1df7b'], 'grass': ['#32683b', '#44863f', '#559b45', '#65ad4e', '#7dbf55', '#9bcc62', '#b4d377'], 'water': ['#123f69', '#185883', '#216c9e', '#287fb1', '#308cc4', '#40a8ce', '#73cedc', '#b4e6e1'], 'skin': ['#57332a', '#8a4c32', '#bb7850', '#dca16e', '#efbf8b', '#f8d6a7'], 'red': ['#481c2c', '#822b3a', '#b53c40', '#d55b4d', '#ed9270'], 'blue': ['#142e58', '#204a85', '#286eb3', '#549fd0', '#9dd1e2'], 'cloth': ['#303929', '#526743', '#889254', '#bab576', '#dfce9c', '#f5e6c0'], 'fire': ['#7f252a', '#c44129', '#ed7d2c', '#ffc04a', '#ffe993'], 'autumn': ['#574120', '#8d6526', '#bd8b32', '#e4ac44', '#f6d46a']}
RGB=lambda h:tuple(int(h.lstrip('#')[i:i+2],16) for i in (0,2,4))
COLS=[v for colors in P.values() for v in colors]
PAL=Image.new('P',(1,1));pals=[n for c in COLS for n in RGB(c)];PAL.putpalette((pals+[0]*(768-len(pals)))[:768])
REALM=['#285fa9','#b9434b','#29865b','#617fac','#94813b','#b4783f','#843b70','#d6a93d','#4d9a63','#594877','#65aabb','#258e9f']
def blank(w,h):return Image.new('RGBA',(w,h),(0,0,0,0))
def q(im,base=None):
 alpha=im.getchannel('A') if im.mode=='RGBA' else None
 if base:im=im.resize(base,Image.Resampling.NEAREST)
 alpha=im.getchannel('A') if im.mode=='RGBA' else None
 rgb=im.convert('RGB').quantize(palette=PAL,dither=Image.Dither.NONE).convert('RGBA')
 if alpha:rgb.putalpha(alpha.point(lambda x:255 if x>100 else 0))
 return rgb
def save(im,cat,id,purpose='',anim=None,new=False,usage=''):
 im=im.convert('RGBA');path=AS/cat/(id+'.png');path.parent.mkdir(parents=True,exist_ok=True);im.save(path,optimize=True)
 item={'id':id,'path':str(path.relative_to(ROOT)),'purpose':purpose or id.replace('_',' '),'size':list(im.size),'type':cat,'introduced':'0.2.0' if new else '0.1.0','revision':'0.3.0','used_by':usage}
 if anim:item['animation']=anim
 OUT.append(item);return im
def asset(id):return Image.open(ROOT/next(x['path'] for x in OUT if x['id']==id)).convert('RGBA')
def poly(d,pts,c):d.polygon([(round(x),round(y)) for x,y in pts],fill=c)
def line(d,pts,c,w=1):d.line([(round(x),round(y)) for x,y in pts],fill=c,width=w)
def atlas(name,cols,rows):
 im=Image.open(SRC/(name+'.png')).convert('RGBA');out=[]
 for j in range(rows):
  for i in range(cols):out.append(im.crop((round(i*im.width/cols),round(j*im.height/rows),round((i+1)*im.width/cols),round((j+1)*im.height/rows))))
 return out
# ARCHITECTURE: 42 different source paintings, not variants made by renaming.
old_buildings=[x['id'] for x in BASE if x['type']=='buildings']
new_buildings=['royal_citadel','grand_stone_castle','fortified_manor','noble_estate','merchant_guildhall','medieval_town_hall','great_cathedral','monastery','stone_watchtower','wooden_watchtower','armory','royal_barracks','siege_workshop','horse_stable','large_windmill','watermill','fortified_harbor','medieval_university']
for i,(name,tile) in enumerate(zip(old_buildings+new_buildings,slice_objects(SRC/'architecture.png',7,6))):
 # Normalize transparent atlas cells, keeping each silhouette and common ground baseline.
 if tile.getextrema()[3][0]==255:
  # Some image engines return a flat neutral background despite alpha requests.
  # Flood only the cell-border-connected near-white/near-black background, preserving stone interiors.
  pix=tile.load();w,h=tile.size;queue=[(x,y) for x in range(w) for y in [0,h-1]]+[(x,y) for y in range(h) for x in [0,w-1]];seen=set(queue)
  for x,y in queue:
   r,g,b,a=pix[x,y]
   if max(r,g,b)-min(r,g,b)>24 or not(max(r,g,b)>210 or max(r,g,b)<28):continue
   pix[x,y]=(0,0,0,0)
   for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
    if 0<=xx<w and 0<=yy<h and (xx,yy) not in seen:seen.add((xx,yy));queue.append((xx,yy))
 box=tile.getbbox();assert box,(name,'empty architecture source');tile=tile.crop(box)
 small=name in ['peasant_hut','house','townhouse','farm','granary','watchtower','wooden_watchtower','stone_watchtower','palisade']
 extent=102 if small else 126 if name in ['market','tavern','sawmill','smithy','horse_stable'] else 140
 tile.thumbnail((extent,extent),Image.Resampling.NEAREST);tile=q(tile);im=blank(144,144)
 im.alpha_composite(tile,((144-tile.width)//2,140-tile.height))
 save(im,'buildings',name,new=i>=24,usage='settlement tiers, construction previews, court/main-menu architecture')
# VEGETATION: leaf clusters follow branch structure and the light direction.
def oak(seed=0,autumn=False,ancient=False,dead=False):
 r=random.Random(seed);im=blank(80,96);d=ImageDraw.Draw(im);wood=P['wood'];leaf=P['autumn'] if autumn else P['leaf']
 d.ellipse((12,80,71,91),fill=(12,28,30,70))
 poly(d,[(34,87),(29,85),(35,72),(35,46),(42,35),(47,43),(43,70),(49,85),(44,88),(39,79)],wood[2]);line(d,[(37,78),(38,49),(42,40)],wood[4],2);line(d,[(43,76),(43,50)],wood[0],2)
 branches=[(37,58,17,38),(41,56,63,31),(39,44,30,18),(41,42,52,16),(35,69,22,53)]
 for x,y,xx,yy in branches:
  line(d,[(x,y),(xx,yy)],wood[2],3);line(d,[(x-1,y-1),(xx-1,yy-1)],wood[4])
  if dead:line(d,[(xx,yy),(xx-6,yy-9)],wood[3],2);line(d,[(xx,yy),(xx+8,yy-6)],wood[3])
 if not dead:
  clusters=[(21,44,17),(55,43,20),(39,24,23),(20,25,17),(55,20,17),(36,48,22)]
  for j,(cx,cy,rad) in enumerate(clusters):
   angles=[k*math.tau/15 for k in range(15)];pts=[]
   for a in angles:
    rr=rad*r.uniform(.83,1.06);pts.append((cx+math.cos(a)*rr,cy+math.sin(a)*rr*.75))
   poly(d,pts,leaf[1] if j%2==0 else leaf[2]);poly(d,[(cx-rad,cy),(cx-rad*.7,cy-rad*.55),(cx,cy-rad*.8),(cx+rad*.65,cy-rad*.25),(cx,cy+rad*.15)],leaf[min(4,len(leaf)-1)])
   for _ in range(24):
    xx=cx+r.randrange(-rad+2,rad-1);yy=cy+r.randrange(-rad//2,rad//2+1)
    if ((xx-cx)/rad)**2+((yy-cy)/(rad*.7))**2>.8:continue
    c=leaf[min(len(leaf)-1,5)] if xx+yy<cx+cy else leaf[min(3,len(leaf)-1)]
    line(d,[(xx,yy),(xx+3,yy-1),(xx+5,yy)],c);d.point((xx+1,yy-1),fill=leaf[-1] if xx<cx else c)
  if ancient:line(d,[(33,67),(27,71),(25,80)],P['leaf'][4],2)
 return im

def pine(seed=0,snow=False):
 r=random.Random(seed);im=blank(80,96);d=ImageDraw.Draw(im);d.ellipse((15,82,67,91),fill=(12,28,30,70));line(d,[(39,90),(39,20)],P['wood'][3],4)
 for tier in range(6):
  y=8+tier*11;w=8+tier*4
  pts=[(39,y),(33,y+10),(39-w,y+18),(39-w+5,y+18),(37-w,y+23),(42,y+21),(42+w,y+23),(37+w,y+17),(43+w,y+18),(43,y+8)]
  poly(d,pts,P['leaf'][1]);poly(d,[(39,y),(34,y+10),(39-w+3,y+17),(40,y+15),(46,y+18),(42,y+5)],P['leaf'][3]);line(d,[(38,y+3),(34,y+12),(41-w,y+17)],P['leaf'][5],2)
  for k in range(6):
   xx=39+r.randrange(-max(2,w-4),max(3,w-3));yy=y+r.randrange(9,19);line(d,[(xx,yy),(xx-3,yy+2)],P['leaf'][4])
  if snow:poly(d,[(39,y),(34,y+10),(39-w+4,y+16),(34,y+14),(39,y+10),(45,y+14),(42,y+7)],P['stone'][5])
 return im

def rock(seed=0,large=True):
 r=random.Random(seed);im=blank(80,96);d=ImageDraw.Draw(im)
 for j in range(4 if large else 2):
  x=17+j*13;y=78-(j%2)*10;w=r.randrange(14,24);h=r.randrange(16,30)
  poly(d,[(x-w/2,y),(x-w*.65,y-h*.4),(x-w*.25,y-h),(x+w*.3,y-h*.9),(x+w*.65,y-h*.3),(x+w/2,y+3)],P['stone'][1]);poly(d,[(x-w*.65,y-h*.4),(x-w*.25,y-h),(x+w*.3,y-h*.9),(x,y-h*.45),(x-w*.2,y-3)],P['stone'][4]);poly(d,[(x,y-h*.45),(x+w*.3,y-h*.9),(x+w*.65,y-h*.3),(x+w/2,y+3),(x-w*.2,y-3)],P['stone'][2]);line(d,[(x-w*.3,y-h*.8),(x-w*.1,y-h*.55),(x-w*.3,y-h*.4)],P['stone'][5]);line(d,[(x+1,y-h*.4),(x+6,y-h*.25),(x+3,y-2)],P['stone'][0]);line(d,[(x-w*.3,y),(x+w*.2,y+1)],P['leaf'][4],2)
 return im

def garden(kind,seed=0):
 r=random.Random(seed);im=blank(80,96);d=ImageDraw.Draw(im)
 poly(d,[(4,75),(49,56),(77,73),(33,92)],'#594b36')
 for row in range(6):
  sx=8+row*5;sy=74+row*2
  for col in range(8):
   x=sx+col*5;y=sy-col*2
   if kind in ['wheat_field','wheat_field_detail']:
    line(d,[(x,y),(x,y-10)],P['gold'][3]);line(d,[(x-2,y-8),(x+2,y-6)],P['gold'][4]);d.point((x,y-12),fill=P['gold'][4])
   elif kind=='vineyard':
    line(d,[(x,y),(x,y-11)],P['wood'][3]);d.ellipse((x-3,y-14,x+3,y-8),fill=P['leaf'][4]);d.ellipse((x-1,y-9,x+2,y-5),fill='#623941');line(d,[(x-3,y-12),(x+3,y-12)],P['leaf'][6])
   else:
    d.ellipse((x-3,y-7,x+3,y-1),fill=P['leaf'][2]);line(d,[(x-2,y-5),(x+1,y-6),(x+2,y-4)],P['leaf'][5]);d.point((x,y-4),fill='#ac6660' if col%2 else '#c5a363')
 return im

def decor(name,seed=0):
 if name in ['oak','ancient_oak']:return oak(seed,ancient=name=='ancient_oak')
 if name=='pine':return pine(seed)
 if name in ['dead_tree','dead_forest_tree']:return oak(seed,dead=True)
 if name in ['small_boulder','large_rock','large_boulder_cluster']:return rock(seed,name!='small_boulder')
 if name in ['wheat_field','wheat_field_detail','vineyard','vegetable_garden']:return garden(name,seed)
 r=random.Random(seed);im=blank(80,96);d=ImageDraw.Draw(im)
 if name in ['bush','wildflower_patch']:
  for j in range(9):
   x=12+j*7;y=76-int(math.sin(j)*5);d.ellipse((x-9,y-9,x+7,y+3),fill=P['leaf'][2]);line(d,[(x-5,y-6),(x,y-8),(x+4,y-5)],P['leaf'][5],2)
   if name=='wildflower_patch':
    for k in range(3):d.rectangle((x+k*2-3,y-7-k,x+k*2-2,y-6-k),fill=['#d4c6a1','#c58b78','#ebd395'][j%3])
 elif name=='apple_orchard':
  im.alpha_composite(oak(seed).resize((48,58),Image.Resampling.NEAREST),(1,27));im.alpha_composite(oak(seed+3).resize((48,58),Image.Resampling.NEAREST),(31,17));d=ImageDraw.Draw(im)
  for x,y in [(18,47),(28,60),(46,37),(61,50),(53,62)]:d.ellipse((x-2,y-2,x+2,y+2),fill=P['red'][3]);d.point((x-1,y-2),fill=P['red'][4])
 elif name=='fallen_tree':
  line(d,[(9,84),(69,58)],P['wood'][1],12);line(d,[(9,80),(69,54)],P['wood'][4],5);line(d,[(14,78),(58,59)],P['wood'][5]);d.ellipse((3,76,17,89),fill=P['wood'][5],outline=P['wood'][1]);d.arc((6,79,14,87),0,350,fill=P['wood'][3]);line(d,[(43,69),(33,48),(22,44)],P['wood'][2],3);line(d,[(54,64),(64,43),(72,42)],P['wood'][2],3)
 elif name in ['haystack','hay_wagon','cart','merchant_cart']:
  wagon=name!='haystack'
  if wagon:
   poly(d,[(8,63),(50,53),(72,64),(30,78)],P['wood'][3]);poly(d,[(8,63),(30,75),(30,84),(8,72)],P['wood'][2]);poly(d,[(30,75),(72,64),(72,73),(30,84)],P['wood'][4]);line(d,[(7,61),(29,72),(73,61)],P['wood'][5],2)
   for x,y in [(19,80),(60,77)]:d.ellipse((x-6,y-8,x+6,y+7),fill=P['wood'][0],outline=P['gold'][2],width=2);line(d,[(x-4,y-5),(x+4,y+5)],P['wood'][4]);line(d,[(x-4,y+4),(x+4,y-5)],P['wood'][4])
  if name in ['haystack','hay_wagon']:
   poly(d,[(12,70),(18,45),(37,34),(58,47),(67,68),(44,78)],P['gold'][2]);poly(d,[(12,70),(18,45),(37,34),(44,78)],P['gold'][3])
   for j in range(23):x=20+j*2;line(d,[(x,68),(x-3,50+abs(x-36)//2)],P['gold'][4] if j%3 else P['wood'][3])
  else:
   poly(d,[(12,59),(15,39),(25,27),(49,23),(63,35),(68,57),(29,68)],P['cloth'][3]);poly(d,[(29,68),(29,41),(34,29),(49,23),(63,35),(68,57)],P['cloth'][4]);line(d,[(13,59),(29,66),(68,56)],P['wood'][5],2)
   for x in [22,40,55]:line(d,[(x,35),(x+5,59)],P['cloth'][2],2)
 elif name in ['fence','wooden_fence_corner','stone_wall','stone_fence','wood_bridge','stone_bridge']:
  stone='stone' in name;colors=P['stone'] if stone else P['wood'];poly(d,[(4,74),(66,52),(76,62),(14,86)],colors[2]);line(d,[(5,71),(66,49),(76,59)],colors[4],3)
  if 'bridge' in name:
   for t in range(11):x=7+t*6;y=74-t*2;line(d,[(x,y),(x+10,y+9)],colors[1]);line(d,[(x,y-8),(x,y+5)],colors[3],2)
   line(d,[(5,64),(68,42)],colors[4],2);line(d,[(15,83),(77,61)],colors[3],2)
  elif stone:
   for row in range(3):
    for j in range(7):x=9+j*8+(row%2)*3;y=70-j*3-row*6;d.rectangle((x,y-5,x+7,y),fill=colors[3],outline=colors[1]);line(d,[(x+1,y-4),(x+6,y-4)],colors[5])
  else:
   for x,y in [(9,72),(28,66),(47,60),(66,54)]:poly(d,[(x-2,y+12),(x-2,y-17),(x,y-21),(x+2,y-17),(x+2,y+12)],colors[4]);line(d,[(x-1,y-16),(x-1,y+10)],colors[5])
   for off in [-10,1]:line(d,[(8,72+off),(67,52+off)],colors[3],4);line(d,[(8,71+off),(67,51+off)],colors[5])
   if name=='wooden_fence_corner':line(d,[(8,60),(34,74)],colors[3],4);line(d,[(8,70),(34,84)],colors[3],4)
 elif name in ['well','village_well','roadside_shrine']:
  d.ellipse((16,66,65,88),fill=P['stone'][1]);d.ellipse((16,61,65,79),fill=P['stone'][4]);d.ellipse((23,65,58,74),fill=P['water'][0]);line(d,[(20,69),(20,37),(59,29),(59,64)],P['wood'][3],4);poly(d,[(8,40),(32,17),(72,30),(62,41),(30,32)],P['roof'][3]);line(d,[(9,38),(32,16),(72,29)],P['roof'][5],2)
  for j in range(5):line(d,[(19+j*7,35-j),(36+j*6,25+j)],P['roof'][1])
  line(d,[(40,39),(40,63)],P['gold'][2]);d.rectangle((36,56,45,67),fill=P['wood'][3],outline=P['wood'][0])
  if name=='roadside_shrine':poly(d,[(25,70),(25,46),(41,33),(56,43),(56,69)],P['stone'][3]);line(d,[(40,43),(40,62)],P['gold'][4],2);line(d,[(33,49),(47,49)],P['gold'][4],2)
 elif name in ['ruins','abandoned_cottage']:
  b=asset('peasant_hut' if name=='abandoned_cottage' else 'stone_keep').resize((76,76),Image.Resampling.NEAREST);im.alpha_composite(b,(2,15));d=ImageDraw.Draw(im)
  poly(d,[(31,18),(49,24),(45,36),(58,42),(44,51),(31,43)],(0,0,0,0));line(d,[(15,78),(21,60),(27,69),(37,77)],P['leaf'][3],3)
  for x,y in [(10,82),(22,86),(61,84),(68,76)]:d.rectangle((x,y,x+6,y+3),fill=P['stone'][3]);line(d,[(x,y),(x+6,y)],P['stone'][5])
 elif name in ['campfire','torch']:
  if name=='torch':line(d,[(40,88),(40,47)],P['wood'][2],5);line(d,[(38,88),(38,48)],P['wood'][4])
  else:
   for a in range(8):x=40+math.cos(a*math.tau/8)*20;y=81+math.sin(a*math.tau/8)*6;d.ellipse((x-4,y-3,x+4,y+3),fill=P['stone'][3]);line(d,[(25,79),(56,84)],P['wood'][4],4)
  for j in range(3):x=32+j*8;poly(d,[(x-8,76),(x-7,58),(x-2,63),(x+2,40+j*3),(x+8,62),(x+6,77)],P['fire'][1]);poly(d,[(x-3,75),(x+1,57),(x+5,76)],P['fire'][3])
 elif name=='signpost':
  line(d,[(38,88),(38,29)],P['wood'][2],5);poly(d,[(14,33),(58,24),(68,30),(59,39),(14,47)],P['wood'][4]);line(d,[(16,34),(57,26)],P['wood'][5]);line(d,[(25,36),(48,31)],P['wood'][1],2)
 return im
old_decor=[x['id'] for x in BASE if x['type']=='decorations']
new_decor=['ancient_oak','dead_forest_tree','fallen_tree','large_boulder_cluster','wildflower_patch','apple_orchard','vineyard','vegetable_garden','wheat_field_detail','hay_wagon','merchant_cart','wooden_fence_corner','stone_fence','abandoned_cottage','roadside_shrine','village_well']
decor_tiles=slice_objects(SRC/'decorations.png',6,6)
def living_foliage(tile,name):
 # Leaf pigments are handled separately from stone, skin, wheat and UI gold.
 if name not in ['oak','ancient_oak','pine','bush','apple_orchard']:return tile
 out=tile.copy();pixels=[]
 for rr,gg,bb,aa in out.getdata():
  h,sat,val=colorsys.rgb_to_hsv(rr/255,gg/255,bb/255)
  if aa>110 and .11<h<.46 and sat>.12:
   h=(.37 if name=='pine' else .30)+(h-.23)*.24;sat=max(.48,min(.86,sat*1.15));val=min(1,val*1.06)
   rr,gg,bb=[round(c*255) for c in colorsys.hsv_to_rgb(h,sat,val)]
  pixels.append((rr,gg,bb,aa))
 out.putdata(pixels);return out
for i,(name,tile) in enumerate(zip(old_decor+new_decor,decor_tiles)):
 tile=q(living_foliage(tile,name));tile.thumbnail((76,91),Image.Resampling.NEAREST);im=blank(80,96);im.alpha_composite(tile,((80-tile.width)//2,94-tile.height))
 save(im,'decorations',name,new=i>=18,usage='biome-constrained terrain cache and settlement surroundings')
(ROOT/'data/art_palette.json').write_text(json.dumps(COLS))
# TERRAIN tiles use low-frequency material patches, tufts, cracks and flow lines.
old_terrain=[x['id'] for x in BASE if x['type']=='terrain']
new_terrain=['dense_oak_forest','ancient_pine_forest','autumn_woodland','rocky_cliffs','snowy_mountain_ridge','alpine_pass','flowering_meadow','wild_grassland','muddy_battlefield','shallow_river_rapids','rocky_coastline','sandy_coastline','forest_clearing','marshland_vegetation']
def mountains(seed,snow=False):
 r=random.Random(seed);im=blank(128,120);d=ImageDraw.Draw(im)
 for j,(x,y,w,h) in enumerate([(26,105,27,55),(75,108,43,90),(110,109,27,62)]):
  summit=(x-5,y-h);poly(d,[(x-w,y),(x-w*.6,y-h*.45),(x-w*.3,y-h*.65),summit,(x+w*.28,y-h*.65),(x+w*.55,y-h*.35),(x+w,y)],P['stone'][1]);poly(d,[(x-w,y),(x-w*.6,y-h*.45),(x-w*.3,y-h*.65),summit,(x-9,y-h*.35),(x+2,y-h*.2),(x-5,y)],P['stone'][3]);poly(d,[summit,(x+w*.28,y-h*.65),(x+w*.55,y-h*.35),(x+w,y),(x+2,y-h*.2),(x-9,y-h*.35)],P['slate'][1])
  for k in range(7):
   yy=y-h*.15-k*h*.09;xx=x-5-k*1.4;line(d,[(xx-9,yy+10),(xx,yy),(xx-3,yy-8)],P['stone'][4] if k%2 else P['stone'][2],2)
  if snow:poly(d,[(x-w*.35,y-h*.57),summit,(x+w*.3,y-h*.59),(x+6,y-h*.62),(x+1,y-h*.51),(x-7,y-h*.65),(x-11,y-h*.56)],P['stone'][5]);line(d,[(x-9,y-h*.7),summit],P['cloth'][5],2)
 return im
for idx,name in enumerate(old_terrain+new_terrain):
 r=random.Random(3000+idx);im=blank(64,64);d=ImageDraw.Draw(im);water='water' in name or 'river' in name or 'coastline' in name
 base=P['grass'][2] if name not in ['grass_lush','forest_floor','pine_forest_floor','deciduous_forest_floor'] else P['leaf'][2]
 if name in ['dry_grass','soil','muddy_battlefield']:base=P['wood'][3] if name=='soil' else P['grass'][3]
 d.rectangle((0,0,63,63),fill=base)
 for j in range(18):
  x,y=r.randrange(64),r.randrange(64);color=P['grass'][r.choice([1,2,3,4])];poly(d,[(x,y),(x+9,y-3),(x+16,y),(x+12,y+5),(x+2,y+6)],color)
 for j in range(30):
  x,y=r.randrange(64),r.randrange(64);line(d,[(x-2,y+2),(x,y-2),(x,y+1),(x+3,y-1)],P['grass'][4] if j%3 else P['grass'][1])
 if name in ['deep_water','shallow_water']:
  d.rectangle((0,0,63,63),fill=P['water'][0 if name=='deep_water' else 2])
  for y in range(4,64,9):
   for x in range(-16,64,22):line(d,[(x+(y%7),y),(x+6+(y%7),y-1),(x+15+(y%7),y)],P['water'][2 if name=='deep_water' else 4]);d.point((x+7+(y%7),y-2),fill=P['water'][3 if name=='deep_water' else 6])
 if 'river' in name:
  pts=[(30,0),(26,17),(33,39),(30,64)]
  if name=='river_bend':pts=[(30,0),(28,17),(37,30),(64,33)]
  line(d,pts,P['grass'][5],21);line(d,pts,P['stone'][2],17);line(d,pts,P['water'][3],14);line(d,[(x-4,y) for x,y in pts],P['water'][5],2)
  if name=='river_junction':line(d,[(30,31),(64,31)],P['water'][3],14)
  for y in range(6,64,11):line(d,[(28,y),(34,y-1),(37,y)],P['water'][6])
 if name in ['coastline_straight','coastline_corner','rocky_coastline','sandy_coastline']:
  poly(d,[(0,0),(23,0),(27,9),(23,21),(31,33),(26,46),(29,64),(0,64)],P['water'][2]);line(d,[(24,0),(28,9),(24,21),(32,33),(27,46),(30,64)],P['gold'][2] if name=='sandy_coastline' else P['stone'][4],4);line(d,[(18,0),(22,10),(18,22),(26,34),(21,47),(24,64)],P['water'][6],2)
  if name=='rocky_coastline':im.alpha_composite(rock(12).resize((32,38),Image.Resampling.NEAREST),(17,19))
 if 'road' in name:
  line(d,[(31,0),(29,28),(33,64)],P['wood'][1],19);line(d,[(31,0),(29,28),(33,64)],P['wood'][4] if name=='dirt_road' else P['stone'][3],15)
  for y in range(0,64,6):line(d,[(24,y),(38,y+1)],P['wood'][2] if name=='dirt_road' else P['stone'][1]);d.rectangle((27+(y%3),y+2,29+(y%3),y+3),fill=P['wood'][5] if name=='dirt_road' else P['stone'][5])
 if name in ['farmland','flowering_meadow','wild_grassland','marsh','marshland_vegetation']:
  if name=='farmland':im.alpha_composite(garden('wheat_field').resize((64,77),Image.Resampling.NEAREST),(0,-15))
  elif 'marsh' in name:
   for j in range(8):
    x,y=r.randrange(54),r.randrange(58);d.ellipse((x,y,x+11,y+4),fill=P['water'][2]);line(d,[(x+2,y),(x+1,y-6)],P['leaf'][5]);line(d,[(x+5,y+1),(x+7,y-5)],P['gold'][2])
  elif name=='flowering_meadow':
   for j in range(20):x,y=r.randrange(62),r.randrange(62);d.rectangle((x,y,x+1,y+1),fill=P['cloth'][5] if j%3 else P['gold'][4])
 if name in ['grassy_hills','rocky_hills','rocky_cliffs']:
  for x,y in [(19,35),(46,57)]:
   d.arc((x-21,y-18,x+21,y+7),185,330,fill=P['grass'][5] if name=='grassy_hills' else P['stone'][4],width=3);d.arc((x-17,y-10,x+20,y+10),3,115,fill=P['grass'][1],width=2)
  if name=='rocky_cliffs':
   for x in range(0,64,8):poly(d,[(x,25+x%9),(x+7,21+x%9),(x+7,54),(x,59)],P['stone'][2]);line(d,[(x,28),(x,54)],P['stone'][4],2)
 if name in ['mountain_base','snow_mountains','snowy_mountain_ridge','alpine_pass']:
  ridge=q(decor_tiles[34]);ridge.thumbnail((70 if name=='snowy_mountain_ridge' else 63,59),Image.Resampling.NEAREST);im.alpha_composite(ridge,((64-ridge.width)//2,64-ridge.height))
  if name=='mountain_base':
   px=im.load()
   for yy in range(64):
    for xx in range(64):
     rr,gg,bb,aa=px[xx,yy]
     if min(rr,gg,bb)>170:px[xx,yy]=(155,169,163,aa)
  if name=='alpine_pass':d=ImageDraw.Draw(im);line(d,[(20,64),(29,49),(25,40),(35,31),(36,20)],P['gold'][2],2)
 if name=='rocky_cliffs':
  cliff=q(decor_tiles[35]);cliff.thumbnail((60,59),Image.Resampling.NEAREST);im.alpha_composite(cliff,((64-cliff.width)//2,64-cliff.height))
 if name=='wild_grassland':
  d=ImageDraw.Draw(im)
  for j in range(22):
   x,y=r.randrange(58),r.randrange(12,64);line(d,[(x-2,y),(x,y-9),(x,y-2),(x+4,y-6)],P['grass'][5])
 if name=='shallow_river_rapids':
  d=ImageDraw.Draw(im)
  for yy in [12,23,35,49]:line(d,[(25,yy),(28,yy-2),(33,yy+1),(37,yy-1)],P['cloth'][5],2)
  im.alpha_composite(asset('small_boulder').resize((15,18),Image.Resampling.NEAREST),(23,24))
 if name in ['dense_oak_forest','ancient_pine_forest','autumn_woodland','forest_clearing']:
  for x,y in [(0,-18),(29,-28),(-8,9),(24,6),(6,31)]:
   tree=asset('pine') if name=='ancient_pine_forest' else oak(idx+y,autumn=True) if name=='autumn_woodland' else asset('oak')
   if name=='forest_clearing' and y>0:continue
   im.alpha_composite(tree.resize((40,48),Image.Resampling.NEAREST),(x,y))
 if name=='muddy_battlefield':
  for x,y in [(7,38),(32,20),(51,50)]:line(d,[(x,y),(x+8,y-13)],P['wood'][1],2);d.ellipse((x-4,y-3,x+6,y+2),fill=P['wood'][2]);line(d,[(x+2,y+5),(x+19,y-1)],P['stone'][2])
 save(im,'terrain',name,new=idx>=22,usage='continuous biome texture blending and constrained terrain brush patches')
# PORTRAITS: all 18 old faces are repainted, twelve new personalities are additional.
old_portraits=[x['id'] for x in BASE if x['type']=='portraits']
new_portraits=['portrait_warrior_king','portrait_wise_monarch','portrait_ambitious_queen','portrait_young_heiress','portrait_arrogant_duke','portrait_treacherous_noble','portrait_famous_general','portrait_old_marshal','portrait_rich_merchant','portrait_grim_inquisitor','portrait_secret_councillor','portrait_rebel_pretender']
for i,(name,tile) in enumerate(zip(old_portraits+new_portraits,atlas('portraits',6,5))):
 side=min(tile.size);x=(tile.width-side)//2;y=(tile.height-side)//2;tile=tile.crop((x,y,x+side,y+side));tile=q(tile,(64,64)).resize((128,128),Image.Resampling.NEAREST)
 save(tile,'portraits',name,new=i>=18,usage='VisualLibrary.portrait: role, age, traits and character identity; compatible with old IDs')
# ANIMATED CHARACTERS: articulated poses, layered costume, tool-specific actions.
old_chars=[x['id'] for x in BASE if x['type']=='characters']
new_chars=['royal_guard','heavy_infantry','elite_spearman','royal_archer','mounted_knight','light_cavalry','royal_messenger','village_farmer','lumberjack','blacksmith','miner','market_trader','noble_lady','noble_lord','royal_advisor','court_priest','tax_collector','village_guard','rebel_fighter','siege_engineer']
combat=set(['militia','infantry','spearman','archer','cavalry','crossbowman','siege_engine','bandit','scout','royal_guard','heavy_infantry','elite_spearman','royal_archer','mounted_knight','light_cavalry','village_guard','rebel_fighter','siege_engineer'])
def actor(name,idx,direction,frame):
 im=blank(40,56);d=ImageDraw.Draw(im);walk=1<=frame<=4;act=5<=frame<=7;hurt=frame>=8;phase=(frame-1)%4
 bob=[0,-1,0,1][phase] if walk else 0;cx=20+(-2 if hurt and frame==8 else 1 if hurt else 0);cy=25+bob
 heavy=name in ['heavy_infantry','royal_guard','mounted_knight','infantry'];female=name in ['peasant_female','noble_female','noble_lady'];mounted=name in ['cavalry','mounted_knight','light_cavalry'];battle=name in combat
 metal=P['stone'];wood=P['wood'];skin=P['skin'];cloth=P['blue'] if idx%4==0 else P['red'] if idx%4==1 else P['cloth'] if idx%4==2 else P['leaf']
 if name in ['royal_guard','royal_archer','mounted_knight','royal_messenger']:cloth=P['blue']
 if name in ['rebel_fighter','bandit']:cloth=P['red']
 if name=='siege_engine':
  for x in [9,31]:
   d.ellipse((x-5,42,x+5,52),fill=wood[0],outline=wood[4],width=2);a=phase*math.pi/4 if walk else frame*.15;line(d,[(x-math.cos(a)*4,47-math.sin(a)*4),(x+math.cos(a)*4,47+math.sin(a)*4)],wood[5])
  poly(d,[(5,43),(13,26),(26,26),(35,43)],wood[3]);line(d,[(9,41),(30,41)],wood[5],3);line(d,[(15,27),(15,43)],wood[1],3);line(d,[(25,27),(25,43)],wood[1],3)
  tipx=12 if direction==1 else 31 if direction==2 else 18;tipy=10+(frame-5)*8 if act else 15
  line(d,[(19,36),(tipx,tipy)],wood[4],4);line(d,[(18,35),(tipx-1,tipy)],wood[6]);d.ellipse((tipx-4,tipy-5,tipx+3,tipy+1),fill=metal[3],outline=metal[0]);line(d,[(11,40),(27,28)],wood[0]);return im
 if mounted:
  cy=17+bob
  poly(d,[(4,35),(9,29),(27,29),(31,22),(35,23),(38,30),(34,33),(31,41),(11,42)],wood[3]);poly(d,[(8,33),(23,30),(29,34),(25,39),(9,39)],wood[4]);poly(d,[(30,23),(34,21),(35,26),(38,29),(34,30)],wood[5]);line(d,[(30,24),(30,34)],wood[0],2)
  for j,(x,y) in enumerate([(8,40),(13,40),(27,39),(31,37)]):
   stride=[-3,0,3,0][(phase+j)%4] if walk else 0;line(d,[(x,y),(x+stride,y+10)],wood[1],3);line(d,[(x+stride-1,y+11),(x+stride+2,y+11)],metal[2],2)
  line(d,[(5,34),(1,42)],wood[0],3);d.rectangle((13,29,25,35),fill=cloth[2],outline=P['gold'][2]);line(d,[(29,28),(23,24)],wood[0])
 # Cape is an articulated silhouette with lit edge and folds.
 caped=battle or name in ['noble_male','noble_female','noble_lady','noble_lord','royal_advisor','royal_messenger','courier']
 if caped:
  sway=[-2,0,2,0][phase] if walk else 0
  poly(d,[(cx-7,cy-3),(cx+7,cy-3),(cx+10+sway,cy+18),(cx+3+sway,cy+21),(cx-10+sway,cy+19)],cloth[0]);poly(d,[(cx-6,cy-3),(cx-1,cy),(cx-2+sway,cy+18),(cx-8+sway,cy+18)],cloth[2]);line(d,[(cx-7,cy),(cx-9+sway,cy+18)],P['gold'][2])
 stride=[-3,0,3,0][phase] if walk else 0
 for j,x in enumerate([cx-4,cx+4]):
  end=x+stride*(1 if j==0 else -1);line(d,[(x,cy+13),(end,cy+23)],metal[1] if heavy else wood[1],4);line(d,[(x-1,cy+14),(end-1,cy+21)],metal[3] if heavy else cloth[2],1);d.rectangle((end-2,cy+22,end+3,cy+25),fill=wood[0]);line(d,[(end-2,cy+22),(end+2,cy+22)],wood[4])
 # Tunic / brigandine / dress.
 bw=8 if heavy else 6
 poly(d,[(cx-bw,cy-2),(cx+bw,cy-2),(cx+bw+1,cy+13),(cx-1,cy+16),(cx-bw-1,cy+13)],metal[2] if heavy else cloth[2]);poly(d,[(cx-bw+1,cy),(cx-1,cy),(cx-1,cy+13),(cx-bw,cy+12)],metal[4] if heavy else cloth[3]);line(d,[(cx,cy+1),(cx,cy+12)],metal[0] if heavy else cloth[0])
 if battle:
  for yy in range(cy+2,cy+10,3):
   for xx in range(cx-bw+2,cx+bw-1,3):d.point((xx,yy),fill=metal[4] if yy%2 else metal[0])
  for x in [cx-bw-1,cx+bw-2]:poly(d,[(x-2,cy-2),(x+3,cy-3),(x+5,cy+2),(x+2,cy+5),(x-3,cy+3)],metal[2]);line(d,[(x-1,cy-2),(x+3,cy-2),(x+4,cy)],metal[5])
 if female:poly(d,[(cx-7,cy+9),(cx+7,cy+9),(cx+11,cy+22),(cx-10,cy+22)],cloth[2]);line(d,[(cx-6,cy+12),(cx-8,cy+20)],cloth[4]);line(d,[(cx+3,cy+12),(cx+6,cy+20)],cloth[0])
 d.rectangle((cx-bw,cy+10,cx+bw,cy+12),fill=wood[1]);d.rectangle((cx-1,cy+10,cx+2,cy+12),fill=P['gold'][3])
 # Face planes: temple shadow, cheek, nose, eyes; back and side directions differ.
 hy=cy-12
 poly(d,[(cx-4,hy-3),(cx+3,hy-4),(cx+6,hy),(cx+5,hy+7),(cx+1,hy+10),(cx-4,hy+7),(cx-6,hy+1)],skin[3]);poly(d,[(cx+3,hy-3),(cx+6,hy),(cx+5,hy+7),(cx+1,hy+10),(cx+1,hy+3)],skin[1]);line(d,[(cx-4,hy),(cx-4,hy+5)],skin[4],2)
 hair=wood[1+idx%3]
 poly(d,[(cx-6,hy+1),(cx-5,hy-4),(cx-1,hy-6),(cx+4,hy-4),(cx+6,hy),(cx+2,hy-2),(cx-2,hy-1)],hair)
 if direction==3:
  poly(d,[(cx-5,hy-1),(cx+5,hy-1),(cx+4,hy+7),(cx,hy+9),(cx-4,hy+7)],hair);line(d,[(cx-3,hy-1),(cx-3,hy+4)],wood[4])
 else:
  if direction!=2:d.point((cx-3,hy+3),fill=P['ink'][0]);d.point((cx-3,hy+2),fill=skin[5])
  if direction!=1:d.point((cx+3,hy+3),fill=P['ink'][0]);d.point((cx+3,hy+2),fill=skin[4])
  nose=cx-5 if direction==1 else cx+5 if direction==2 else cx;line(d,[(nose,hy+3),(nose,hy+6)],skin[5]);line(d,[(cx-1,hy+8),(cx+2,hy+8)],skin[0])
 if battle and name not in ['archer','royal_archer','scout','bandit','rebel_fighter']:
  poly(d,[(cx-6,hy),(cx-6,hy-4),(cx-2,hy-7),(cx+3,hy-6),(cx+6,hy-2),(cx+6,hy+1)],metal[2]);line(d,[(cx-5,hy-3),(cx-1,hy-6),(cx+2,hy-5)],metal[5],2);line(d,[(cx-5,hy+1),(cx+5,hy+1)],P['gold'][2] if 'royal' in name else metal[0]);line(d,[(cx+4,hy+2),(cx+4,hy+7)],metal[1],2)
  if heavy:line(d,[(cx,hy-3),(cx,hy+6)],metal[4]);d.rectangle((cx-3,hy+3,cx-1,hy+4),fill=P['ink'][0]);d.rectangle((cx+1,hy+3,cx+3,hy+4),fill=P['ink'][0])
 if name in ['noble_lord','noble_lady','noble_male','noble_female','royal_advisor']:
  line(d,[(cx-5,hy-4),(cx-5,hy-8),(cx-2,hy-5),(cx+1,hy-9),(cx+3,hy-5),(cx+6,hy-8),(cx+5,hy-4)],P['gold'][3],2)
 if 'priest' in name:poly(d,[(cx-7,hy+2),(cx-6,hy-6),(cx,hy-10),(cx+6,hy-6),(cx+7,hy+3),(cx+3,hy-1),(cx-3,hy-1)],P['cloth'][4]);line(d,[(cx,hy-9),(cx,hy-3)],P['gold'][3])
 if name in ['miner','lumberjack','blacksmith','siege_engineer']:
  d.rectangle((cx-6,hy-3,cx+6,hy),fill=wood[2]);line(d,[(cx-5,hy-4),(cx+3,hy-4)],wood[4],2)
  if name=='miner':d.rectangle((cx-2,hy-5,cx+1,hy-2),fill=P['gold'][4])
 # Arms articulate independently of feet, action swings span three distinct poses.
 swing=[-2,-1,2,1][phase] if walk else 0
 near=(cx+10,cy+5+swing);far=(cx-10,cy+6-swing)
 if act:
  near=[(cx+8,cy-9),(cx+12,cy-13),(cx+16,cy+5)][frame-5]
  far=[(cx-9,cy+6),(cx-8,cy+3),(cx-9,cy-1)][frame-5]
 if hurt:near=(cx+9,cy-3);far=(cx-10,cy+11)
 for start,end in [((cx-7,cy),far),((cx+7,cy),near)]:
  line(d,[start,((start[0]+end[0])/2,start[1]+4),end],metal[2] if battle else cloth[2],4);d.rectangle((end[0]-1,end[1]-1,end[0]+2,end[1]+2),fill=skin[3]);d.point((end[0]-1,end[1]-1),fill=skin[5])
 x,y=near
 if name in ['spearman','elite_spearman','village_guard','village_farmer','peasant_male']:
  line(d,[(x,y+12),(x-1,y-25)],wood[4],2);poly(d,[(x-4,y-24),(x-1,y-33),(x+2,y-24)],metal[4]);line(d,[(x-1,y-30),(x-1,y-24)],metal[6])
 elif name in ['archer','royal_archer','crossbowman']:
  d.arc((x-4,y-15,x+6,y+13),255,100,fill=wood[5],width=2);line(d,[(x+1,y-13),(x-2-(3 if act and frame==6 else 0),y),(x+1,y+12)],P['cloth'][4]);line(d,[(x-7,y),(x+12 if act and frame==7 else x+6,y)],metal[4])
 elif name in ['lumberjack','miner','blacksmith','siege_engineer']:
  tip=(x-8,y-15) if not act else (x-9,y-10) if frame==5 else (x-3,y-15) if frame==6 else (x+6,y-4)
  line(d,[(x,y),tip],wood[4],2)
  if name=='lumberjack':poly(d,[(tip[0]-4,tip[1]-6),(tip[0]+4,tip[1]-3),(tip[0]+4,tip[1]+3),(tip[0]-4,tip[1]+1)],metal[3]);line(d,[(tip[0]-4,tip[1]-6),(tip[0]-4,tip[1]+1)],metal[6])
  elif name=='miner':line(d,[(tip[0]-6,tip[1]-3),(tip[0],tip[1]-6),(tip[0]+6,tip[1]-2)],metal[4],2)
  else:d.rectangle((tip[0]-5,tip[1]-4,tip[0]+4,tip[1]),fill=metal[2]);line(d,[(tip[0]-4,tip[1]-4),(tip[0]+3,tip[1]-4)],metal[5])
 elif battle:
  tip=(x+2,y-17) if not act else (x-9,y-12) if frame==5 else (x-1,y-21) if frame==6 else (x+14,y-4)
  line(d,[(x,y),tip],metal[3],3);line(d,[(x-1,y-1),(tip[0]-1,tip[1])],metal[6]);line(d,[(x-4,y-1),(x+4,y+1)],P['gold'][3],2)
  sx,sy=far;poly(d,[(sx-4,sy-5),(sx+5,sy-5),(sx+5,sy+5),(sx,sy+10),(sx-5,sy+5)],cloth[2]);line(d,[(sx-4,sy-4),(sx+4,sy-4),(sx+4,sy+4),(sx,sy+8),(sx-4,sy+4),(sx-4,sy-4)],metal[4]);line(d,[(sx,sy-3),(sx,sy+6)],P['gold'][3])
 elif name in ['court_priest','priest']:
  line(d,[(x,y+15),(x,y-20)],P['gold'][3],2);line(d,[(x-4,y-15),(x+4,y-15)],P['gold'][4],2)
 elif name in ['courier','royal_messenger','royal_advisor','tax_collector']:
  d.rectangle((x-3,y-4,x+4,y+3),fill=P['cloth'][4],outline=P['wood'][3]);line(d,[(x-2,y-3),(x+3,y-3)],P['cloth'][5]);d.rectangle((x,y,x+1,y+1),fill=P['red'][3])
 elif name in ['merchant','market_trader']:
  d.ellipse((x-4,y-1,x+4,y+7),fill=P['wood'][4],outline=P['wood'][1]);line(d,[(x-2,y-2),(x+2,y-2)],P['gold'][2],2)
 elif name in ['noble_female','noble_lady']:
  poly(d,[(x,y+1),(x-5,y-6),(x+4,y-9),(x+7,y-2)],P['cloth'][4]);line(d,[(x,y),(x+4,y-7)],P['gold'][2])
 # Elite/new roles have purpose-specific costume details, not recoloured duplicates.
 if name in ['royal_guard','heavy_infantry','elite_spearman']:
  line(d,[(cx-5,cy+2),(cx+5,cy+7)],P['gold'][3],2);d.rectangle((cx-2,hy-10,cx+1,hy-7),fill=P['red'][3] if name=='heavy_infantry' else P['blue'][4]);line(d,[(cx-5,cy+13),(cx-3,cy+18)],metal[4],2)
 if name=='royal_messenger':
  poly(d,[(cx-5,cy+3),(cx+5,cy+3),(cx+4,cy+11),(cx,cy+14),(cx-4,cy+11)],P['gold'][3]);poly(d,[(cx-3,cy+5),(cx+3,cy+5),(cx,cy+11)],P['blue'][1]);line(d,[(cx-8,cy),(cx-10,cy+13)],P['gold'][4])
 if name=='royal_archer':
  poly(d,[(cx-7,hy),(cx-4,hy-7),(cx+3,hy-7),(cx+7,hy),(cx+4,hy-3),(cx-3,hy-3)],P['blue'][2]);line(d,[(cx-4,hy-6),(cx+2,hy-6)],P['gold'][3]);line(d,[(cx+7,cy+8),(cx+10,cy+15)],P['wood'][3],3)
 if name=='tax_collector':d.rectangle((cx-9,cy+9,cx-3,cy+15),fill=P['wood'][3],outline=P['gold'][2]);d.point((cx-6,cy+11),fill=P['gold'][4])
 if hurt:d.line((cx-7,cy-1,cx+3,cy+7),fill=P['red'][4],width=1)
 return im
for idx,name in enumerate(old_chars+new_chars):
 sheet=blank(400,224)
 for direction in range(4):
  for frame in range(10):sheet.alpha_composite(actor(name,idx,direction,frame),(frame*40,direction*56))
 anim={'frame_width':40,'frame_height':56,'columns':10,'rows':4,'directions':['down','left','right','up'],'idle':[0],'walk':[1,2,3,4],'action':[5,6,7],'hurt':[8,9] if name in combat else [],'fps':8,'combat':name in combat}
 save(sheet,'characters',name,anim=anim,new=idx>=16,usage='MapActors ambient cast and army roles; recruit previews; battle hurt state')
# HERALDRY AND OLD NAVIGATION: painted metal rims and readable medieval charges.
old_herald=[x['id'] for x in BASE if x['type']=='heraldry']
for idx,name in enumerate(old_herald):
 is_ui=name.startswith('ui_');im=blank(96,112 if not is_ui else 96);d=ImageDraw.Draw(im)
 if not is_ui:
  pts=[(11,9),(84,9),(82,61),(70,88),(48,105),(26,88),(14,61)];poly(d,pts,P['gold'][1]);line(d,pts+[pts[0]],P['ink'][0],3);inner=[(16,14),(79,14),(76,59),(66,83),(48,98),(30,83),(19,59)];poly(d,inner,REALM[idx%12]);line(d,inner+[inner[0]],P['gold'][3],2);line(d,[(17,16),(77,16)],P['gold'][5],2)
  # Different charges: lion, star, thorn, waves, wheel, peak, flame, sun, oak, tower, snow, anchor.
  x,y=48,54;c=P['gold'][4]
  if idx==0:
   poly(d,[(36,75),(32,56),(42,45),(37,37),(48,25),(59,34),(55,43),(64,49),(57,59),(60,77),(51,79),(47,62),(44,78)],c);line(d,[(36,62),(24,70),(20,54),(27,42)],c,4);line(d,[(56,46),(70,37)],c,5);d.point((53,33),fill=P['ink'][0]);line(d,[(35,75),(31,79)],P['gold'][2],3)
  elif idx==1:
   poly(d,[(48+math.cos(a*math.pi/5)*(28 if a%2==0 else 12),53+math.sin(a*math.pi/5)*(28 if a%2==0 else 12)) for a in range(10)],c)
  elif idx==2:
   for x in [32,48,64]:line(d,[(48,82),(x,29)],c,3);line(d,[(x-7,40),(x+5,51)],c,3)
  elif idx==3:
   for y in [37,53,69]:line(d,[(24,y),(35,y-4),(48,y+3),(61,y-4),(73,y)],c,3)
  elif idx==4:
   d.ellipse((25,30,72,77),outline=c,width=3)
   for a in range(8):line(d,[(48,54),(48+math.cos(a*math.pi/4)*24,54+math.sin(a*math.pi/4)*24)],c,2)
  elif idx==5:poly(d,[(22,77),(48,28),(75,77)],c);poly(d,[(38,47),(48,28),(59,48),(50,43),(45,50)],P['cloth'][5])
  elif idx==6:poly(d,[(32,78),(23,54),(37,61),(48,24),(67,56),(60,78)],c);poly(d,[(44,75),(48,55),(57,75)],REALM[idx])
  elif idx==7:
   d.ellipse((35,41,61,67),fill=c)
   for a in range(12):line(d,[(48+math.cos(a*math.pi/6)*18,54+math.sin(a*math.pi/6)*18),(48+math.cos(a*math.pi/6)*28,54+math.sin(a*math.pi/6)*28)],c,3)
  elif idx==8:
   line(d,[(48,81),(48,30)],c,4)
   for y in [43,56,69]:d.ellipse((25,y-10,46,y+2),fill=c);d.ellipse((49,y-10,70,y+2),fill=c)
  elif idx==9:
   d.rectangle((30,39,66,79),fill=c);d.rectangle((42,62,53,79),fill=P['ink'][1])
   for x in [30,43,57]:d.rectangle((x,30,x+8,43),fill=c)
  elif idx==10:
   for a in range(6):
    xx=48+math.cos(a*math.pi/3)*29;yy=54+math.sin(a*math.pi/3)*29;line(d,[(48,54),(xx,yy)],c,3);line(d,[(xx-5,yy-8),(xx,yy),(xx+7,yy-4)],c,2)
  else:
   line(d,[(48,31),(48,77)],c,4);d.arc((24,46,72,81),0,180,fill=c,width=4);line(d,[(25,64),(24,54)],c,3);line(d,[(71,64),(72,54)],c,3);d.ellipse((42,22,54,34),outline=c,width=3)
  for x,y in [(14,11),(82,11),(20,66),(75,66)]:d.rectangle((x,y,x+2,y+2),fill=P['gold'][5])
 else:
  # Navigation icons use small dimensional objects, not single-colour UI blocks.
  kind=name[3:];c=P['gold'][3]
  if kind=='economy':
   for x,y in [(22,66),(46,51),(70,71)]:
    for z in range(4):d.ellipse((x-13,y-z*5-8,x+13,y-z*5+3),fill=P['gold'][2],outline=P['gold'][0]);d.arc((x-10,y-z*5-7,x+10,y-z*5+1),180,330,fill=P['gold'][4],width=2)
  elif kind=='diplomacy':
   poly(d,[(14,24),(82,24),(79,73),(18,73)],P['cloth'][4]);line(d,[(17,27),(48,51),(79,27)],P['wood'][3],2);d.ellipse((40,47,56,63),fill=P['red'][3],outline=P['red'][0]);line(d,[(44,52),(48,48),(52,52),(48,58),(44,52)],P['gold'][3])
  elif kind=='military':
   for flip in [False,True]:
    a,b=(18,78) if not flip else (78,18);line(d,[(a,77),(b,17)],P['stone'][1],7);line(d,[(a-2,77),(b-2,17)],P['stone'][5],3);line(d,[(a-9,68),(a+9,83)],P['gold'][3],4)
  elif kind=='dynasty':
   poly(d,[(19,69),(12,25),(31,43),(47,17),(65,43),(84,25),(77,69)],P['gold'][2]);line(d,[(21,66),(16,31),(31,48),(47,24),(65,48),(80,31),(75,66)],P['gold'][4],2);d.rectangle((22,72,76,80),fill=P['gold'][3]);d.rectangle((43,51,51,62),fill=P['red'][3])
  elif kind=='intrigue':
   poly(d,[(15,82),(20,33),(48,12),(77,33),(82,82)],P['slate'][1]);poly(d,[(23,79),(28,34),(48,19),(39,42),(36,79)],P['slate'][3]);d.ellipse((32,36,65,73),fill=P['ink'][0]);line(d,[(37,51),(43,49)],P['gold'][4],2);line(d,[(53,49),(59,51)],P['gold'][4],2)
  else:
   line(d,[(48,17),(48,77)],c,4);line(d,[(17,34),(79,34)],c,3)
   for x in [22,74]:line(d,[(x,35),(x-12,64),(x+12,64),(x,35)],P['gold'][3],2);d.arc((x-13,57,x+13,71),0,180,fill=P['gold'][4],width=3)
   line(d,[(28,82),(68,82)],P['gold'][3],5)
 save(im,'heraldry',name,usage='realm borders, banners, portrait cards, country selection and navigation')
# VEHICLES / EFFECTS: multi-frame fire, dust and blade flashes.
old_effects=[x['id'] for x in BASE if x['type']=='effects']
for idx,name in enumerate(old_effects):
 count=8 if name in ['fire','dust_smoke','sword_impact'] else 1;sheet=blank(80*count,80)
 for f in range(count):
  im=blank(80,80);d=ImageDraw.Draw(im)
  if name=='trade_wagon':im=decor('merchant_cart',200).crop((0,16,80,96))
  elif name in ['trade_ship','warship']:
   poly(d,[(6,52),(72,47),(63,65),(24,71)],P['wood'][2]);poly(d,[(10,54),(68,51),(61,61),(25,66)],P['wood'][4]);line(d,[(13,56),(64,53)],P['gold'][2],2);line(d,[(39,10),(39,56)],P['wood'][4],3);poly(d,[(41,12),(67,42),(42,43)],P['cloth'][4] if name=='trade_ship' else P['red'][3]);poly(d,[(36,19),(15,46),(36,45)],P['cloth'][3]);line(d,[(42,15),(45,40)],P['cloth'][5]);line(d,[(18,47),(67,43)],P['wood'][0]);poly(d,[(41,8),(58,10),(52,18),(41,17)],P['blue'][3] if name=='trade_ship' else P['red'][3])
   for x in range(22,64,8):line(d,[(x,60),(x+5,64)],P['wood'][0])
  elif name in ['siege_tower','battering_ram']:
   if name=='siege_tower':
    poly(d,[(15,63),(23,17),(55,17),(66,63)],P['wood'][2]);poly(d,[(19,58),(25,20),(39,20),(41,59)],P['wood'][4]);line(d,[(25,21),(58,59)],P['wood'][0],3)
    for y in [28,40,52]:line(d,[(24,y),(58,y)],P['wood'][5],3)
    for x in [20,60]:d.ellipse((x-7,59,x+7,73),fill=P['wood'][0],outline=P['wood'][4],width=2)
   else:
    poly(d,[(8,31),(39,10),(72,28),(65,37),(39,21),(16,40)],P['roof'][3]);line(d,[(15,37),(15,62)],P['wood'][4],4);line(d,[(65,35),(65,60)],P['wood'][4],4);line(d,[(12,52),(70,46)],P['wood'][3],9);line(d,[(12,49),(68,43)],P['wood'][5],2);d.rectangle((64,41,74,50),fill=P['stone'][3]);d.ellipse((15,59,27,71),fill=P['wood'][1],outline=P['wood'][5]);d.ellipse((55,55,67,67),fill=P['wood'][1],outline=P['wood'][5])
  elif name=='arrow':
   line(d,[(11,67),(65,13)],P['wood'][5],2);poly(d,[(60,12),(74,5),(68,20)],P['stone'][5]);line(d,[(11,59),(11,68),(20,68)],P['cloth'][4],2);line(d,[(15,55),(15,64),(24,64)],P['cloth'][2],2)
  elif name=='stone_projectile':im=rock(112,False).resize((64,77),Image.Resampling.NEAREST);im=ImageOps.pad(im,(80,80),method=Image.Resampling.NEAREST)
  elif name=='sword_impact':
   radius=8+f*4;d.arc((40-radius,40-radius,40+radius,40+radius),210+f*9,320+f*9,fill=P['gold'][4],width=max(1,5-f//2));d.arc((42-radius,42-radius,40+radius,40+radius),220+f*9,315+f*9,fill=P['cloth'][5],width=2)
   for j in range(4):a=(j*math.pi/2)+f*.2;line(d,[(40+math.cos(a)*radius,40+math.sin(a)*radius),(40+math.cos(a)*(radius+4),40+math.sin(a)*(radius+4))],P['gold'][3])
  elif name=='fire':
   for j in range(6):
    x=16+j*9;h=20+(j*9+f*7)%28;poly(d,[(x-8,71),(x-8,51),(x-2,57),(x+2,71-h),(x+8,51),(x+7,71)],P['fire'][1]);poly(d,[(x-5,69),(x+1,54-h//4),(x+5,70)],P['fire'][3]);poly(d,[(x-1,70),(x+1,59),(x+3,70)],P['fire'][4]);d.rectangle((x+f%3,38-(f*5+j*2)%18,x+f%3+1,39-(f*5+j*2)%18),fill=P['fire'][3])
  else:
   for j in range(7):
    x=15+j*7+f*2;y=65-j*4-f*3;rr=6+f//2;d.ellipse((x-rr,y-rr,x+rr,y+rr),fill=(116+f*4,122+f*3,113+f*3,180-f*15));d.arc((x-rr+2,y-rr+1,x+rr-2,y+rr-2),190,300,fill=(181,177,148,130-f*10),width=2)
  sheet.alpha_composite(im,(f*80,0))
 anim={'frame_width':80,'frame_height':80,'columns':count,'rows':1,'fps':8,'frames':count} if count>1 else None
 save(sheet,'effects',name,anim=anim,usage='trade routes, army march, siege and battle effects')
# NEW MILITARY objects: compact formations and field equipment.
new_military=['infantry_formation','pike_formation','archer_formation','cavalry_formation','royal_army_banner','rebel_army_banner','siege_camp','war_tent','trebuchet','battlefield_ruins']
for idx,name in enumerate(new_military):
 im=blank(128,112);d=ImageDraw.Draw(im)
 if idx<4:
  kind=['heavy_infantry','elite_spearman','royal_archer','mounted_knight'][idx];sheet=asset(kind);unit=sheet.crop((0,0,40,56)).resize((28,39),Image.Resampling.NEAREST)
  for row in range(3):
   for col in range(4 if idx!=3 else 3):im.alpha_composite(unit,(8+col*25+(row%2)*5,12+row*23))
 elif idx in [4,5]:
  cloth=P['blue'] if idx==4 else P['red'];line(d,[(32,105),(32,9)],P['wood'][4],4);poly(d,[(31,9),(36,2),(41,9)],P['gold'][4]);poly(d,[(35,12),(102,17),(91,64),(68,77),(40,67)],cloth[1]);poly(d,[(35,12),(70,15),(66,72),(40,67)],cloth[2]);line(d,[(38,16),(98,20),(88,61),(68,72),(43,64)],P['gold'][3],2);crest=asset('aurelian' if idx==4 else 'veyrmark').resize((39,45),Image.Resampling.NEAREST);im.alpha_composite(crest,(47,21))
 elif idx in [6,7]:
  def tent(x,y,s=1):
   poly(d,[(x-28*s,y),(x,y-40*s),(x+31*s,y-1*s),(x+20*s,y+10*s),(x-20*s,y+12*s)],P['cloth'][2]);poly(d,[(x,y-40*s),(x+31*s,y-1*s),(x+20*s,y+10*s),(x+2*s,y-3*s)],P['red'][2]);poly(d,[(x,y-15*s),(x+9*s,y+9*s),(x-7*s,y+10*s)],P['ink'][0]);line(d,[(x,y-46*s),(x,y-38*s)],P['wood'][4],2);poly(d,[(x+2*s,y-46*s),(x+19*s,y-42*s),(x+14*s,y-36*s),(x+2*s,y-38*s)],P['blue'][2]);line(d,[(x-28*s,y),(x-35*s,y+12*s)],P['wood'][3]);line(d,[(x+30*s,y),(x+36*s,y+11*s)],P['wood'][3])
  if idx==6:tent(37,71,.7);tent(87,67,.6);im.alpha_composite(decor('campfire',0).resize((40,48),Image.Resampling.NEAREST),(47,61))
  else:tent(62,84,1.2)
 elif name=='trebuchet':
  for x,y in [(26,92),(93,86)]:d.ellipse((x-8,y-8,x+8,y+8),fill=P['wood'][0],outline=P['wood'][5],width=2);line(d,[(x-5,y-5),(x+5,y+5)],P['wood'][4]);line(d,[(x+5,y-5),(x-5,y+5)],P['wood'][4])
  line(d,[(25,87),(51,37),(90,83)],P['wood'][2],9);line(d,[(29,85),(51,43),(86,81)],P['wood'][5],2);line(d,[(25,87),(91,82)],P['wood'][4],6);line(d,[(43,70),(82,12)],P['wood'][4],5);line(d,[(45,68),(84,12)],P['wood'][5]);line(d,[(82,12),(108,30)],P['wood'][1],2);d.ellipse((102,25,115,37),fill=P['stone'][3],outline=P['stone'][0]);d.rectangle((30,59,47,78),fill=P['wood'][2],outline=P['wood'][0]);line(d,[(30,60),(46,60)],P['wood'][5])
 else:
  im.alpha_composite(decor('ruins',4).resize((96,105),Image.Resampling.NEAREST),(10,5));d=ImageDraw.Draw(im);line(d,[(16,90),(63,62)],P['wood'][3],3);line(d,[(41,79),(51,95)],P['stone'][4],3);poly(d,[(68,82),(94,74),(100,86),(79,95)],P['red'][1]);line(d,[(85,73),(85,51)],P['wood'][4],2)
 save(im,'military',name,new=True,usage='army LOD formations, campaign banners, active sieges and recent battle sites')
# PREMIUM UI: 9-slice materials, crests and ornament. No input-handling nodes.
new_ui=['ui_ornate_menu_frame','ui_royal_crown','ui_province_frame','ui_portrait_frame','ui_resource_bar','ui_medieval_buttons','ui_dynasty_tree','ui_victory_ornament']
def frame_panel(w,h,ornate=True):
 im=Image.new('RGBA',(w,h),P['ink'][1]);d=ImageDraw.Draw(im)
 # Slate planes: quiet centre, embossed metal bevels, ornamental corners only.
 d.rectangle((0,0,w-1,h-1),outline=P['ink'][0],width=3);d.rectangle((3,3,w-4,h-4),outline=P['gold'][1],width=2);d.rectangle((5,5,w-6,h-6),outline=P['gold'][3]);d.rectangle((8,8,w-9,h-9),outline=P['ink'][3]);line(d,[(9,9),(w-10,9)],P['stone'][1]);line(d,[(9,h-10),(w-10,h-10)],P['ink'][0])
 if ornate:
  for x,y,sx,sy in [(5,5,1,1),(w-6,5,-1,1),(5,h-6,1,-1),(w-6,h-6,-1,-1)]:
   def lp(points,c,width=1):line(d,[(x+px*sx,y+py*sy) for px,py in points],c,width)
   lp([(0,20),(5,17),(4,10),(10,4),(17,5),(20,0)],P['gold'][2],2);lp([(1,18),(7,15),(6,10),(10,6),(15,7),(18,1)],P['gold'][4]);poly(d,[(x+7*sx,y+7*sy),(x+12*sx,y+6*sy),(x+9*sx,y+12*sy)],P['gold'][3]);d.rectangle((x-1,y-1,x+1,y+1),fill=P['gold'][5])
 return im
for idx,name in enumerate(new_ui):
 if idx in [0,2,3,4]:
  sizes={0:(256,256),2:(192,256),3:(144,144),4:(256,96)};im=frame_panel(*sizes[idx],ornate=idx!=4)
  if idx==3:ImageDraw.Draw(im).rectangle((15,15,128,128),fill=(0,0,0,0))
 elif idx==5:
  im=blank(192,64*4)
  for j in range(4):
   tile=frame_panel(192,64,False);d=ImageDraw.Draw(tile)
   if j==1:d.rectangle((9,9,182,54),fill=P['ink'][3]);line(d,[(11,11),(180,11)],P['gold'][4])
   if j==2:d.rectangle((6,6,185,57),outline=P['gold'][5],width=2)
   if j==3:tile=Image.blend(tile,Image.new('RGBA',tile.size,P['ink'][0]),.55)
   im.alpha_composite(tile,(0,j*64))
 elif idx==1:
  im=blank(192,128);d=ImageDraw.Draw(im);poly(d,[(35,82),(25,26),(55,53),(95,13),(133,53),(166,26),(156,82)],P['gold'][1]);poly(d,[(40,78),(32,35),(55,60),(95,24),(133,60),(160,35),(150,78)],P['gold'][3]);line(d,[(38,77),(32,35),(55,60),(95,24),(133,60),(160,35),(151,77)],P['gold'][5],2);d.rectangle((39,87,151,100),fill=P['gold'][3],outline=P['gold'][0]);line(d,[(42,89),(148,89)],P['gold'][5],2)
  for x,c in [(55,P['blue'][3]),(95,P['red'][3]),(134,P['leaf'][5])]:d.ellipse((x-5,65,x+5,76),fill=c,outline=P['gold'][5]);d.point((x-2,67),fill=P['cloth'][5])
 else:
  im=blank(256,128);d=ImageDraw.Draw(im)
  if idx==6:
   line(d,[(128,16),(128,58),(64,58),(64,95)],P['gold'][2],2);line(d,[(128,58),(192,58),(192,95)],P['gold'][2],2)
   for x,y in [(128,18),(64,101),(192,101)]:d.ellipse((x-13,y-12,x+13,y+12),outline=P['gold'][3],width=2);d.ellipse((x-9,y-8,x+9,y+8),outline=P['gold'][1])
  else:
   for sign in [-1,1]:
    for j in range(12):
     x=128+sign*(25+j*6);y=98-j*4;poly(d,[(x,y),(x+sign*8,y-13),(x+sign*14,y-12),(x+sign*10,y-2)],P['gold'][2 if j%2 else 3]);line(d,[(x,y),(x+sign*10,y-10)],P['gold'][4])
   im.alpha_composite(asset('ui_royal_crown').resize((96,64),Image.Resampling.NEAREST),(80,6));line(d,[(60,108),(196,108)],P['gold'][3],2)
 save(im,'ui',name,new=True,usage='9-slice menu/province/resource/portrait surfaces, button states, genealogy and victory decoration')
# EVENTS: all twelve new scenes; older ten retain their IDs with focused compositions.
new_events=['event_royal_coronation','event_capital_siege','event_great_battle','event_royal_marriage','event_noble_betrayal','event_peasant_rebellion','event_medieval_plague','event_royal_funeral','event_harvest_festival','event_diplomatic_summit','event_city_fire','event_empire_foundation']
event_tiles=atlas('events',3,4)
for i,(name,tile) in enumerate(zip(new_events,event_tiles)):
 tile=q(tile,(512,256));save(tile,'events',name,new=True,usage='EventSystem windows and main-menu panorama (empire foundation)')
old_events=[x['id'] for x in BASE if x['type']=='events'];source_idx=[0,3,7,8,6,5,1,9,4,2]
for i,(name,source) in enumerate(zip(old_events,source_idx)):
 tile=event_tiles[source];w,h=tile.size
 # A deliberately tighter foreground/story crop, framed in the same material language.
 crop=tile.crop((int(w*.16),int(h*.03),int(w*.86),int(h*.9)));crop=q(crop,(192,96)).resize((384,192),Image.Resampling.NEAREST)
 d=ImageDraw.Draw(crop);d.rectangle((0,0,383,191),outline=P['gold'][2],width=2);d.rectangle((4,4,379,187),outline=P['ink'][1],width=2)
 save(crop,'events',name,usage='legacy saved event illustration IDs; alternate foreground composition')
# Stable manifest, exact counts and a compact before/after registry.
assert len(OUT)==246,len(OUT)
assert sum(x['introduced']=='0.2.0' for x in OUT)==110
assert set(OLD).issubset({x['id'] for x in OUT})
(ROOT/'assets_manifest.json').write_text(json.dumps({'version':2,'art_version':'0.3.0','license':'Original project artwork, CC0-1.0; fonts separately licensed','sources':['tools/art_sources/architecture.png','tools/art_sources/portraits.png','tools/art_sources/events.png','tools/art_sources/decorations.png'],'resources':OUT},ensure_ascii=False,indent=2))
with (ROOT/'docs/asset_revision.csv').open('w',newline='') as f:
 writer=csv.writer(f,lineterminator="\n");writer.writerow(['ID','category','decision','old_size','new_size','old_sha256','new_sha256','runtime_use'])
 for a in OUT:
  if a['id'] not in OLD:continue
  old=OLD[a['id']];digest=hashlib.sha256((ROOT/a['path']).read_bytes()).hexdigest();assert digest!=old['before_sha256'],a['id']
  writer.writerow([a['id'],a['type'],'Replace' if a['type'] in ['buildings','portraits','characters','events'] else 'Improve',str(old['size']),str(a['size']),old['before_sha256'],digest,a['used_by']])
font=ImageFont.truetype(str(AS/'fonts/DejaVuSans.ttf'),10)
w=1920;cellw=160;cellh=136;rows=math.ceil(len(OUT)/12);catalog=Image.new('RGB',(w,rows*cellh),'#17252c');d=ImageDraw.Draw(catalog)
for i,a in enumerate(OUT):
 x=(i%12)*cellw;y=(i//12)*cellh;im=Image.open(ROOT/a['path']).convert('RGBA')
 if a['type']=='characters':im=im.crop((0,0,40,56))
 elif a.get('animation'):im=im.crop((0,0,80,80))
 elif a['id']=='ui_medieval_buttons':im=im.crop((0,0,192,64))
 im.thumbnail((144,106),Image.Resampling.NEAREST);catalog.paste(im,(x+(cellw-im.width)//2,y+3+(106-im.height)//2),im);d.text((x+4,y+112),a['id'][:24],font=font,fill='#ebd395' if a['introduced']=='0.2.0' else '#9ba9a3');d.line((x,y+134,x+158,y+134),fill='#344b52')
catalog.save(ROOT/'docs/asset_catalog_after.png',optimize=True);catalog.save(ROOT/'docs/asset_catalog.png',optimize=True)
print('VIBRANT MATERIALS: 246 existing resources regenerated; Niyazov extension listed above. 36 articulated sheets, 1440 frames.')

import subprocess,sys
if (SRC/"niyazov_story.png").exists() and (SRC/"niyazov_heraldry.png").exists():subprocess.run([sys.executable,str(ROOT/"tools/niyazov_art.py")],check=True)

if (SRC/"settlements_v0_3_1.png").exists():subprocess.run([sys.executable,str(ROOT/"tools/settlement_art.py")],check=True)
