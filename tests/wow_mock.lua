-- Explicit UI/API simulation. This is NOT a live WoW client.
frames={}; messages={}; currentTime=0; faction="Alliance"; combat=false; playerMap=1429; playerX=.5; playerY=.5
function GetLocale() return "enUS" end
function UnitFactionGroup() return faction end
function GetTime() return currentTime end
function time() return 1795334400 end
function date() return "22.11 09:00" end
function GetBuildInfo() return "1.60.1","70959","Nov 18",16001 end
function IsLoggedIn() return false end
function InCombatLockdown() return combat end
function issecretvalue(x) return x=="SECRET" end
function UnitGUID() return "Creature-0-1-0-0-999001-00001" end
function UnitName() return "Observed merchant" end
function IsShiftKeyDown() return false end
function GetCursorPosition() return 500,400 end
function GetMinimapShape() return "ROUND" end
function CreateVector2D(x,y) return {x=x,y=y,GetXY=function(s)return s.x,s.y end} end
C_Map={}
function C_Map.GetBestMapForUnit() return playerMap end
function C_Map.GetPlayerMapPosition() if not playerX then return nil end; return CreateVector2D(playerX,playerY) end
-- Synthetic geography: maps 1 and 2 share a world; map 3 is another continent.
function C_Map.GetWorldPosFromMapPos(map,pos)
    if map==999 then return nil end
    local c=map==3 and 2 or 1
    return c,CreateVector2D(pos.x*1000+(map==2 and 1000 or 0),pos.y*1000)
end
function C_Map.GetMapPosFromWorldPos(c,pos,map)
    if map==999 then return nil end
    if (map==3 and c~=2) or (map~=3 and c~=1) then return nil end
    return map,CreateVector2D((pos.x-(map==2 and 1000 or 0))/1000,pos.y/1000)
end
function C_Map.GetMapInfo(map) return {name="Test map "..map} end
C_Item={GetItemInfo=function(id) return "Item "..id,"item:"..id end,
    GetItemInfoInstant=function(id)return id,"Misc","Misc","",123,0,5 end}
merchantRows={}
function GetMerchantNumItems() return #merchantRows end
function GetMerchantItemID(index) return merchantRows[index].id end
C_MerchantFrame={GetItemInfo=function(index) return merchantRows[index] end}
function Mixin(target,...)
    for i=1,select('#',...) do for k,v in pairs(select(i,...)) do target[k]=v end end; return target
