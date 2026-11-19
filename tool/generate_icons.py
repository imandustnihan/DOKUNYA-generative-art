"""Build original ARTPULSE vector-mark assets; no external artwork."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import math
root=Path(__file__).resolve().parents[1]
size=1024
base=Image.new('RGB',(size,size),'#0b0c12')
mask=Image.new('L',(size,size));d=ImageDraw.Draw(mask)
points=[]
def curve(a,b,c,e):
 for i in range(101):
  t=i/100;u=1-t
  points.append(((u*u*u*a[0]+3*u*u*t*b[0]+3*u*t*t*c[0]+t*t*t*e[0])*size,
                 (u*u*u*a[1]+3*u*u*t*b[1]+3*u*t*t*c[1]+t*t*t*e[1])*size))
# The same curve as lib/app/theme.dart, scaled inside a safe maskable region.
def inset(p): return (.17+.66*p[0],.17+.66*p[1])
curve(*map(inset,[(.18,.72),(.27,-.02),(.67,-.02),(.8,.6)]))
curve(*map(inset,[(.8,.6),(.92,1.03),(.37,.93),(.39,.53)]))
d.line(points,fill=255,width=61,joint='curve')
for x,y in [points[0],points[-1]]:d.ellipse((x-30,y-30,x+30,y+30),fill=255)
grad=Image.new('RGB',(size,size));gp=grad.load()
for y in range(size):
 for x in range(size):
  t=(x+y)/(2*size)
  gp[x,y]=tuple(round(a+(b-a)*t) for a,b in zip((190,135,255),(101,231,245)))
base.paste(grad,(0,0),mask)

def save(path,n):
 path.parent.mkdir(parents=True,exist_ok=True)
 base.resize((n,n),Image.Resampling.LANCZOS).save(path)
for path in (root/'web/icons').glob('*.png'):
 save(path,512 if '512' in path.name else 192)
save(root/'web/favicon.png',32)
for density,n in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
 save(root/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png',n)
for path in (root/'macos/Runner/Assets.xcassets/AppIcon.appiconset').glob('*.png'):
 save(path,int(path.stem.split('_')[-1]))
import json
icons=root/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for icon in json.loads((icons/'Contents.json').read_text())['images']:
 if 'filename' in icon:
  n=round(float(icon['size'].split('x')[0])*float(icon['scale'].replace('x','')))
  save(icons/icon['filename'],n)
base.save(root/'windows/runner/resources/app_icon.ico',sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
base.save(root/'assets/app_icon.png')
banner=Image.new('RGB',(1280,720),'#0b0c12');banner.paste(base.resize((500,500)),(40,110))
bd=ImageDraw.Draw(banner);font=ImageFont.truetype(str(root/'assets/fonts/NotoSans-Bold.ttf'),88)
bd.text((560,275),'ARTPULSE',font=font,fill='#eeedf5')
font=ImageFont.truetype(str(root/'assets/fonts/NotoSans-Regular.ttf'),28)
bd.text((566,390),'GENERATIVE ART STUDIO',font=font,fill='#9494aa')
p=root/'android/app/src/main/res/drawable-nodpi/tv_banner.png';p.parent.mkdir(exist_ok=True)
banner.resize((320,180),Image.Resampling.LANCZOS).save(p)
print('Original icons generated for Android, web, Windows and Apple runners.')
