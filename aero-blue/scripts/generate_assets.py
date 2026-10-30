#!/usr/bin/env python3
"""Generate original Aero Blue art. Requires Pillow; no network or stock images.

Examples: python3 scripts/generate_assets.py
          python3 scripts/generate_assets.py --width 3024 --height 1964
The default is a portable 3200 × 2000 master. All geometry is our own.
"""
from __future__ import annotations

import argparse
import io
import json
import math
from pathlib import Path
import random
import struct

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
PALETTE = {"sky": "#A8D8FF", "crystal": "#65C7F7", "aqua": "#48DCE6",
           "ice": "#F4FBFF", "glass": "#CDEEFF", "leaf": "#9AD96B", "ocean": "#2478B8"}
ICONS = [("finder", "Finder"), ("safari", "Safari"), ("mail", "Mail"),
         ("messages", "Messages"), ("music", "Music"), ("photos", "Photos"),
         ("calendar", "Calendar"), ("notes", "Notes"), ("settings", "Settings"),
         ("terminal", "Terminal"), ("vscode", "VS Code"), ("downloads", "Downloads"),
         ("documents", "Documents"), ("projects", "Projects"),
         ("applications", "Applications"), ("trash", "Trash"), ("desktop", "Desktop folders")]
CURSORS = [("pointer", "Normal pointer", (5, 4)), ("text", "Text selection", (16, 16)),
           ("link", "Link hand", (13, 4)), ("busy", "Busy", (16, 16)),
           ("resize-horizontal", "Horizontal resize", (16, 16)),
           ("resize-vertical", "Vertical resize", (16, 16)),
           ("resize-diagonal", "Diagonal resize", (16, 16)),
           ("move", "Move", (16, 16)), ("crosshair", "Crosshair", (16, 16)),
           ("unavailable", "Unavailable", (16, 16))]


def rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def blend(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def font(size, bold=False):
    names = ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else
             "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
             "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else
             "/System/Library/Fonts/Supplemental/Arial.ttf"]
    for name in names:
        if Path(name).exists():
            return ImageFont.truetype(name, size)
    return ImageFont.load_default(size=size)


def gradient(size, stops):
    image = Image.new("RGBA", size)
    d = ImageDraw.Draw(image)
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        for (p, a), (q, b) in zip(stops, stops[1:]):
            if p <= t <= q:
                d.line((0, y, size[0], y), fill=blend(a, b, (t - p) / (q - p)))
                break
    return image


