"""Extract transparent sprites by connected silhouette, not a brittle fixed crop.
The generation grid assigns identity; complete silhouettes may extend into padding.
"""
from PIL import Image

def slice_objects(path,cols,rows):
 im=Image.open(path).convert('RGBA');w,h=im.size;alpha=im.getchannel('A').tobytes();seen=bytearray(w*h);components=[]
 for start,v in enumerate(alpha):
  if v<120 or seen[start]:continue
  seen[start]=1;queue=[start];pts=[];left=right=start%w;top=bottom=start//w
  while queue:
   pos=queue.pop();pts.append(pos);x=pos%w;y=pos//w;left=min(left,x);right=max(right,x);top=min(top,y);bottom=max(bottom,y)
   for yy in range(max(0,y-1),min(h,y+2)):
    for xx in range(max(0,x-1),min(w,x+2)):
     n=yy*w+xx
     if not seen[n] and alpha[n]>=120:seen[n]=1;queue.append(n)
  if len(pts)>=15:components.append({'pts':pts,'box':(left,top,right+1,bottom+1),'size':len(pts)})
 groups=[[] for _ in range(cols*rows)]
 for c in components:
  l,t,rr,b=c['box'];col=min(cols-1,int((l+rr)*.5/w*cols));row=min(rows-1,int((t+b)*.5/h*rows));groups[row*cols+col].append(c)
 out=[]
 for idx,group in enumerate(groups):
  assert group,('No sprite in source cell',path,idx)
  primary=max(group,key=lambda c:c['size']);l,t,rr,b=primary['box'];selected=[primary]
  for c in components:
   if c is primary or not 45<c['size']<primary['size']*.2:continue
   a,bb,cc,dd=c['box'];distance=max(0,l-cc,a-rr,t-dd,bb-b)
   if distance<=12:selected.append(c)
  l=max(0,min(c['box'][0] for c in selected)-2);t=max(0,min(c['box'][1] for c in selected)-2);rr=min(w,max(c['box'][2] for c in selected)+2);b=min(h,max(c['box'][3] for c in selected)+2)
  tile=im.crop((l,t,rr,b));mask=Image.new('L',tile.size);pixels=mask.load()
  for c in selected:
   for pos in c['pts']:pixels[pos%w-l,pos//w-t]=255
  tile.putalpha(mask);out.append(tile)
 return out
