#!/usr/bin/env python3
"""Living Kingdoms: deliberate architectural modules and articulated pixel actors.

No random texture/noise, recoloured legacy files or runtime image generation.
The twelve original palace paintings are retained as source, with hard alpha.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, math, shutil
from atlas_extract import slice_objects

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/living'
OUT.mkdir(parents=True, exist_ok=True)
manifest = json.loads((ROOT/'assets_manifest.json').read_text())
manifest['resources'] = [r for r in manifest['resources'] if r.get('introduced') != '0.4.0']
STYLES = [
 # id, material, light, shade, roof, roof light, construction, roof pitch
 ('niyazov','#d7c9a4','#fff0cf','#91866f','#244f8a','#4386b9','royal',25),
 ('veyrmark','#a65340','#db9871','#68382e','#27685d','#58a28b','brick',38),
 ('thornsreach','#c2c39a','#f0e0b4','#70694c','#386f3e','#74a356','timber',31),
 ('greyshore','#d6d8bc','#fff2d6','#8a9d9b','#326c96','#74abc0','coastal',22),
 ('harrowfen','#91653a','#d5a869','#4b4433','#b59742','#edcc70','stilt',34),
 ('duncrest','#a8adac','#e3e1ce','#606d74','#3c5065','#7990a0','terrace',16),
 ('ashlands','#6c727a','#a3adaf','#3d4253','#922e38','#d75c40','bastion',13),
 ('sunmarch','#ddb878','#ffe1a0','#a47b50','#b94e35','#f08e4e','arcade',17),
 ('velden','#e1d2a4','#fff0c7','#83734c','#216b63','#56a184','stepped',28),
 ('blackridge','#8e92a0','#cdd3d4','#4a4d65','#463e78','#8776ae','gothic',40),
 ('frostholm','#7a7771','#b6bcb0','#393e4e','#29465f','#5e879c','longhall',37),
 ('marrow_coast','#e5cbb0','#fff0d0','#9d8e84','#a94330','#e77746','loggia',19),
]
KINDS = ['peasant','large_house','townhouse','manor','market','outbuilding','barracks','temple','castle','administration']
PURPOSES = ['Крестьянский двор','Большой жилой дом','Городской дом','Поместье дворянина','Рынок','Хозяйственный двор','Казармы','Храм','Замок','Канцелярия']
CULTURES = ['Аурелианская','Вейрская','Терновая лесная','Грейвская прибрежная','Харроуская болотная','Данвикская горная','Эшборнская военная','Соларийская южная','Вельдская торговая','Блэквудская горная','Фростская северная','Мэрроуская морская']
O = '#252e3b'; GOLD='#edc35c'; WOOD='#65452f'; GLASS='#29485d'

def save(im, ident, purpose, typ='buildings', style='', culture='', animation=None):
 path=OUT/(ident+'.png');im.save(path,optimize=True)
 entry=dict(id=ident,path=str(path.relative_to(ROOT)),size=list(im.size),type=typ,purpose=purpose,
            introduced='0.4.0',revision='0.4.0',dynastic_style=style,regional_culture=culture,
            used_by='SettlementSystem slots / construction / architecture catalogue' if typ=='buildings' else 'LivingWorld agents / army roles / character catalogue')
 if animation:entry['animation']=animation
 manifest['resources'].append(entry)

def architecture(si, kind, project=False):
 name,wall,light,shade,roof,rhi,form,pitch=STYLES[si]
 im=Image.new('RGBA',(160,176));d=ImageDraw.Draw(im)
 # Dimensions express the building's function, independently of its material.
 w,h,depth={'peasant':(64,35,22),'large_house':(89,47,27),'townhouse':(55,73,27),
 'manor':(96,62,31),'market':(105,33,30),'outbuilding':(77,39,24),
 'barracks':(102,53,29),'temple':(65,75,34),'castle':(95,69,34),'administration':(88,63,30)}[kind]
 if form=='longhall':w+=12;h-=10
 if form=='stilt':h-=7
 if form=='gothic':w-=7;h+=8
 if form=='terrace':depth+=9
 if form=='arcade':w+=8;h-=6
 x=80-w//2;y=149;top=y-h;right=x+w
 d.ellipse((x-9,y-8,right+depth//2+8,y+12),fill=(18,32,38,65))
 def line(points,c,width=1):d.line(points,fill=c,width=width)
 def window(wx,wy,ww=7,hh=11,arch=True):
  d.rectangle((wx-1,wy-1,wx+ww,wy+hh),fill=shade,outline=O)
  if arch:
   d.pieslice((wx,wy-ww//2,wx+ww-1,wy+ww//2),180,360,fill=GLASS)
  d.rectangle((wx,wy+1,wx+ww-1,wy+hh-1),fill=GLASS)
  line([(wx+1,wy+2),(wx+1,wy+hh-2)],'#79bac5')
  line([(wx+ww//2,wy),(wx+ww//2,wy+hh-1)],light)
  line([(wx-2,wy+hh+1),(wx+ww+2,wy+hh+1)],light,2)
 def roof_module(rx,ry,rw,rd,rp):
  if form in ('arcade','loggia') and kind in ('temple','administration','manor'):
   d.pieslice((rx+rw//2-rw//3,ry-rp-7,rx+rw//2+rw//3,ry+7),180,360,fill=roof,outline=O,width=1)
   for k in range(-2,3):line([(rx+rw//2+k*3,ry-rp),(rx+rw//2+k*7,ry)],rhi)
   d.rectangle((rx-3,ry-3,rx+rw+2,ry+2),fill=roof,outline=O)
  else:
   peak=rx+rw//2 if form!='coastal' else rx+rw//3
   pts=[(rx-5,ry),(peak-2,ry-rp),(rx+rw+4,ry),(rx+rw+rd//2+4,ry-rd//2),(peak+rd//2,ry-rp-rd//2),(peak-2,ry-rp)]
   d.polygon(pts,fill=roof,outline=O)
   d.polygon([(rx-5,ry),(peak-2,ry-rp),(rx+rw+4,ry)],fill=rhi,outline=O)
   for t in range(4,rp,4):
    ratio=t/rp;l=round((rx-5)*(1-ratio)+(peak-2)*ratio);r=round((rx+rw+4)*(1-ratio)+(peak-2)*ratio)
    line([(l,ry-t),(r,ry-t)],roof)
    for tile in range(l+2,r,9):line([(tile,ry-t),(tile+2,ry-t+2)],roof)
   line([(rx-5,ry+1),(rx+rw+4,ry+1)],O,2)
   if form=='longhall':
    for xx in (rx-5,rx+rw+4):line([(xx,ry),(xx-4,ry-5),(xx-2,ry-8)],GOLD,2)
   if form=='stepped':
    for t in range(0,rp,5):
     span=round(rw/2*(1-t/rp));d.rectangle((peak-span-2,ry-t-4,peak-span+1,ry-t),fill=light,outline=WOOD)
   if form=='royal':line([(peak-2,ry-rp),(peak-2,ry-rp-8)],GOLD,2)
   if form=='stilt':
    for xx in range(rx-2,rx+rw+2,4):line([(xx,ry-1),(xx+2,ry+4)],'#eacb72')
   if form=='longhall':line([(peak-3,ry-rp),(rx+rw+1,ry-2)],'#dce8df',2)
 # Raised foundations, boards and front steps; no procedural noise.
 if form=='stilt':
  for xx in range(x+3,right,15):d.rectangle((xx,y-8,xx+4,y+9),fill=WOOD,outline=O)
  y-=8;top-=8
 d.polygon([(x,top),(right,top),(right, y),(x,y)],fill=wall,outline=O)
 d.polygon([(right,top),(right+depth//2,top-depth//2),(right+depth//2,y-depth//2),(right,y)],fill=shade,outline=O)
 # Ordered masonry follows courses; timber frames use actual structural bays.
 if form in ('timber','stepped','longhall','stilt'):
  for xx in range(x+2,right,19):
   line([(xx,top),(xx,y)],WOOD,3)
   if xx+17<right:line([(xx,top+5),(xx+17,min(y-4,top+27))],WOOD,2)
  for yy in range(top+2,y,23):line([(x,yy),(right,yy)],WOOD,3)
  if form in ('longhall','stilt'):
   for yy in range(top+3,y,5):line([(x+2,yy),(right-1,yy)],shade)
 else:
  course=5 if form=='brick' else 8 if form=='bastion' else 7
  for row,yy in enumerate(range(top+4,y-2,course)):
   line([(x+1,yy),(right-1,yy)],shade)
   for xx in range(x+2+(row%2)*7,right-2,14):line([(xx,yy-course+2),(xx,yy-1)],shade)
  line([(x+1,top+1),(x+1,y-1)],light,2)
 for yy in range(top+12,y-14,23):
  for xx in range(x+9,right-6,20):window(xx,yy,6,10,form not in ('bastion','longhall','stilt'))
 dx=80 if kind!='market' else x+8
 if form in ('arcade','loggia','coastal'):
  for xx in range(x+8,right-6,17):
   d.rounded_rectangle((xx,y-22,xx+11,y-2),radius=5,fill=shade,outline=light,width=2)
 d.rounded_rectangle((dx-7,y-24,dx+8,y-1),radius=7 if form!='bastion' else 2,fill=WOOD,outline=light,width=2)
 line([(dx,y-20),(dx,y-2)],O);d.rectangle((dx+3,y-12,dx+4,y-10),fill=GOLD)
 for k in range(3):d.rectangle((dx-10-k,y+k,dx+10+k,y+k+1),fill=light,outline=shade)
 roof_module(x,top,w,depth,pitch)
 if kind not in ('market','outbuilding'):
  chimney=x+w-15;d.rectangle((chimney,top-pitch-2,chimney+7,top-5),fill=shade,outline=O);d.rectangle((chimney-2,top-pitch-4,chimney+8,top-pitch),fill=light,outline=O)
 if kind in ('castle','barracks','temple','administration','manor'):
  towers=2 if kind=='castle' else 1 if kind in ('temple','administration') else 0
  for i in range(towers):
   tx=x-7 if i==0 else right-12;ty=top-15 if form!='bastion' else top-3;tw=21
   d.rectangle((tx,ty,tx+tw,y+1),fill=wall,outline=O);d.rectangle((tx+tw-5,ty,tx+tw,y+1),fill=shade,outline=O)
   for yy in range(ty+9,y-8,19):window(tx+6,yy,6,10)
   if form in ('bastion','terrace'):
    d.rectangle((tx-3,ty-4,tx+tw+3,ty+3),fill=light,outline=O)
    for xx in range(tx-3,tx+tw+2,7):d.rectangle((xx,ty-9,xx+4,ty-2),fill=wall,outline=O)
   else:roof_module(tx-1,ty,tw+2,7,pitch if kind=='temple' else pitch-4)
 if kind=='market':
  for xx in range(x+7,right-4,31):
   d.polygon([(xx-7,y-29),(xx+11,y-35),(xx+22,y-22),(xx-8,y-17)],fill=rhi,outline=O)
   for stripe in range(0,25,8):line([(xx-5+stripe,y-26),(xx-4+stripe,y-18)],light,3)
   for leg in (xx-6,xx+20):line([(leg,y-19),(leg,y+6)],WOOD,2)
   d.rectangle((xx-6,y-3,xx+19,y+2),fill='#ad7b46',outline=O)
   for j,c in enumerate(('#de9b46','#a5b953','#c45a3e')):d.ellipse((xx-3+j*6,y-8,xx+2+j*6,y-3),fill=c,outline=WOOD)
 if kind=='outbuilding':
  d.rectangle((x+5,y-14,x+25,y-2),fill=WOOD,outline=O)
  for xx in range(x+7,x+25,4):line([(xx,y-12),(xx,y-4)],'#b38c57')
  for xx in (right-8,right+4):d.ellipse((xx-5,y-10,xx+5,y+3),fill='#a77945',outline=O);line([(xx-5,y-4),(xx+5,y-4)],shade)
 if kind in ('administration','manor','castle','barracks'):
  pole=right+depth//2;line([(pole,top+6),(pole,top-20)],WOOD,2)
  d.polygon([(pole,top-20),(pole+14,top-18),(pole+10,top-11),(pole,top-13)],fill=roof,outline=GOLD if si==0 else light)
 if kind=='temple':
  line([(80,top-pitch-2),(80,top-pitch-16)],GOLD,2);line([(75,top-pitch-11),(85,top-pitch-11)],GOLD,2)
 if project:
  # Project-only annexes, gardens, carved pediments and different footprints.
  d.rectangle((15,143,145,151),fill=shade,outline=O)
  for xx in range(22,144,12):d.rectangle((xx,141,xx+6,145),fill=GOLD if kind=='administration' else light,outline=O)
  if kind in ('temple','manor'):d.ellipse((26,145,37,157),fill='#478b4c',outline=O);d.ellipse((126,145,138,158),fill='#478b4c',outline=O)
 return im

town_source=ROOT/'tools/art_sources/towns_v0_4.png'
if not town_source.exists():shutil.copy('/workspace/generated_images/exec-9498bd11-1d15-4e3f-8985-c63a4945c1ee.png',town_source)
# The Duncrest guildhall touches its neighbour. Use the complete mountain
# residence module for this civic plan, rather than slicing a roof in half.
town_paintings=slice_objects(town_source,6,6,{17:slice_objects(ROOT/'tools/art_sources/residences_v0_4.png',4,3)[5]})
def painted_architecture(si,kind,project=False):
 # Three purpose-painted modules per culture, composed into ten functional plans.
 # All pieces are complete buildings with proper perspective, not rectangular noise.
 sources=[town_paintings[si*3+j] for j in range(3)]
 im=Image.new('RGBA',(160,176));d=ImageDraw.Draw(im)
 plans={
 'peasant':[(0,99,80,162)],'large_house':[(0,67,44,146),(1,89,98,164)],
 'townhouse':[(1,115,80,165)],'manor':[(0,64,36,155),(2,112,95,164)],
 'market':[(2,116,79,146)],'outbuilding':[(0,86,60,161)],
 'barracks':[(1,82,42,151),(0,78,113,165)],'temple':[(2,131,80,167)],
 'castle':[(1,76,40,151),(2,112,98,165)],'administration':[(2,140,80,164)]}
 for source,width,x,ground in plans[kind]:
  tile=sources[source].crop(sources[source].getbbox());height=round(tile.height*width/tile.width)
  tile=tile.resize((width,height),Image.Resampling.NEAREST)
  alpha=tile.getchannel('A').point(lambda v:255 if v>=128 else 0)
  tile=tile.convert('RGB').quantize(colors=72,dither=Image.Dither.NONE).convert('RGBA');tile.putalpha(alpha)
  im.alpha_composite(tile,(x-width//2,ground-height))
 d=ImageDraw.Draw(im);style=STYLES[si];wood='#7f5c37';light=style[2];dark=style[3];roof=style[4]
 if kind=='market':
  for x in (30,75,118):
   for leg in (x-16,x+18):d.line([(leg,143),(leg,169)],fill=wood,width=2)
   d.polygon([(x-18,143),(x-6,131),(x+13,132),(x+20,145)],fill=roof,outline=O)
   for off in (0,8,16,24):d.line([(x-13+off,140),(x-10+off,133)],fill=light,width=3)
   d.rectangle((x-16,157,x+18,164),fill='#ad7b46',outline=O)
   for off,c in zip((-10,-2,6),('#ddad47','#a2c363','#c66943')):d.ellipse((x+off,152,x+off+7,157),fill=c,outline=wood)
 if kind=='outbuilding':
  for x in (113,132):
   d.ellipse((x-8,147,x+8,168),fill='#bb8c4b',outline=O);d.line([(x-8,154),(x+8,154)],fill=dark,width=2);d.line([(x-8,163),(x+8,163)],fill=dark,width=2)
  d.rectangle((92,157,110,169),fill=wood,outline=O);d.line([(92,157),(110,169)],fill='#c99d5a',width=2)
 if kind in ('barracks','castle'):
  for x in range(15,145,7):d.rectangle((x,163,x+4,171),fill=style[1] if si not in (2,4,10) else wood,outline=O)
  if kind=='barracks':
   for x in (70,82):d.line([(x,145),(x,171)],fill=wood,width=2);d.polygon([(x-4,146),(x,136),(x+4,146)],fill='#c4d6db',outline=O)
 if kind=='temple':
  d.line([(79,54),(79,34)],fill=GOLD,width=2);d.line([(73,41),(85,41)],fill=GOLD,width=2)
 if kind=='large_house':
  for x in range(18,62,9):d.rectangle((x,159,x+7,165),fill='#51864e',outline=O)
 if kind=='manor' or project:
  for x in (15,140):d.ellipse((x-9,150,x+9,170),fill='#3b8655',outline=O);d.ellipse((x-6,148,x+5,160),fill='#74b35f')
 if project:
  d.rectangle((26,166,133,171),fill=light,outline=dark)
  for x in range(30,132,13):d.rectangle((x,163,x+7,167),fill=GOLD,outline=O)
 return im

world=json.loads((ROOT/'data/world.json').read_text())
styles=[]
for i,style in enumerate(STYLES):
 sid=style[0];r=world['realms'][i]
 styles.append(dict(id=sid,realm=i,dynasty=r['dynasty'],culture=CULTURES[i],construction=style[6],residence='lk_'+sid+'_residence',types={k:'lk_'+sid+'_'+k for k in KINDS}))
 for kind,purpose in zip(KINDS,PURPOSES):save(painted_architecture(i,kind),'lk_'+sid+'_'+kind,purpose,style=sid,culture=CULTURES[i])

src=ROOT/'tools/art_sources/residences_v0_4.png'
if not src.exists():
 shutil.copy('/workspace/generated_images/exec-7453ed26-114e-4f99-862f-98a9cd0636df.png',src)
for i,tile in enumerate(slice_objects(src,4,3)):
 tile=tile.crop(tile.getbbox());tile.thumbnail((184,186),Image.Resampling.NEAREST)
 # Pixel-scale quantisation retains architecture and grouped material shading.
 alpha=tile.getchannel('A').point(lambda v:255 if v>=128 else 0)
 tile=tile.convert('RGB').quantize(colors=80,dither=Image.Dither.NONE).convert('RGBA');tile.putalpha(alpha)
 im=Image.new('RGBA',(192,192));im.alpha_composite(tile,((192-tile.width)//2,190-tile.height))
 save(im,'lk_'+STYLES[i][0]+'_residence','Дворец Ниязовых — Niyazov Royal Palace' if i==0 else 'Резиденция дома '+styles[i]['dynasty'],style=STYLES[i][0],culture=CULTURES[i])
PROJECTS=[('command_academy','Академия полководцев',6,'barracks'),('royal_archive','Королевский архив',0,'administration'),('great_market','Великий рынок',8,'market'),('dynastic_tomb','Династическая усыпальница',9,'temple'),('embassy_court','Посольский двор',3,'manor'),('royal_shipyard','Королевская верфь',11,'outbuilding'),('great_library','Великая библиотека',7,'administration'),('royal_gardens','Королевские сады',2,'manor')]
for ident,title,si,kind in PROJECTS:
 im=painted_architecture(si,kind,True)
 if ident=='royal_shipyard':
  d=ImageDraw.Draw(im);d.line([(17,151),(17,78),(45,78),(54,96)],fill=WOOD,width=4);d.line([(40,78),(40,126)],fill=GOLD,width=1);d.polygon([(26,148),(43,153),(63,145),(75,137),(35,137)],fill='#b98042',outline=O)
 save(im,'lk_'+ident,title,style=STYLES[si][0],culture=CULTURES[si])

# 32 independently costumed rigs, 24 poses and four genuinely drawn directions.
ROLES=['peasant','peasant_woman','farmer','lumberjack','miner','blacksmith','merchant','traveller','courier','tax_collector','priest','monk','guard','patrol','bandit','infantry','spearman','archer','crossbowman','knight','cavalry','officer','general','noble','noblewoman','king','queen','prince','princess','agent','engineer','diplomat']
ROLE_NAMES=['Крестьянин','Крестьянка','Фермер','Лесоруб','Шахтёр','Кузнец','Торговец','Путешественник','Курьер','Сборщик налогов','Священник','Монах','Стражник','Патрульный','Разбойник','Пехотинец','Копейщик','Лучник','Арбалетчик','Рыцарь','Кавалерист','Офицер','Полководец','Дворянин','Дворянка','Король','Королева','Принц','Принцесса','Тайный агент','Военный инженер','Дипломат']
COMBAT=set(ROLES[12:23]+['agent','engineer'])
RAMPS=[('#304656','#527f8a','#92bec0'),('#655136','#a27b48','#e1b977'),('#334f37','#649658','#a1c576'),('#5d3141','#a85155','#e59174'),('#343d67','#506daa','#9ab5e0'),('#443d51','#817388','#c6b7bb')]
def actor(role,idx,direction,frame):
 im=Image.new('RGBA',(48,64));d=ImageDraw.Draw(im)
 walking=2<=frame<10;working=14<=frame<18;attacking=18<=frame<22;interacting=10<=frame<14;hurt=frame>=22
 phase=(frame-2)*math.tau/8 if walking else 0;stride=round(math.sin(phase)*4);lift=round(max(0,math.cos(phase))*2) if walking else 0
 side=direction in (1,2);face=-1 if direction==1 else 1
 bob=round(abs(math.sin(phase))*1) if walking else frame%2 if frame<2 else 0
 cx=23+(-2 if hurt else 0);cy=29-bob
 dark,cloth,hi=RAMPS[idx%len(RAMPS)];skin='#dba777';skinhi='#f5d6ac';skinshade='#9d634b';metal='#8fa7b5';mhi='#dce7dc';ink='#202b38'
 if role in ('king','queen','prince','princess','courier','guard','diplomat'):dark,cloth,hi=RAMPS[4]
 if role in ('monk','lumberjack'):dark,cloth,hi=RAMPS[1]
 if role=='agent':dark,cloth,hi=('#202e3d','#3d5363','#738a91')
 battle=role in COMBAT;female=role in ('peasant_woman','noblewoman','queen','princess');royal=role in ('king','queen','prince','princess');mounted=role=='cavalry'
 def line(points,c,width=1):d.line(points,fill=c,width=width)
 def poly(points,c):d.polygon(points,fill=c,outline=ink)
 d.ellipse((11,55,39,61),fill=(18,27,37,65))
 if mounted:
  cy-=9
  poly([(4,40),(9,31),(31,31),(35,23),(40,23),(44,33),(39,38),(34,46),(11,46)],'#a87b4c')
  line([(4,39),(2,49)],'#533b31',3)
  for k,x in enumerate((11,17,31,36)):
   end=x+(stride if k%2 else -stride);line([(x,44),(end,56-(lift if k%2 else 0))],'#583f35',3);line([(end-1,57),(end+2,57)],metal,2)
  line([(35,26),(32,39)],ink,2);d.rectangle((16,35,30,42),fill=cloth,outline=GOLD)
 if royal or battle or role in ('traveller','courier','noble','noblewoman','diplomat'):
  sway=round(math.sin(phase-1)*2) if walking else frame%2
  poly([(cx-7,cy-3),(cx+7,cy-3),(cx+10+sway,cy+21),(cx+1,cy+24),(cx-11+sway,cy+21)],dark)
  line([(cx-7,cy),(cx-9+sway,cy+20)],hi);line([(cx+4,cy+3),(cx+7+sway,cy+21)],cloth,2)
 # Bent knees and alternate foot lift; side views narrow the torso.
 for k,x in enumerate((cx-4,cx+4)):
  step=stride*(1 if k==0 else -1);knee=(x+step//2,cy+18);foot=(x+step,cy+26-(lift if k==0 else 2-lift) if walking else cy+26)
  line([(x,cy+11),knee,foot],ink,5);line([(x-1,cy+12),(knee[0]-1,knee[1]),(foot[0]-1,foot[1]-1)],metal if battle else cloth,2)
  d.rectangle((foot[0]-2,foot[1]-1,foot[0]+3,foot[1]+2),fill='#48332c',outline=ink);line([(foot[0]-2,foot[1]-1),(foot[0]+2,foot[1]-1)],'#9c7653')
 bw=5 if side else 8
 poly([(cx-bw,cy-3),(cx+bw,cy-3),(cx+bw+1,cy+13),(cx,cy+16),(cx-bw-1,cy+13)],metal if battle and role not in ('archer','bandit','agent') else cloth)
 line([(cx-bw+1,cy),(cx-bw+1,cy+11)],mhi if battle else hi,2);line([(cx+3,cy),(cx+4,cy+11)],dark,2)
 if battle:
  for yy in (cy+1,cy+5,cy+9):
   for xx in range(cx-bw+3,cx+bw-1,4):line([(xx,yy),(xx+1,yy+1)],mhi)
 if female or role in ('priest','monk'):
  poly([(cx-7,cy+7),(cx+7,cy+7),(cx+10+stride//2,cy+24),(cx-10,cy+24)],cloth)
  for offset in (-6,0,5):line([(cx+offset//2,cy+10),(cx+offset,cy+22)],hi if offset<0 else dark)
 d.rectangle((cx-bw,cy+9,cx+bw,cy+11),fill='#614332',outline=ink);d.rectangle((cx-1,cy+9,cx+2,cy+11),fill=GOLD)
 if role in ('blacksmith','farmer','engineer'):poly([(cx-5,cy+2),(cx+5,cy+2),(cx+6,cy+18),(cx-5,cy+18)],'#9e784e');line([(cx-3,cy+4),(cx-3,cy+15)],'#d6b582')
 # Different head shapes/profile, with eyebrows, nose, lip and directional hair.
 hx=cx+(face if side else 0);hy=cy-15
 poly([(hx-5,hy-2),(hx+4,hy-3),(hx+6,hy+1),(hx+5,hy+8),(hx,hy+11),(hx-5,hy+7),(hx-6,hy+2)],skin)
 poly([(hx+3,hy),(hx+6,hy+1),(hx+5,hy+8),(hx,hy+11),(hx+1,hy+5)],skinshade)
 hair=['#4d342c','#a87541','#453c38','#c5a672'][idx%4]
 poly([(hx-6,hy+3),(hx-6,hy-2),(hx-2,hy-5),(hx+3,hy-4),(hx+6,hy),(hx+2,hy-1),(hx-3,hy+1)],hair)
 if female:line([(hx-6,hy),(hx-7,hy+12),(hx-4,hy+15)],hair,3)
 if direction==3:
  d.rounded_rectangle((hx-5,hy-2,hx+5,hy+8),radius=3,fill=hair);line([(hx-3,hy),(hx-3,hy+5)],hi)
 else:
  for offset in ((face*3,) if side else (-3,3)):
   line([(hx+offset-1,hy+3),(hx+offset+1,hy+3)],hair);d.point((hx+offset,hy+4),fill=ink)
  nose=hx+face*6 if side else hx;line([(nose,hy+4),(nose,hy+7)],skinhi);line([(hx-1,hy+9),(hx+2,hy+9)],'#774a43')
 if battle and role not in ('bandit','archer','agent'):
  poly([(hx-6,hy),(hx-6,hy-4),(hx-1,hy-7),(hx+4,hy-5),(hx+7,hy),(hx+5,hy+1)],metal)
  line([(hx-5,hy-3),(hx-1,hy-6),(hx+2,hy-4)],mhi,2);line([(hx-6,hy+1),(hx+6,hy+1)],ink)
  if role in ('knight','general'):line([(hx,hy-6),(hx,hy+7)],mhi,2)
 elif royal:
  poly([(hx-6,hy-1),(hx-7,hy-7),(hx-3,hy-4),(hx,hy-9),(hx+3,hy-4),(hx+7,hy-7),(hx+6,hy-1)],GOLD);d.point((hx,hy-4),fill='#bb3843')
 elif role in ('priest','monk'):
  poly([(hx-7,hy+2),(hx-6,hy-5),(hx,hy-11),(hx+6,hy-5),(hx+7,hy+2),(hx+3,hy-2),(hx-3,hy-2)],hi if role=='priest' else dark)
 elif role in ('merchant','diplomat','noble'):
  d.ellipse((hx-8,hy-6,hx+8,hy-1),fill=cloth,outline=ink);line([(hx+3,hy-5),(hx+6,hy-11)],GOLD,2)
 elif role in ('farmer','peasant','peasant_woman','lumberjack','miner','engineer'):
  d.ellipse((hx-8,hy-3,hx+8,hy+1),fill='#cfaa67',outline=ink);d.rectangle((hx-5,hy-6,hx+4,hy-2),fill='#b68a4b',outline=ink)
  if role=='miner':d.rectangle((hx-2,hy-6,hx+1,hy-3),fill=GOLD)
 # Independently articulated elbows/wrists and actual tool arcs.
 swing=round(math.sin(phase+math.pi)*4) if walking else 0
 far=(cx-10,cy+6-swing);near=(cx+10,cy+6+swing)
 if working or attacking:near=[(cx+9,cy-5),(cx+12,cy-11),(cx+15,cy-3),(cx+15,cy+10)][frame%4]
 if interacting:near=[(cx+10,cy+5),(cx+13,cy+1),(cx+14,cy-1),(cx+12,cy+3)][frame%4]
 if hurt:near=(cx+9,cy-1);far=(cx-9,cy+11)
 for start,end in [((cx-7,cy-1),far),((cx+7,cy-1),near)]:
  elbow=((start[0]+end[0])//2,start[1]+5)
  line([start,elbow,end],ink,5);line([start,elbow,end],metal if battle else cloth,3);d.rectangle((end[0]-1,end[1]-1,end[0]+1,end[1]+2),fill=skin);d.point((end[0]-1,end[1]-1),fill=skinhi)
 x,y=near
 if role in ('spearman','guard','patrol','farmer'):
  line([(x,y+11),(x-1,y-23)],WOOD,2)
  if role=='farmer':
   for off in (-3,0,3):line([(x-1,y-20),(x+off,y-26)],metal)
  else:poly([(x-4,y-22),(x-1,y-30),(x+2,y-22)],mhi)
 elif role in ('lumberjack','miner','blacksmith','engineer'):
  tip=(x-8,y-14) if not working else [(x-10,y-9),(x-7,y-18),(x+2,y-14),(x+6,y-1)][frame%4]
  line([(x,y),tip],WOOD,2)
  if role=='miner':line([(tip[0]-5,tip[1]),(tip[0],tip[1]-4),(tip[0]+6,tip[1])],metal,2)
  else:poly([(tip[0]-4,tip[1]-5),(tip[0]+3,tip[1]-3),(tip[0]+4,tip[1]+2),(tip[0]-3,tip[1]+1)],metal);line([(tip[0]-4,tip[1]-4),(tip[0]-3,tip[1]+1)],mhi)
 elif role in ('archer','crossbowman'):
  d.arc((x-3,y-13,x+7,y+12),270,90,fill='#b98b51',width=2);line([(x+2,y-12),(x-(4 if attacking else 1),y),(x+2,y+11)],mhi)
  if role=='crossbowman':line([(x-5,y+4),(x+9,y-5)],WOOD,3)
 elif battle:
  tip=(x+1,y-18) if not attacking else [(x-8,y-13),(x-2,y-22),(x+13,y-9),(x+15,y+1)][frame%4]
  line([(x,y),tip],ink,4);line([(x,y),tip],mhi,2);line([(x-4,y-1),(x+4,y+1)],GOLD,2)
  sx,sy=far;poly([(sx-4,sy-5),(sx+4,sy-5),(sx+4,sy+5),(sx,sy+10),(sx-4,sy+5)],cloth);line([(sx,sy-3),(sx,sy+6)],GOLD)
 elif role in ('courier','tax_collector','diplomat'):
  d.rectangle((x-4,y-4,x+5,y+3),fill='#e6d7ae',outline=WOOD);line([(x-3,y-2),(x+3,y-2)],'#a29477');d.rectangle((x,y,x+2,y+2),fill='#b44149')
 elif role in ('priest','monk'):line([(x,y+15),(x,y-17)],GOLD,2);line([(x-4,y-12),(x+4,y-12)],GOLD,2)
 elif role in ('merchant','traveller','peasant'):
  d.ellipse((x-4,y-2,x+5,y+8),fill='#b68c51',outline=ink);line([(x-2,y-3),(x+3,y-3)],GOLD)
 elif female:poly([(x-4,y-1),(x-6,y-7),(x+2,y-10),(x+7,y-4)],hi)
 if role=='tax_collector':d.rectangle((cx-10,cy+10,cx-5,cy+17),fill=WOOD,outline=GOLD)
 if royal or role in ('officer','diplomat'):line([(cx-5,cy),(cx+5,cy+7)],GOLD,2);d.point((cx,cy+4),fill='#f8df8f')
 if role=='agent':line([(hx-5,hy+7),(hx+5,hy+7)],dark,3)
 return im

for idx,role in enumerate(ROLES):
 sheet=Image.new('RGBA',(48*24,64*4))
 for direction in range(4):
  for frame in range(24):sheet.alpha_composite(actor(role,idx,direction,frame),(frame*48,direction*64))
 anim=dict(frame_width=48,frame_height=64,columns=24,rows=4,directions=['down','left','right','up'],idle=[0,1],walk=list(range(2,10)),interact=list(range(10,14)),work=list(range(14,18)),attack=list(range(18,22)) if role in COMBAT else [],hurt=[22,23] if role in COMBAT else [],fps=8,combat=role in COMBAT)
 save(sheet,'lk_actor_'+role,ROLE_NAMES[idx],'characters',animation=anim)

(ROOT/'data/architecture.json').write_text(json.dumps(dict(styles=styles,types=KINDS,projects=[x[0] for x in PROJECTS],rosehill_inherits='niyazov'),ensure_ascii=False,indent=2))
(ROOT/'data/living_characters.json').write_text(json.dumps([dict(id='lk_actor_'+role,role=role,name=ROLE_NAMES[i]) for i,role in enumerate(ROLES)],ensure_ascii=False,indent=2))
manifest['art_version']='0.4.0';manifest['sources']=list(dict.fromkeys(manifest.get('sources',[])+['tools/art_sources/residences_v0_4.png','tools/art_sources/towns_v0_4.png']))
(ROOT/'assets_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
# Compact reviewable catalogues, not counted as game assets.
font=ImageFont.truetype(str(ROOT/'assets/fonts/DejaVuSans.ttf'),13)
sheet=Image.new('RGB',(12*160,11*196),'#203d48');d=ImageDraw.Draw(sheet)
for si,style in enumerate(STYLES):
 for ki,kind in enumerate(KINDS+['residence']):
  ident='lk_'+style[0]+'_'+kind;tile=Image.open(OUT/(ident+'.png'));tile.thumbnail((154,174))
  x=si*160+(160-tile.width)//2;y=ki*196
  sheet.paste(tile,(x,y),tile);d.text((si*160+3,y+175),style[0]+' / '+kind,font=font,fill='#edce8b')
sheet.save(ROOT/'docs/architecture_catalogue_0.4.0.png')
sheet=Image.new('RGB',(8*144,4*164),'#203d48');d=ImageDraw.Draw(sheet)
for i,role in enumerate(ROLES):
 tile=Image.open(OUT/('lk_actor_'+role+'.png')).crop((0,0,48,64)).resize((96,128),Image.Resampling.NEAREST)
 x=(i%8)*144;y=(i//8)*164;sheet.paste(tile,(x+24,y),tile);d.text((x+4,y+134),role,font=font,fill='#edce8b')
sheet.save(ROOT/'docs/character_catalogue_0.4.0.png')
print('Living art: 120 architectural modules + 12 residences + 8 projects; 32 articulated sheets, 3072 frames.')
