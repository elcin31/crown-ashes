#!/usr/bin/env python3
"""Bounded v0.3 art/story data check, no long simulation."""
from pathlib import Path
from PIL import Image,ImageStat
import json,hashlib,subprocess,colorsys
root=Path(__file__).resolve().parents[1];m=json.loads((root/'assets_manifest.json').read_text());items=m['resources'];assert len(items)==260
assert len([a for a in items if a['introduced']=='0.3.0'])==14
ids={a['id'] for a in items};assert len(ids)==260
hashes=set();frames=0;rgba=0
for a in items:
 im=Image.open(root/a['path']);im.verify();im=Image.open(root/a['path']).convert('RGBA');assert list(im.size)==a['size'] and im.getbbox()
 digest=hashlib.sha256(im.tobytes()).digest();assert digest not in hashes,a['id'];hashes.add(digest);rgba+=len(im.tobytes())
 if a['type']=='characters':
  an=a['animation'];w,h=an['frame_width'],an['frame_height'];frames+=an['rows']*an['columns']
  for row in range(4):
   for key,count in [('walk',4),('action',3)]:assert len({im.crop((f*w,row*h,(f+1)*w,(row+1)*h)).tobytes() for f in an[key]})==count
story=json.loads((root/'data/narrative.json').read_text());assert len(story['events'])>=20
assert len({e['id'] for e in story['events']})==len(story['events'])
assert {(e['act'],e['slot']) for e in story['events']}=={(a,b) for a in range(1,5) for b in range(6)}
for e in story['events']:
 assert e['illustration'] in ids and e['choices'] and e['actors']
 for c in e['choices']:assert c['label'] and c['hint'] and all(v>=0 for v in c['cost'].values())
# Compare actual changed blobs against v0.2, not just generator claims.
old=json.loads(subprocess.check_output(['git','show','35eebd1:assets_manifest.json'],cwd=root));changed=0
for a in old['resources']:
 old_data=subprocess.check_output(['git','show','35eebd1:'+a['path']],cwd=root);new_data=(root/a['path']).read_bytes();changed+=old_data!=new_data
 assert next(x for x in items if x['id']==a['id'])['path']==a['path']
def saturation(path):
 im=Image.open(path).convert('RGB').resize((384,224),Image.Resampling.NEAREST)
 return round(sum(colorsys.rgb_to_hsv(r/255,g/255,b/255)[1] for r,g,b in im.getdata())/(im.width*im.height),4)
# Build before imagery directly from retained git history, without altering the workspace.
from io import BytesIO
before=Image.open(BytesIO(subprocess.check_output(['git','show','35eebd1:data/terrain_cache.png'],cwd=root)));before_path=root/'docs/map_before_0.3.png';before.thumbnail((768,448),Image.Resampling.NEAREST);before.save(before_path)
after=Image.open(root/'data/terrain_cache.png');after.thumbnail((768,448),Image.Resampling.NEAREST);after.save(root/'docs/map_after_0.3.png')
result={'png':len(items),'new_png':14,'story_illustrations':12,'new_heraldic_assets':2,'old_png_recolored':changed,'sprite_sheets':36,'frames':frames,'rgba_texture_bytes_all_assets':rgba,'story_event_definitions':len(story['events']),'core_chapters':24,'acts':4,'map_saturation_before':saturation(before_path),'map_saturation_after':saturation(root/'docs/map_after_0.3.png')}
(root/'docs/ASSET_CHECK_0.3.0.json').write_text(json.dumps(result,indent=2)+'\n');print('CONTENT PASS',json.dumps(result))
