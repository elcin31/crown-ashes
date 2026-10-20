#!/usr/bin/env python3
"""One bounded content check for Kingdom Reforged, not a long gameplay audit."""
from pathlib import Path
from PIL import Image
from collections import Counter
import hashlib,json
root=Path(__file__).resolve().parents[1];m=json.loads((root/'assets_manifest.json').read_text());items=m['resources'];baseline=json.loads((root/'tools/art_sources/baseline_assets.json').read_text())['resources']
assert len(items)==246
new=[a for a in items if a['introduced']=='0.2.0'];assert len(new)==110
expected={'terrain':14,'buildings':18,'characters':20,'portraits':12,'military':10,'decorations':16,'ui':8,'events':12}
assert Counter(a['type'] for a in new)==expected
hashes={};frames=0;sheet_count=0;texture_bytes=0
for a in items:
 p=root/a['path'];im=Image.open(p);im.verify();im=Image.open(p).convert('RGBA');assert list(im.size)==a['size']
 assert im.getbbox() is not None,(a['id'],'empty')
 raw=im.tobytes();digest=hashlib.sha256(raw).hexdigest();assert digest not in hashes,(a['id'],'duplicate',hashes.get(digest));hashes[digest]=a['id'];texture_bytes+=len(raw)
 if a['type'] in ['buildings','characters','decorations','military']:assert im.getextrema()[3][0]==0,a['id']
 if a['type']=='characters':
  anim=a['animation'];w,h=anim['frame_width'],anim['frame_height'];assert anim['rows']==4 and anim['columns']==10
  for row in range(4):
   walks=[im.crop((f*w,row*h,(f+1)*w,(row+1)*h)).tobytes() for f in anim['walk']]
   actions=[im.crop((f*w,row*h,(f+1)*w,(row+1)*h)).tobytes() for f in anim['action']]
   assert len(set(walks))==4,(a['id'],row,'walking frames')
   assert len(set(actions))==3,(a['id'],row,'action frames')
  if anim['combat']:assert len(anim['hurt'])==2
  frames+=anim['rows']*anim['columns'];sheet_count+=1
for old in baseline:
 current=next(a for a in items if a['id']==old['id']);assert current['path']==old['path']
 assert hashlib.sha256((root/current['path']).read_bytes()).hexdigest()!=old['before_sha256']
world=json.loads((root/'data/world.json').read_text());assert len(world['provinces'])==60
assert sum(r['suzerain']==-1 for r in world['realms'])==12
result={'png':246,'new_png':110,'old_reworked':136,'sprite_sheets':sheet_count,'new_sprite_sheets':20,'frames':frames,'new_frames':800,'rgba_texture_bytes_all_assets':texture_bytes,'new_categories':dict(Counter(a['type'] for a in new))}
(root/'docs/ASSET_CHECK_0.2.0.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('ART PASS:',json.dumps(result,ensure_ascii=False))