def glow(image, center, radius, color, alpha):
    # Render blurred sunlight at one quarter size for deterministic low memory usage.
    size = (max(1, image.width // 4), max(1, image.height // 4))
    layer = Image.new("RGBA", size)
    d = ImageDraw.Draw(layer)
    x, y, r = center[0] / 4, center[1] / 4, radius / 4
    d.ellipse((x - r, y - r, x + r, y + r), fill=(*color, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(radius / 7))
    image.alpha_composite(layer.resize(image.size, Image.Resampling.BILINEAR))


def clouds(image, dark, seed=4):
    rng = random.Random(seed)
    w, h = image.size
    # Rounded cumulus silhouettes, white lit tops, a very faint blue underside.
    # A small edge blur keeps the lobes puffy rather than producing smoky halos.
    for cx, cy, cw, ch in [(.13, .29, .34, .073), (.73, .18, .29, .075),
                            (.43, .42, .19, .045), (.97, .39, .22, .054)]:
        mask = Image.new("L", image.size)
        d = ImageDraw.Draw(mask)
        x,y=cx*w,cy*h
        d.ellipse((x-cw*w*.48,y-ch*h*.08,x+cw*w*.48,y+ch*h*.29),fill=255)
        for i in range(7):
            t=i/6
            px=x+(t-.5)*cw*w*.75
            py=y-ch*h*.10
            rx=cw*w*rng.uniform(.095,.14)
            ry=ch*h*(.23+.34*math.sin(t*math.pi))*rng.uniform(.84,1.12)
            d.ellipse((px-rx,py-ry,px+rx,py+ry),fill=255)
        mask=mask.filter(ImageFilter.GaussianBlur(w*.0015))
        fill=Image.new("RGBA",image.size)
        fd=ImageDraw.Draw(fill)
        top,bottom=int(y-ch*h*.75),int(y+ch*h*.4)
        for yy in range(max(0,top),min(h,bottom+1)):
            t=max(0,min(1,(yy-top)/max(1,bottom-top)))
            color=blend((185,216,242,55),(117,161,197,32),t) if dark else blend((255,255,255,235),(219,242,253,195),t)
            fd.line((0,yy,w,yy),fill=color)
        alpha=Image.composite(fill.getchannel("A"),Image.new("L",image.size),mask)
        fill.putalpha(alpha)
        image.alpha_composite(fill)


def bubble(image, center, radius, dark=False, sphere=False):
    x, y = center
    r = radius
    layer = Image.new("RGBA", image.size)
    d = ImageDraw.Draw(layer)
    if sphere:
        # The sphere refracts an inverted, enlarged copy of the real scene.
        side = max(2, int(2 * r))
        crop = image.crop((int(x-r), int(y-r), int(x+r), int(y+r)))
        crop = crop.transpose(Image.Transpose.FLIP_TOP_BOTTOM).resize((side, side))
        tint = Image.new("RGBA", crop.size, (134, 231, 249, 42 if not dark else 22))
        crop = Image.alpha_composite(crop, tint)
        mask = Image.new("L", crop.size)
        ImageDraw.Draw(mask).ellipse((1, 1, side-2, side-2), fill=220)
        layer.paste(crop, (int(x-r), int(y-r)), mask)
    else:
        d.ellipse((x-r,y-r,x+r,y+r), fill=(160, 227, 255, 12 if dark else 20))
    width = max(1, round(r * .012))
    d.ellipse((x-r,y-r,x+r,y+r), outline=(213, 247, 255, 160 if dark else 205), width=width)
    d.arc((x-r*.95,y-r*.95,x+r*.95,y+r*.95), 194, 297,
          fill=(250, 255, 255, 200), width=max(1, round(r * .022)))
    d.arc((x-r*.94,y-r*.94,x+r*.94,y+r*.94), 24, 97,
          fill=(102, 228, 245, 145), width=max(1, round(r * .023)))
    if sphere:
        d.arc((x-r*.84,y-r*.84,x+r*.84,y+r*.84), 36, 130,
              fill=(179, 246, 243, 80), width=max(1, round(r*.045)))
        d.arc((x-r*.72,y-r*.95,x+r*.72,y+r*.98), 50, 126,
              fill=(74, 192, 226, 70), width=max(1, round(r*.014)))
    d.ellipse((x-r*.58, y-r*.73, x-r*.18, y-r*.58), fill=(255, 255, 255, 105))
    image.alpha_composite(layer)
    shine = Image.new("RGBA", image.size)
    ImageDraw.Draw(shine).ellipse((x-r*.53,y-r*.74,x-r*.24,y-r*.63), fill=(255,255,255,110))
    image.alpha_composite(shine.filter(ImageFilter.GaussianBlur(max(1,r*.035))))


def hills(image, dark, meadow):
    w, h = image.size
    layers = [(.67, .03, .12, (63, 133, 116, 255) if dark else (129, 206, 148, 255)),
              (.76, .10, 1.2, (24, 85, 82, 255) if dark else (111, 188, 97, 255)),
              (.88, .07, 3.1, (16, 56, 61, 255) if dark else (61, 158, 78, 255))]
    d = ImageDraw.Draw(image)
    for baseline, amplitude, phase, color in layers:
        if not meadow:
            baseline, amplitude = .62, .018
            color = (35,86,90,255) if dark else (125,190,133,255)
        points = [(0, h)] + [(x, h*(baseline + amplitude*math.sin(x/w*4.2+phase)))
                             for x in range(0,w+8,8)] + [(w,h)]
        d.polygon(points, fill=color)
        if not meadow:
            break
    if meadow:
        # Fine, restrained blades appear only in the bottom edge, away from windows.
        rng = random.Random(71)
        for _ in range(1300):
            x = rng.uniform(0,w)
            y = rng.uniform(.90*h, 1.06*h)
            length = rng.uniform(.006,.035)*h
            d.line((x, y, x+rng.uniform(-.006,.006)*w,y-length),
                   fill=(51,100,85,255) if dark else (126,194,101,255), width=max(1,w//1800))


def wallpaper(kind, dark, size):
    w, h = size
    sky = [(0,(5,24,54,255)),(.58,(26,76,108,255)),(1,(45,104,124,255))] if dark else [
        (0,(39,140,219,255)),(.48,(115,199,241,255)),(1,(207,239,246,255))]
    image = gradient(size, sky)
    glow(image,(w*.76,h*.08), w*.16, (133,202,255) if dark else (255,255,237), 100 if dark else 210)
    clouds(image,dark)
    if kind == "aero-sky":
        for cx,cy,r in [(.81,.58,.09),(.87,.36,.035),(.23,.67,.029),(.66,.75,.018)]:
            bubble(image,(cx*w,cy*h),r*h,dark)
    elif kind == "crystal-ocean":
        hills(image,dark,False)
        water_y = int(h*.65)
        water = gradient((w,h-water_y), [(0,(37,108,129,255) if dark else (143,223,225,255)),
                                        (1,(5,40,68,255) if dark else (27,159,197,255))])
        image.alpha_composite(water,(0,water_y))
        # Horizontal caustic reflections from the sky: asymmetric and softly graded.
        sheen = Image.new("RGBA",size)
        sd = ImageDraw.Draw(sheen)
        rng=random.Random(42)
        for i in range(180):
            t = rng.random()
            y = water_y+(h-water_y)*t
            x = rng.uniform(-.1,1.1)*w
            length = rng.uniform(.005,.09)*w*(.3+t)
            sd.line((x,y,x+length,y),fill=(205,249,247,12 if dark else 24),width=max(1,round(1+t*3)))
        for i in range(28):
            t=(i/28)**1.6
            y=water_y+(h-water_y)*t
            phase=rng.uniform(0,math.pi*2)
            points=[(x,y+math.sin(x/w*14+phase)*(1+t*5)) for x in range(-8,w+8,8)]
            sd.line(points,fill=(217,253,247,10 if dark else 34),width=max(1,round((.6+t*2.5)*w/1600)))
        # Pale broad sky reflections, with open water between the glints.
        for cx,cy,rw,rh in [(.24,.71,.17,.012),(.72,.77,.13,.016),(.43,.91,.19,.019)]:
            sd.ellipse(((cx-rw)*w,(cy-rh)*h,(cx+rw)*w,(cy+rh)*h),
                       fill=(225,252,246,10 if dark else 26))
        image.alpha_composite(sheen.filter(ImageFilter.GaussianBlur(.8)))
        glow(image,(w*.71,h*.90),w*.18,(64,207,209),25 if dark else 70)
        shadow = Image.new("RGBA",size)
        ImageDraw.Draw(shadow).ellipse((w*.61,h*.82,w*.84,h*.87),fill=(3,55,87,95))
        image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(w*.013)))
        bubble(image,(w*.725,h*.645),h*.19,dark,True)
        bubble(image,(w*.22,h*.76),h*.026,dark)
    else:
        hills(image,dark,True)
        glow(image,(w*.72,h*.65),w*.22,(190,233,128),20 if dark else 55)
        for cx,cy,r in [(.78,.57,.088),(.88,.43,.035),(.19,.79,.031)]:
            bubble(image,(cx*w,cy*h),r*h,dark,True)
    return image.convert("RGB")


def rounded_box(image, bounds, radius, fill, outline=None, width=1):
    ImageDraw.Draw(image).rounded_rectangle(bounds,radius,fill,outline,width)


def icon_art(kind, size=1024):
    # All icon glyph coordinates live in a 256 point design grid.
    s=size/256
    image=Image.new("RGBA",(size,size))
    mask=Image.new("L",(size,size))
    md=ImageDraw.Draw(mask)
    md.rounded_rectangle((18*s,18*s,238*s,238*s),radius=51*s,fill=255)
    bg=gradient((size,size),[(0,(207,246,255,245)),(.45,(71,191,232,240)),(1,(32,116,183,250))])
    image.paste(bg,(0,0),mask)
    d=ImageDraw.Draw(image)
    def box(b,r,fill,outline=None,width=1):
        d.rounded_rectangle(tuple(v*s for v in b),r*s,fill,outline,max(1,int(width*s)))
    def line(points,fill,width=5):
        d.line([(x*s,y*s) for x,y in points],fill,width=max(1,round(width*s)),joint="curve")
    def ellipse(b,fill,outline=None,width=1):
        d.ellipse(tuple(v*s for v in b),fill,outline,max(1,round(width*s)))
    def poly(points,fill):
        d.polygon([(x*s,y*s) for x,y in points],fill)
    white=(245,253,255,255); navy=(20,83,132,255); pale=(191,238,252,255)
    # Inner glass rim and light cap.
    box((21,21,235,235),49,None,(229,252,255,220),1.6)
    cap=Image.new("RGBA",image.size)
    ImageDraw.Draw(cap).ellipse((5*s,-93*s,251*s,137*s),fill=(255,255,255,70))
    cap.putalpha(Image.composite(cap.getchannel("A"),Image.new("L",image.size),mask))
    image=Image.alpha_composite(image,cap); d=ImageDraw.Draw(image)
    if kind=="aero-blue":
        ellipse((53,53,203,203),(228,251,255,255))
        ellipse((60,60,196,196),(69,190,218,255))
        d.arc((70*s,88*s,186*s,172*s),0,180,fill=(213,251,251,255),width=round(4*s))
        d.arc((90*s,69*s,166*s,187*s),80,280,fill=(166,234,241,255),width=round(3*s))
        d.arc((72*s,73*s,184*s,184*s),196,282,fill=white,width=round(6*s))
        ellipse((92,76,113,87),white)
        ellipse((153,151,178,162),(154,217,107,255))
    elif kind=="finder":
        box((60,59,196,197),25,white)
        poly([(128,60),(126,124),(112,143),(133,143),(134,197),(173,197),(196,175),(196,82),(174,59)],(123,214,241,255))
        line([(93,103),(93,118)],navy,6); line([(163,103),(163,118)],navy,6)
        d.arc((86*s,117*s,170*s,171*s),12,168,fill=navy,width=round(5*s))
    elif kind=="safari":
        ellipse((58,58,198,198),white); ellipse((67,67,189,189),(65,163,208,255))
        for i in range(12):
            a=i*math.pi/6
            line([(128+52*math.cos(a),128+52*math.sin(a)),(128+44*math.cos(a),128+44*math.sin(a))],white,2)
        poly([(154,81),(139,139),(102,175),(117,117)],white)
        poly([(154,81),(139,139),(117,117)],(239,115,107,255))
        ellipse((121,121,135,135),navy)
    elif kind=="mail":
        box((52,78,204,181),15,white)
        line([(56,84),(128,138),(200,84)],(45,146,193,255),5)
        line([(56,173),(100,132)],(112,196,226,255),4); line([(200,173),(156,132)],(112,196,226,255),4)
    elif kind=="messages":
        box((84,101,207,179),23,(153,231,222,255)); poly([(167,171),(192,193),(192,168)],(153,231,222,255))
        box((48,66,178,151),28,white); poly([(67,139),(63,169),(98,145)],white)
        for x in (87,113,139): ellipse((x-5,103,x+5,113),(64,162,207,255))
    elif kind=="music":
        poly([(111,77),(180,60),(180,163),(165,163),(165,89),(126,99),(126,179),(111,179)],white)
        ellipse((78,164,126,194),white); ellipse((132,150,180,180),white)
    elif kind=="photos":
        colors=[(255,180,122,255),(250,221,139,255),(163,220,145,255),(105,220,218,255),
                (128,185,244,255),(181,165,232,255),(237,164,202,255),(247,155,153,255)]
        for i,color in enumerate(colors):
            a=i*math.pi/4
            cx,cy=128+41*math.cos(a),128+41*math.sin(a)
            ellipse((cx-28,cy-28,cx+28,cy+28),color,white,.8)
        ellipse((104,104,152,152),white)
    elif kind=="calendar":
        box((62,62,194,197),19,white); box((62,62,194,101),16,(42,138,191,255))
        d.rectangle((62*s,85*s,194*s,101*s),fill=(42,138,191,255))
        for x in (92,164): line([(x,53),(x,78)],white,8)
        d.text((128*s,141*s),"12",font=font(round(58*s),True),anchor="mm",fill=navy)
    elif kind=="notes":
        box((69,54,187,201),14,white); box((69,54,187,82),11,(170,223,132,255))
        for y in (107,128,149,170):line([(87,y),(170,y)],(91,165,196,255),3)
        line([(92,83),(92,194)],(187,223,232,255),2)
    elif kind=="settings":
        points=[]
        for i in range(48):
            a=i*math.pi/24; r=70 if i%4 in (1,2) else 58
            points.append((128+math.cos(a)*r,128+math.sin(a)*r))
        poly(points,white); ellipse((91,91,165,165),(50,144,187,255)); ellipse((107,107,149,149),pale)
    elif kind=="terminal":
        box((48,71,208,187),18,(17,77,120,255),pale,2)
        box((48,71,208,95),13,(187,233,247,255))
        for x in (63,76,89):ellipse((x,80,x+5,85),(63,147,186,255))
        line([(74,118),(94,135),(74,152)],white,5); line([(113,155),(148,155)],(150,226,178,255),5)
    elif kind=="vscode":
        line([(99,86),(59,128),(99,170)],white,12)
        line([(157,86),(197,128),(157,170)],white,12)
        line([(142,74),(114,182)],(165,239,229,255),10)
    elif kind in ("downloads","documents","projects","applications","desktop"):
        box((46,74,125,111),12,(213,246,255,255));box((46,92,210,191),18,(223,248,255,255))
        box((47,111,209,192),15,(113,210,229,255),(235,255,255,255),2)
        if kind=="downloads":
            line([(128,121),(128,164)],white,8); poly([(110,152),(128,173),(146,152)],white)
        elif kind=="documents":
            box((109,119,149,177),5,white)
            for y in (136,147,158): line([(117,y),(141,y)],(66,155,192,255),2)
        elif kind=="projects":
            line([(112,124),(104,124),(104,140),(96,147),(104,154),(104,170),(112,170)],white,4)
            line([(144,124),(152,124),(152,140),(160,147),(152,154),(152,170),(144,170)],white,4)
        elif kind=="applications":
            for x in (105,133):
                for y in (125,153):box((x,y,x+19,y+19),4,white)
        else:
            box((98,122,158,161),5,white);box((103,127,153,154),2,(57,147,190,255))
            line([(128,161),(128,171)],white,4);line([(112,173),(144,173)],white,4)
    elif kind=="trash":
        poly([(79,94),(177,94),(168,193),(88,193)],white)
        box((74,79,182,94),7,pale);box((106,65,150,81),5,pale)
        for x in (106,128,150):line([(x,112),(x,175)],(82,169,203,255),5)
    return image


def cursor_art(kind):
    # Render at 8 physical pixels per logical point for clean 2x/4x source exports.
    scale=8
    image=Image.new("RGBA",(32*scale,32*scale)); mask=Image.new("L",image.size)
    d=ImageDraw.Draw(mask)
    def poly(points): d.polygon([(x*scale,y*scale) for x,y in points],fill=255)
    def line(points,width=2):d.line([(x*scale,y*scale) for x,y in points],fill=255,width=round(width*scale),joint="curve")
    def ellipse(box,width=None):
        b=tuple(v*scale for v in box)
        d.ellipse(b,fill=255 if width is None else None,outline=255 if width else None,width=round((width or 1)*scale))
    if kind=="pointer":
        poly([(5,4),(5,25),(10.4,20.5),(14.1,28),(18,26),(14.4,18.8),(21,18.8)])
    elif kind=="text":
        line([(16,5),(16,27)],2);line([(10,5),(22,5)],2);line([(10,27),(22,27)],2)
    elif kind=="link":
        # Pointing index at (13, 4), rounded knuckles, thumb swept to the left.
        pts=[(13,4),(15,4),(16,6),(16,13),(18,12),(20,13),(22,13),(24,15),(26,16),(26,22),(23,28),
             (13,28),(10,23),(6,18),(6,16),(8,15),(12,18),(12,6)]
        poly(pts)
    elif kind=="busy":
        ellipse((5,5,27,27),2.5)
        for i in range(8):
            a=i*math.pi/4
            ellipse((16+8*math.cos(a)-1.2,16+8*math.sin(a)-1.2,16+8*math.cos(a)+1.2,16+8*math.sin(a)+1.2))
    elif kind in ("resize-horizontal","resize-vertical","resize-diagonal"):
        poly([(3,16),(10,10),(10,14),(22,14),(22,10),(29,16),(22,22),(22,18),(10,18),(10,22)])
        if kind=="resize-vertical":mask=mask.rotate(90)
        if kind=="resize-diagonal":mask=mask.rotate(-45,Image.Resampling.BICUBIC)
    elif kind=="move":
        poly([(16,2),(21,8),(18,8),(18,14),(24,14),(24,11),(30,16),(24,21),(24,18),(18,18),
              (18,24),(21,24),(16,30),(11,24),(14,24),(14,18),(8,18),(8,21),(2,16),(8,11),
              (8,14),(14,14),(14,8),(11,8)])
    elif kind=="crosshair":
        line([(16,3),(16,13)],1.6);line([(16,19),(16,29)],1.6)
        line([(3,16),(13,16)],1.6);line([(19,16),(29,16)],1.6);ellipse((14.7,14.7,17.3,17.3))
    elif kind=="unavailable":
        ellipse((5,5,27,27),3);line([(9,9),(23,23)],3)
    # Outside dark-blue outline with a bright inner edge. Transparent canvas stays intact.
    outline=mask.filter(ImageFilter.MaxFilter(13))
    edge=mask.filter(ImageFilter.MaxFilter(5))
    image.paste((13,66,105,255),(0,0),outline)
    image.paste((235,253,255,255),(0,0),edge)
    color=gradient(image.size,[(0,(213,253,255,255)),(.35,(110,221,240,255)),(1,(39,147,201,255))])
    image.paste(color,(0,0),mask)
    return image


def save_icns(images, path):
    kinds={16:b"icp4",32:b"icp5",64:b"icp6",128:b"ic07",256:b"ic08",512:b"ic09",1024:b"ic10"}
    chunks=[]
    for size,image in images.items():
        stream=io.BytesIO();image.save(stream,"PNG")
        data=stream.getvalue();chunks.append(kinds[size]+struct.pack(">I",len(data)+8)+data)
    body=b"".join(chunks);path.write_bytes(b"icns"+struct.pack(">I",len(body)+8)+body)


def relative(path):return str(path.relative_to(ROOT))


def generate(width=3200,height=2000):
    manifest={"schemaVersion":1,"palette":PALETTE,"artwork":"Original procedural artwork generated by scripts/generate_assets.py",
              "wallpapers":[],"icons":[],"cursors":[]}
    for name in ("wallpapers","icons","cursors","previews"):(ASSETS/name).mkdir(parents=True,exist_ok=True)
    wall_thumbs=[]
    for kind,title in [("aero-sky","Aero Sky"),("crystal-ocean","Crystal Ocean"),("aero-meadow","Aero Meadow")]:
        for variant in ("light","dark"):
            identity=f"{kind}-{variant}"
            im=wallpaper(kind,variant=="dark",(width,height))
            path=ASSETS/"wallpapers"/f"{identity}.png";im.save(path,optimize=True)
            thumb=im.copy();thumb.thumbnail((640,400))
            preview=ASSETS/"wallpapers"/f"{identity}-preview.jpg";thumb.save(preview,quality=90)
            manifest["wallpapers"].append({"id":identity,"title":title,"variant":variant,"file":relative(path),
                "thumbnail":relative(preview),"width":width,"height":height})
            wall_thumbs.append((thumb.copy(),f"{title} · {variant.title()}"))
    icon_thumbs=[]
    for identity,title in ICONS:
        path=ASSETS/"icons"/identity;path.mkdir(exist_ok=True)
        art=icon_art(identity)
        sizes={size:art.resize((size,size),Image.Resampling.LANCZOS) for size in (16,32,64,128,256,512,1024)}
        for size,im in sizes.items():im.save(path/f"{size}.png",optimize=True)
        icns=path/f"{identity}.icns";save_icns(sizes,icns)
        manifest["icons"].append({"id":identity,"title":title,"file":relative(path/"256.png"),"icns":relative(icns),
                                  "sizes":{str(n):relative(path/f"{n}.png") for n in sizes}})
        icon_thumbs.append((sizes[128],title))
    for identity,title,hotspot in CURSORS:
        path=ASSETS/"cursors"/identity;path.mkdir(exist_ok=True)
        art=cursor_art(identity)
        for size in (64,128):art.resize((size,size),Image.Resampling.LANCZOS).save(path/f"{size}.png",optimize=True)
        manifest["cursors"].append({"id":identity,"title":title,"file":relative(path/"64.png"),
            "retina":relative(path/"128.png"),"hotspot":list(hotspot),"logicalSize":[32,32],
            "sourceHotspot64":[v*2 for v in hotspot],"sourceHotspot128":[v*4 for v in hotspot],
            "sourceHotspot":[v*2 for v in hotspot],"retinaHotspot":[v*4 for v in hotspot],
            "frames":1})
    app_art=icon_art("aero-blue")
    app_sizes={size:app_art.resize((size,size),Image.Resampling.LANCZOS) for size in (16,32,64,128,256,512,1024)}
    app_art.save(ASSETS/"app-icon.png",optimize=True)
    save_icns(app_sizes,ASSETS/"app-icon.icns")
    (ASSETS/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    # Reviewable galleries use a neutral sky background, not app screenshots.
    gallery=Image.new("RGB",(1320,1390),(235,246,252));gd=ImageDraw.Draw(gallery)
    gd.text((30,24),"AERO BLUE / WALLPAPER COLLECTION",font=font(26,True),fill=(29,83,124))
    for i,(im,label) in enumerate(wall_thumbs):
        x=20+(i%2)*650;y=80+(i//2)*430
        im.thumbnail((630,390));gallery.paste(im,(x,y))
        gd.text((x+8,y+397),label,font=font(20),fill=(29,83,124))
    gallery.save(ASSETS/"previews"/"wallpapers.jpg",quality=92)
    gallery=Image.new("RGB",(1100,980),(235,246,252));gd=ImageDraw.Draw(gallery)
    gd.text((30,24),"AERO BLUE CRYSTAL ICONS",font=font(26,True),fill=(29,83,124))
    for i,(im,label) in enumerate(icon_thumbs):
        x=25+(i%5)*215;y=95+(i//5)*215
        gallery.paste(im,(x+34,y),im)
        gd.text((x+98,y+151),label,anchor="mm",font=font(17),fill=(29,83,124))
    gallery.save(ASSETS/"previews"/"icons.jpg",quality=93)
    gallery=Image.new("RGB",(1100,510),(235,246,252));gd=ImageDraw.Draw(gallery)
    gd.text((30,24),"AERO CRYSTAL CURSOR / ARTWORK PREVIEW",font=font(25,True),fill=(29,83,124))
    for i,(identity,title,hotspot) in enumerate(CURSORS):
        x=25+(i%5)*215;y=95+(i//5)*195
        im=Image.open(ASSETS/"cursors"/identity/"128.png")
        gallery.paste(im,(x+34,y),im)
        gd.text((x+98,y+147),title,anchor="mm",font=font(16),fill=(29,83,124))
    gallery.save(ASSETS/"previews"/"cursors.jpg",quality=93)
    return manifest


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--width",type=int,default=3200)
    parser.add_argument("--height",type=int,default=2000)
    args=parser.parse_args()
    if not (640<=args.width<=7680 and 400<=args.height<=4320):parser.error("Use dimensions between 640×400 and 7680×4320")
    manifest=generate(args.width,args.height)
    print(json.dumps({"wallpapers":len(manifest["wallpapers"]),"icons":len(manifest["icons"]),"cursors":len(manifest["cursors"]),
                      "wallpaperSize":[args.width,args.height]}))


if __name__=="__main__":main()
