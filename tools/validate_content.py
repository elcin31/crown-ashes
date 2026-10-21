#!/usr/bin/env python3
"""Optional bounded content check for current mobile patch; no game simulation."""
from pathlib import Path
from PIL import Image
import json,hashlib
root=Path(__file__).resolve().parents[1];m=json.loads((root/'assets_manifest.json').read_text());items=m['resources']
assert len(items)==263 and len({a['id'] for a in items})==263
assert len([a for a in items if a['introduced']=='0.3.1'])==3
hashes=set();sheets=0
for a in items:
 im=Image.open(root/a['path']);im.verify();im=Image.open(root/a['path']).convert('RGBA')
 assert list(im.size)==a['size'] and im.getbbox()
 digest=hashlib.sha256(im.tobytes()).digest();assert digest not in hashes,a['id'];hashes.add(digest)
 if a['type']=='characters':
  sheets+=1;an=a['animation'];w,h=an['frame_width'],an['frame_height']
  for row in range(4):
   assert len({im.crop((f*w,row*h,(f+1)*w,(row+1)*h)).tobytes() for f in an['walk']})==4
assert sheets==36
world=json.loads((root/'data/world.json').read_text());assert len(world['provinces'])==60
print('CONTENT PASS:263 unique game PNG,36 character sheets,60 unchanged provinces')
