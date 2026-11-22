"""Render layout QA from the actual Lua UI frame tree, with simulated geography.
This is a schematic preview, NOT a screenshot from WoW. No game art is bundled.
"""
from pathlib import Path
import re
import math
import sys
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from test_addon import runtime

def render(rt,root,path,title):
    frames=rt.globals().frames
    # Stable object IDs avoid Python Lua-proxy identity differences.
    rt.execute('for i,f in ipairs(frames)do f.serial=i end')
    rid=root.serial
    scale=1.5
    rx,ry,rw,rh=root.GetBounds(root);root_scale=root.GetEffectiveScale(root)
    w,h=int(rw/root_scale),int(rh/root_scale)
    image=Image.new('RGB',(int((w+40)*scale),int((h+86)*scale)),(13,20,26));draw=ImageDraw.Draw(image)
    font_path='C:/Windows/Fonts/segoeui.ttf'
    def font(size):return ImageFont.truetype(font_path,int(size*scale))
    draw.text((20*scale,10*scale),title,font=font(13),fill=(140,164,175))
    draw.text((20*scale,31*scale),'Layout preview · simulated distances · not an in-game screenshot',font=font(11),fill=(110,132,145))
    def bounds(f):
        fx,fy,fw,fh=f.GetBounds(f)
        return 20+(fx-rx)/root_scale,64+(fy-ry)/root_scale,fw/root_scale,fh/root_scale
    def belongs(f):
        if f.serial==rid:return True
        return bool(f.parent and belongs(f.parent))
    def visible(f):
        if not f.shown:return False
        return f.serial==rid or (f.parent and visible(f.parent))
    def color(t,default):return tuple(int(max(0,min(1,t[i]))*255) for i in (1,2,3)) if t else default
    clipped=[]
    for _,f in frames.items():
        if not belongs(f) or not visible(f):continue
        x,y,fw,fh=bounds(f);box=(int(x*scale),int(y*scale),int((x+fw)*scale),int((y+fh)*scale))
        if f.color:
            if f.kind=='Texture':
                angle=f.rotation or 0;c,s=math.cos(angle),math.sin(angle)
                cx,cy=(x+fw/2)*scale,(y+fh/2)*scale
                points=[(cx+(dx*c-dy*s)*scale,cy+(dx*s+dy*c)*scale) for dx,dy in [(-fw/2,-fh/2),(fw/2,-fh/2),(fw/2,fh/2),(-fw/2,fh/2)]]
                draw.polygon(points,fill=color(f.color,(9,14,18)))
            else:
                draw.rounded_rectangle(box,4*scale,fill=color(f.color,(9,14,18)),outline=color(f.border,(45,64,70)),width=1)
        if f.text and f.kind in ('FontString','EditBox'):
            text=re.sub(r'\|c[0-9a-fA-F]{8}|\|r','',f.text)
            if f.kind=='EditBox':x+=10;y+=6;fw-=20
            size=17 if f.font=='GameFontNormalLarge' else 13 if f.font in ('GameFontNormal','GameFontHighlight') else 11
            size*=f.GetEffectiveScale(f)/root_scale
            ft=font(size);lineh=(size+2)*scale
            lines=[]
            for para in text.split('\n'):
                line=''
                for word in para.split():
                    if line and draw.textlength(line+' '+word,font=ft)>fw*scale:lines.append(line);line=word
                    else:line=(line+' '+word).strip()
                lines.append(line)
            maxlines=max(1,int((fh*scale+2)//lineh))
            if len(lines)>maxlines:clipped.append(text)
            for i,line in enumerate(lines[:maxlines]):
                if i==maxlines-1 and len(lines)>maxlines:
                    while line and draw.textlength(line+'…',font=ft)>fw*scale:line=line[:-1]
                    line+='…'
                xx=x*scale
                if f.justify=='CENTER':xx+=(fw*scale-draw.textlength(line,font=ft))/2
                draw.text((xx,y*scale+i*lineh-2),line,font=ft,fill=color(f.textColor,(218,231,234)))
    path.parent.mkdir(parents=True,exist_ok=True);image.save(path)
    print(path.name,'text overflow candidates:',len(clipped))
    for s in clipped:print(' ',s[:160])

if __name__=='__main__':
    out=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'preview'
    rt=runtime(full=True)
    rt.execute('''
        C_Map.GetMapInfo=function(map)return {name=V.Data.zones[({[1429]=12,[1453]=1519,[1426]=1,[1431]=10,[1436]=40,[1433]=44,[1455]=1537})[map]] or "Other zone"} end
        playerMap=1429;playerX=.43;playerY=.65
        V:SetQuery("Refreshing Spring Water");V.window:Show();V:Select(V.results[1])
    ''')
    render(rt,rt.globals().V.window,out/'window-en.png','VendorScout · standalone search')
    rt.execute('V.db.language="no";V:RefreshUI()')
    render(rt,rt.globals().V.window,out/'window-no.png','VendorScout · norsk grensesnitt')
    rt.execute('V:OpenMapSearch()')
    render(rt,rt.globals().V.mapPanel,out/'map-panel.png','VendorScout · world-map search panel')
    rt.execute('''
        WorldMapFrame:SetBackdropColor(.035,.045,.055,1)
        WorldMapFrame.ScrollContainer:SetBackdropColor(.06,.14,.16,1)
        V:Label(WorldMapFrame.ScrollContainer,"MAP CANVAS / KARTFLATE",14,-16,240,22,"GameFontNormal")
        WorldMapFrame:SetSize(1035,534)
        WorldMapFrame.TitleCanvasSpacerFrame:SetPoint("BOTTOMRIGHT",WorldMapFrame,"TOPRIGHT",-336,-67)
        WorldMapFrame.scripts.OnSizeChanged()
    ''')
    render(rt,rt.globals().UIParent,out/'map-floating-compact.png','VendorScout · movable search window · compact map + quest-log space')
    rt.execute('''
        WorldMapFrame:SetSize(1400,850)
        WorldMapFrame.TitleCanvasSpacerFrame:SetPoint("BOTTOMRIGHT",WorldMapFrame,"TOPRIGHT",-3,-67)
        WorldMapFrame.scripts.OnSizeChanged()
    ''')
    render(rt,rt.globals().UIParent,out/'map-floating-large.png','VendorScout · movable search window · expanded map')
