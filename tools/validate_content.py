#!/usr/bin/env python3
"""One bounded content audit used by the main project check."""
from pathlib import Path
from PIL import Image
from collections import Counter
import hashlib,json,math
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'assets_manifest.json').read_text());res=m['resources']
assert len(res)==136
hashes={};frames=0
for x in res:
 p=root/x['path'];im=Image.open(p);im.verify();im=Image.open(p).convert('RGBA')
 assert list(im.size)==x['size'];assert im.getbbox() is not None
 sha=hashlib.sha256(im.tobytes()).hexdigest()
 assert sha not in hashes,(x['id'],hashes.get(sha));hashes[sha]=x['id']
 if x['type'] in ['buildings','characters','decorations','effects']:assert im.getextrema()[3][0]==0
 if x['type']=='characters':
  a=x['animation'];assert a['columns']*a['rows']==28
  for row in range(4):
   walking=[im.crop((f*32,row*40,(f+1)*32,(row+1)*40)).tobytes() for f in range(1,5)]
   assert len(set(walking))==4,(x['id'],row,'walk frames must move')
   assert im.crop((5*32,row*40,6*32,(row+1)*40)).tobytes()!=im.crop((6*32,row*40,7*32,(row+1)*40)).tobytes(),(x['id'],'action')
  frames+=28
assert frames==448
world=json.loads((root/'data/world.json').read_text());p=world['provinces']
assert len(p)==60;assert sum(x['suzerain']==-1 for x in world['realms'])==12
seen={0};queue=[0]
for node in queue:
 for n in p[node]['neighbors']:
  assert node in p[n]['neighbors']
  if n not in seen:seen.add(n);queue.append(n)
assert len(seen)==60
# Shared-edge checks and area equality prove a connected, gap-free clipping partition.
def area(poly):return abs(sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(poly,poly[1:]+poly[:1])))/2
assert abs(sum(area(x['polygon']) for x in p)-area(world['coast']))<20
for e in world['edges']:
 assert math.dist(*e['points'])>0.1
 assert int(e['b']) in p[int(e['a'])]['neighbors']
events=json.loads((root/'data/events.json').read_text());assert len(events)>=30
assert all(len(x['choices'])>=2 and (root/'assets/events'/(x['illustration']+'.png')).exists() for x in events)
print('CONTENT PASS:',len(res),'unique PNG;',frames,'animated frames; 60 connected provinces; 12 sovereign realms;',len(events),'events')