end
function CreateFromMixins(...) return Mixin({},...) end
TaggableObjectMixin={RemoveAllTags=function() end}
local F={}
function F:SetSize(w,h) self.width=w;self.height=h end
function F:SetWidth(w) self.width=w end
function F:SetHeight(h) self.height=h end
local anchorXY={TOPLEFT={0,0},TOP={.5,0},TOPRIGHT={1,0},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,1},BOTTOM={.5,1},BOTTOMRIGHT={1,1}}
function F:GetBounds()
    if not self.parent then return 0,0,self.width or 100,self.height or 100 end
    local scale=self:GetEffectiveScale()
    local width,height=(self.width or 100)*scale,(self.height or 18)*scale
    local xx,yy={},{}
    for _,p in ipairs(self.points or {})do
        local ref=p[2] or self.parent;local x,y,w,h=ref:GetBounds()
        local a,b=anchorXY[p[1]],anchorXY[p[3]]
        xx[#xx+1]={a[1],x+w*b[1]+p[4]*scale};yy[#yy+1]={a[2],y+h*b[2]-p[5]*scale}
    end
    local function solve(values,size,offset)
        if #values==0 then return offset,size end
        local a=values[1]
        for i=2,#values do local b=values[i];if a[1]~=b[1] then size=(b[2]-a[2])/(b[1]-a[1]);break end end
        return a[2]-size*a[1],size
    end
    local px,py=self.parent:GetBounds()
    local x,w=solve(xx,width,px);local y,h=solve(yy,height,py)
    return x,y,w,h
end
function F:GetWidth() local _,_,w=self:GetBounds();return w/self:GetEffectiveScale() end
function F:GetHeight() local _,_,_,h=self:GetBounds();return h/self:GetEffectiveScale() end
function F:GetLeft() local x=self:GetBounds();return x/self:GetEffectiveScale() end
function F:GetRight() local x,_,w=self:GetBounds();return (x+w)/self:GetEffectiveScale() end
function F:GetTop() local _,y=self:GetBounds();return (UIParent:GetHeight()-y)/self:GetEffectiveScale() end
function F:GetBottom() local _,y,_,h=self:GetBounds();return (UIParent:GetHeight()-y-h)/self:GetEffectiveScale() end
function F:SetMovable(value) self.movable=value end
function F:StartMoving() assert(self.movable);self.moving=true end
function F:StopMovingOrSizing() self.moving=false end
function F:SetScale(v) self.scale=v end
function F:GetScale() return self.scale or 1 end
function F:GetEffectiveScale() return self:GetScale()*(self.parent and self.parent:GetEffectiveScale() or 1) end
function F:SetPoint(point,a,b,c,d)
    if type(a)=="number" then self.point={point,self.parent,point,a,b}
    elseif a==nil then self.point={point,self.parent,point,0,0}
    else self.point={point,a,b,c or 0,d or 0} end
    self.points=self.points or {};local replaced=false
    for i,p in ipairs(self.points)do if p[1]==point then self.points[i]=self.point;replaced=true;break end end
    if not replaced then self.points[#self.points+1]=self.point end
end
function F:GetPoint(i) return unpack((self.points or {})[i or 1] or {"CENTER",self.parent,"CENTER",0,0}) end
function F:GetNumPoints() return #(self.points or {}) end
function F:ClearAllPoints() self.point=nil;self.points={} end
function F:SetAllPoints(other) self.allPoints=other or self.parent end
function F:SetText(t) self.text=t or "";self.cursor=#self.text;self.textWrites=(self.textWrites or 0)+1; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end end
function F:GetText() return self.text or "" end
function F:SetScript(k,v) self.scripts[k]=v end
function F:GetScript(k) return self.scripts[k] end
function F:HookScript(k,v) local old=self.scripts[k]; self.scripts[k]=function(...)if old then old(...) end; v(...)end end
function F:Show() local old=self.shown;self.shown=true;if not old and self.scripts.OnShow then self.scripts.OnShow(self) end end
function F:Hide() local old=self.shown;self.shown=false;if old and self.scripts.OnHide then self.scripts.OnHide(self) end end
function F:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function F:SetShown(v) if v then self:Show() else self:Hide() end end
function F:SetFocus() for _,f in ipairs(frames)do f.focus=false end;self.focus=true end
function F:ClearFocus() self.focus=false end
function F:HasFocus() return self.focus==true end
function F:SetEnabled(v) self.enabled=v end
function F:SetFrameLevel(v) self.level=v end
function F:GetFrameLevel() return self.level or (self.parent and self.parent:GetFrameLevel()+1 or 1) end
function F:SetFrameStrata(s) self.strata=s end
function F:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata() or "MEDIUM") end
function F:EnableMouse(v) self.mouse=v end
function F:EnableKeyboard(v) self.keyboard=v end
function F:RegisterForClicks(...) self.clicks={...} end
function F:Type(text)
    assert(self.keyboard and self.focus,"Keyboard input requires focus and keyboard enabled")
    local cursor=self.cursor or #self:GetText();self.text=self:GetText():sub(1,cursor)..text..self:GetText():sub(cursor+1)
    self.cursor=cursor+#text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,true)end
end
function F:SetBackdropColor(...) self.color={...} end
function F:SetBackdropBorderColor(...) self.border={...} end
function F:SetTextColor(...) self.textColor={...} end
function F:SetTexture(v) self.texture=v end
function F:SetVertexColor(...) self.tint={...} end
function F:SetColorTexture(...) self.color={...} end
function F:SetRotation(value) self.rotation=value end
function F:SetAlpha(a) self.alpha=a end
function F:SetFontObject(name) self.font=name end
function F:SetJustifyH(v) self.justify=v end
function F:SetWordWrap(v) self.wordWrap=v end
function F:GetCenter() return 500,400 end
function F:RegisterEvent(e) self.events[e]=true end
function F:Click() if self.enabled~=false and self.scripts.OnClick then self.scripts.OnClick(self,"LeftButton") end end
local noop={"SetBackdrop","SetJustifyV","SetTextInsets","SetAutoFocus","SetMaxLetters","SetClampedToScreen","RegisterForDrag","AddMaskTexture"}
for _,k in ipairs(noop) do F[k]=function()end end
function CreateFrame(kind,name,parent,template)
    local f=setmetatable({kind=kind,name=name,parent=parent,template=template,shown=true,scripts={},events={},enabled=true},{__index=F})
    frames[#frames+1]=f; if name then _G[name]=f end; return f
end
function F:CreateFontString(name,layer,font) local s=CreateFrame("FontString",name,self);s.font=font;return s end
function F:CreateTexture(name,layer) return CreateFrame("Texture",name,self) end
function F:CreateMaskTexture() return CreateFrame("MaskTexture",nil,self) end
UIParent=CreateFrame("Frame","UIParent");UIParent:SetSize(1920,1080)
Minimap=CreateFrame("Frame","Minimap",UIParent);Minimap:SetSize(140,140)
UISpecialFrames={};SlashCmdList={};ChatEdit_InsertLink=function()end
DEFAULT_CHAT_FRAME={AddMessage=function(_,s)messages[#messages+1]=s end}
GameTooltip={SetOwner=function()end,SetText=function()end,AddLine=function()end,SetHyperlink=function()end,Show=function()end,Hide=function()end}
function hooksecurefunc()end
function ShowUIPanel(frame) frame:Show() end
function HideUIPanel(frame) frame:Hide() end
C_AddOns={LoadAddOn=function()end}
function makeMap()
    WorldMapFrame=CreateFrame("Frame","WorldMapFrame",UIParent);WorldMapFrame:SetSize(1000,700);WorldMapFrame:Hide()
    WorldMapFrame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",100,-100)
    WorldMapFrame:SetFrameStrata("MEDIUM");WorldMapFrame:EnableMouse(true)
    local spacer=CreateFrame("Frame",nil,WorldMapFrame);WorldMapFrame.TitleCanvasSpacerFrame=spacer
    spacer:SetPoint("TOPLEFT",WorldMapFrame,"TOPLEFT",2,0);spacer:SetPoint("BOTTOMRIGHT",WorldMapFrame,"TOPRIGHT",-3,-67)
    local scroll=CreateFrame("Frame",nil,WorldMapFrame);WorldMapFrame.ScrollContainer=scroll;scroll:SetSize(1000,640)
    scroll:SetPoint("TOPLEFT",spacer,"BOTTOMLEFT",0,0);scroll:SetPoint("BOTTOMLEFT",WorldMapFrame,"BOTTOMLEFT",0,2);scroll:SetPoint("RIGHT",spacer,"RIGHT",0,0);scroll:EnableMouse(true)
    local border=CreateFrame("Frame",nil,WorldMapFrame);WorldMapFrame.BorderFrame=border
    border:SetPoint("TOPLEFT",WorldMapFrame,"TOPLEFT",0,0);border:SetPoint("BOTTOMRIGHT",WorldMapFrame,"BOTTOMRIGHT",0,0)
    border:SetFrameStrata("HIGH");border:EnableMouse(true)
    function WorldMapFrame:OnFrameSizeChanged()self.resizeCalls=(self.resizeCalls or 0)+1 end
    WorldMapFrame.mapID=1429;WorldMapFrame.pins={}
    local levels={}
    local manager={AddFrameLevel=function(_,name)levels[name]=true end}
    function WorldMapFrame:GetPinFrameLevelsManager() return manager end
    function WorldMapFrame:AddDataProvider(p)self.provider=p;p:OnAdded(self)end
    function WorldMapFrame:GetMapID()return self.mapID end
    function WorldMapFrame:SetMapID(id)self.mapID=id;if self.provider then self.provider:OnMapChanged()end end
    function WorldMapFrame:RemoveAllPinsByTemplate()
        for _,p in ipairs(self.pins)do p:OnReleased();p:Hide()end;self.pins={}
    end
    function WorldMapFrame:AcquirePin(template,...)
        local p=CreateFrame("Frame",nil,self);Mixin(p,VendorScoutPinMixin)
        p.Icon=p:CreateTexture();p.Ring=p:CreateTexture();p.owningMap=self
        -- Positioning/nudging is owned by MapCanvas, simulated here.
        p.SetPosition=function(s,x,y)s.x=x;s.y=y end
        p:OnLoad();assert(levels[p.pinFrameLevelType],"Pin level must be registered")
        p:OnAcquired(...);self.pins[#self.pins+1]=p;return p
    end
end
local strataRank={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,FULLSCREEN=6,FULLSCREEN_DIALOG=7,TOOLTIP=8}
function pointerTarget(x,y)
    local best,rank,level=nil,0,0
    for _,f in ipairs(frames)do
        if f.mouse and f:IsShown() then
            local fx,fy,fw,fh=f:GetBounds();local r,l=strataRank[f:GetFrameStrata()],f:GetFrameLevel()
            if x>=fx and x<fx+fw and y>=fy and y<fy+fh and (r>rank or (r==rank and l>=level))then best,rank,level=f,r,l end
        end
    end
    return best
end
function pointerClick(frame)
    local x,y,w,h=frame:GetBounds();local target=pointerTarget(x+w/2,y+h/2)
    assert(target==frame,"Pointer intercepted by another frame")
    if target.scripts.OnMouseDown then target.scripts.OnMouseDown(target,"LeftButton")end
    target:Click();return target
end
function fire(event,...)
    local copy={unpack(frames)}
    for _,f in ipairs(copy) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
end
