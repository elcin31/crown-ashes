#!/usr/bin/env python3
"""0.3.1: original clean architecture and composed settlement tiers, stable IDs."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from atlas_extract import slice_objects
from io import BytesIO
import json,subprocess,hashlib
ROOT=Path(__file__).resolve().parents[1];AS=ROOT/'assets';SRC=ROOT/'tools/art_sources'
m=json.loads((ROOT/'assets_manifest.json').read_text());m['resources']=[a for a in m['resources'] if a.get('introduced')!='0.3.1']
ids=['peasant_hut','house','townhouse','farm','granary','market','small_castle','wooden_fort','fortified_manor','stone_keep','noble_estate','windmill']
extents=[90,106,112,120,104,122,136,130,138,124,138,140]
pal=Image.new('P',(1,1));colours=json.loads((ROOT/'data/art_palette.json').read_text());raw=[int(c.lstrip('#')[i:i+2],16) for c in colours for i in (0,2,4)];pal.putpalette(raw+[0]*(768-len(raw)))
old={};revisions=[]
for id in ids:
 a=next(a for a in m['resources'] if a['id']==id)
 old[id]=Image.open(BytesIO(subprocess.check_output(['git','show','dfd6f13:'+a['path']],cwd=ROOT))).convert('RGBA')
for id,extent,tile in zip(ids,extents,slice_objects(SRC/'settlements_v0_3_1.png',3,4)):
 tile=tile.crop(tile.getbbox());tile.thumbnail((extent,extent),Image.Resampling.NEAREST)
 alpha=tile.getchannel('A');tile=tile.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');tile.putalpha(alpha.point(lambda a:255 if a>=120 else 0))
 im=Image.new('RGBA',(144,144));im.alpha_composite(tile,((144-tile.width)//2,140-tile.height))
 path=AS/'buildings'/(id+'.png');im.save(path,optimize=True);assert im.getbbox() and im.getextrema()[3][0]==0
 a=next(a for a in m['resources'] if a['id']==id);a.update(revision='0.3.1',used_by='VisualLibrary settlements, construction panels and static settlement satellites')
 revisions.append({'id':id,'path':a['path'],'decision':'Replace','reason':'clean silhouette, ordered roofing, distinct openings and larger readable material clusters'})
def settlement(name,buildings,paths):
 im=Image.new('RGBA',(192,160));d=ImageDraw.Draw(im)
 for pts in paths:d.line(pts,fill='#89502b',width=8);d.line(pts,fill='#cd9651',width=5)
 for id,width,x,ground in buildings:
  tile=Image.open(AS/'buildings'/(id+'.png')).convert('RGBA');tile=tile.crop(tile.getbbox());tile=tile.resize((width,round(tile.height*width/tile.width)),Image.Resampling.NEAREST);im.alpha_composite(tile,(x-width//2,ground-tile.height))
 path=AS/'buildings'/(name+'.png');im.save(path,optimize=True)
 m['resources'].append({'id':name,'path':str(path.relative_to(ROOT)),'size':[192,160],'type':'buildings','purpose':{'village_cluster':'Читаемая деревня: три различных двора','town_quarter':'Торговый город: квартал и рыночная площадь','walled_town':'Укреплённый город: стены, донжон и дома'}[name],'introduced':'0.3.1','revision':'0.3.1','used_by':'VisualLibrary.settlement; population/development/fortification tiers on live map'})
settlement('village_cluster',[('house',70,99,117),('peasant_hut',63,38,148),('farm',64,154,146)],[[(37,152),(96,137),(153,153)],[(97,140),(99,115)]])
settlement('town_quarter',[('townhouse',71,45,130),('noble_estate',91,117,119),('market',105,113,155)],[[(31,151),(85,135),(172,142)]])
settlement('walled_town',[('small_castle',155,97,133),('townhouse',65,41,156),('granary',50,162,153)],[[(20,155),(102,142),(177,155)]])
m['art_version']='0.3.1';m['sources']+=['tools/art_sources/settlements_v0_3_1.png'];m['sources']=list(dict.fromkeys(m['sources']))
(ROOT/'assets_manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))
# One contact sheet at native and phone-map scale; historical paintings remain in git.
font=ImageFont.truetype(str(AS/'fonts/DejaVuSans.ttf'),15);sheet=Image.new('RGB',(1440,720),'#182b3b');d=ImageDraw.Draw(sheet)
for i,id in enumerate(ids):
 x=(i%6)*240;y=(i//6)*330;after=Image.open(AS/'buildings'/(id+'.png')).convert('RGBA')
 d.text((x+8,y+8),id,font=font,fill='#f6d361')
 for art,xx,label in [(old[id],x+8,'0.3.0'),(after,x+126,'0.3.1')]:
  tile=art.resize((108,108),Image.Resampling.NEAREST);sheet.paste(tile,(xx,y+36),tile);d.text((xx,y+148),label,font=font,fill='#c1bfa0')
 for art,xx in [(old[id],x+20),(after,x+135)]:
  tile=art.resize((68,68),Image.Resampling.NEAREST);sheet.paste(tile,(xx,y+190),tile)
 d.text((x+8,y+272),'Native / map-size comparison',font=font,fill='#91a7a5')
sheet.save(ROOT/'docs/building_comparison_0.3.1.png',optimize=True)
for a in m['resources']:
 im=Image.open(ROOT/a['path']);im.verify()
 assert list(Image.open(ROOT/a['path']).size)==a['size']
result={'version':'0.3.1','game_png':len(m['resources']),'repainted_buildings':12,'new_settlement_tiers':3,'sprite_sheets_unchanged':36,'stable_old_ids':True,'revisions':revisions}
(ROOT/'docs/ART_CHECK_0.3.1.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('SETTLEMENT ART:',len(m['resources']),'game PNG;12 original replacements,3 composed settlement tiers; all PNG decoded.')
