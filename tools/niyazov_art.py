#!/usr/bin/env python3
"""Pixel-normalize original Niyazov paintings; shared material palette, stable old IDs."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,math
ROOT=Path(__file__).resolve().parents[1];AS=ROOT/'assets';SRC=ROOT/'tools/art_sources'
m=json.loads((ROOT/'assets_manifest.json').read_text());m['resources']=[a for a in m['resources'] if a.get('introduced')!='0.3.0']
colors=json.loads((ROOT/'data/art_palette.json').read_text());pal=Image.new('P',(1,1));raw=[int(c.lstrip('#')[i:i+2],16) for c in colors for i in (0,2,4)];pal.putpalette(raw+[0]*(768-len(raw)))
def pixel(im):
 alpha=im.getchannel('A');out=im.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');out.putalpha(alpha.point(lambda x:255 if x>110 else 0));return out
def save(im,id,cat,purpose):
 path=AS/cat/(id+'.png');path.parent.mkdir(exist_ok=True,parents=True);im.save(path,optimize=True)
 m['resources'].append({'id':id,'path':str(path.relative_to(ROOT)),'size':list(im.size),'type':cat,'purpose':purpose,'introduced':'0.3.0','revision':'0.3.0','used_by':'NarrativeSystem, main menu, genealogy, royal capital and armies' if cat=='heraldry' else 'NarrativeSystem chapters and endings; main menu/campaign palace panorama'})
source=Image.open(SRC/'niyazov_story.png').convert('RGBA')
names=['coronation','council','palace','family','conspiracy','rebellion','battlefield','wedding','feast','funeral','throne','empire']
for i,name in enumerate(names):
 x=i%3;y=i//3;w=source.width/3;h=source.height/4
 tile=source.crop((round(x*w+3),round(y*h+3),round((x+1)*w-3),round((y+1)*h-3))).resize((512,256),Image.Resampling.NEAREST)
 save(pixel(tile),'story_'+name,'events','Наследие Ниязовых: '+name)
crest=Image.open(SRC/'niyazov_heraldry.png').convert('RGBA');crest=crest.crop(crest.getbbox());crest.thumbnail((124,136),Image.Resampling.NEAREST);crest=pixel(crest)
emblem=Image.new('RGBA',(128,144));emblem.alpha_composite(crest,((128-crest.width)//2,144-crest.height));save(emblem,'niyazov','heraldry','Дом Ниязовых: синий щит с золотым коронованным львом')
banner=Image.new('RGBA',(80,144));d=ImageDraw.Draw(banner);d.rectangle((8,5,12,143),fill='#89502b');d.line((10,7,74,7),fill='#f6d361',width=3)
d.polygon([(17,10),(73,10),(73,120),(58,110),(46,127),(32,113),(17,122)],fill='#142e58',outline='#d9a837',width=2)
for y in range(14,116,4):d.line((20,y,69,y),fill='#204a85' if y%12 else '#286eb3')
small=emblem.resize((53,60),Image.Resampling.NEAREST);banner.alpha_composite(small,(19,22));d.line((21,102,68,102),fill='#d9a837',width=2);save(banner,'niyazov_standard','heraldry','Королевский штандарт Ниязовых: войска и королевская столица')
m['art_version']='0.3.0';m['sources']+=['tools/art_sources/niyazov_story.png','tools/art_sources/niyazov_heraldry.png'];m['sources']=list(dict.fromkeys(m['sources']))
(ROOT/'assets_manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))
font=ImageFont.truetype(str(AS/'fonts/DejaVuSans.ttf'),10);cw,ch=160,138;canvas=Image.new('RGB',(1920,math.ceil(len(m['resources'])/12)*ch),'#182b3b');d=ImageDraw.Draw(canvas)
for i,a in enumerate(m['resources']):
 x=i%12*cw;y=i//12*ch;im=Image.open(ROOT/a['path']).convert('RGBA')
 if a['type']=='characters':im=im.crop((0,0,40,56))
 elif a.get('animation'):im=im.crop((0,0,80,80))
 elif a['id']=='ui_medieval_buttons':im=im.crop((0,0,192,64))
 im.thumbnail((144,110),Image.Resampling.NEAREST);canvas.paste(im,(x+(cw-im.width)//2,y+(110-im.height)//2),im);d.text((x+3,y+114),a['id'][:25],font=font,fill='#f6d361' if a['introduced']=='0.3.0' else '#c1bfa0')
canvas.save(ROOT/'docs/asset_catalog_0.3.png',optimize=True)
print('NIYAZOV ART:',len(m['resources']),'game PNG,12 narrative scenes,2 new heraldic assets')
