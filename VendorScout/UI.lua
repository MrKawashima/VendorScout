local _, V = ...
local BG={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}}
local NO={
    ["Find what you need. See who sells it."]="Finn det du trenger. Se hvem som selger det.",
    ["Search item, vendor, item ID or paste an item link"]="Søk vare, vendor, item-ID eller lim inn en item-lenke",
    ["All"]="Alle",["Consumables"]="Forbruksvarer",["Supplies"]="Forsyninger",["Recipes"]="Oppskrifter",["Gear"]="Utstyr",
    ["My faction"]="Min fraksjon",["All factions"]="Alle fraksjoner",["Show on map"]="Vis i kartet",["Vendors"]="Vendors",
    ["This map"]="Dette kartet",["Everywhere"]="Overalt",["Open window"]="Åpne vindu",["Clear pin"]="Fjern markør",
    ["Choose a vendor"]="Velg en vendor",["Select a result to see matching items and its map location."]="Velg et treff for å se varer og plasseringen i kartet.",
    ["No vendors found"]="Ingen vendors funnet",["Try a shorter name, another category or all factions."]="Prøv et kortere navn, en annen kategori eller alle fraksjoner.",
    ["Location unknown"]="Ukjent plassering",["Distance unknown"]="Ukjent avstand",["Other world / distance unknown"]="Annet område / ukjent avstand",
    ["Straight-line distance; travel routes and access may differ."]="Luftlinje; reisevei og tilgang kan avvike.",
    ["Database stock; availability may change."]="Databaseutvalg; tilgjengelighet kan endres.",
    ["Limited stock"]="Begrenset lager",["Stock unknown"]="Lager ukjent",["Requires level"]="Krever nivå",
    ["Access unverified"]="Tilgang ikke bekreftet",["Alliance"]="Alliance",["Horde"]="Horde",["Both factions"]="Begge fraksjoner",
    ["Known spawn; vendor may move."]="Kjent plassering; vendoren kan flytte seg.",
    ["Observed nearby"]="Observert i nærheten",["Map unavailable in combat. Try again after combat."]="Kartet er utilgjengelig i kamp. Prøv igjen etter kampen.",
    ["This vendor has no known map coordinates."]="Denne vendoren har ingen kjente kartkoordinater.",
    ["Map integration is unavailable in this client."]="Kartintegrasjonen er utilgjengelig i denne klienten.",
    ["Last seen"]="Sist sett",["Matching items"]="Matchende varer",["Click to select; double-click to open map."]="Klikk for å velge; dobbeltklikk for å åpne kartet.",
    ["Left-click: search. Right-click: map search. Drag: move."]="Venstreklikk: søk. Høyreklikk: kartsøk. Dra: flytt.",
    ["Search vendors"]="Søk vendors",["Open world map"]="Åpne verdenskart",["No coordinates"]="Ingen koordinater",
    ["Known locations"]="Kjente plasseringer",["Community snapshot"]="Fellesskapsdatabase",
    ["New Forever content may be missing."]="Nytt Forever-innhold kan mangle.",
    ["Requires reputation"]="Krever omdømme",["Requires PvP rank"]="Krever PvP-rang",
    ["Nearby vendors"]="Vendors i nærheten",["pins"]="markører",["vendors"]="vendors",["items"]="varer",
    ["Category"]="Kategori",["Show map search"]="Vis kartsøk",["Hide map search"]="Skjul kartsøk",
    ["Drag to move"]="Dra for å flytte",["Map search"]="Kartsøk",["Clear selection"]="Fjern valg",["Marked"]="Markert",
    ["No vendor selected"]="Ingen vendor valgt",
    ["Nearest match selected. Choose another result or use Show on map."]="Nærmeste treff er valgt. Velg et annet treff eller trykk Vis i kartet.",
}
function V:L(s) return self.db and self.db.language=="no" and (NO[s] or s) or s end
function V:Message(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff61d9b0VendorScout:|r "..self:L(text)) end
end
function V:Panel(parent,w,h,name)
    local f=CreateFrame("Frame",name,parent,"BackdropTemplate")
    f:SetSize(w,h); f:SetBackdrop(BG); f:SetBackdropColor(.035,.055,.07,.98); f:SetBackdropBorderColor(.23,.36,.39,1)
    return f
end
-- Original coin icon, shared by the compact map toggle and vendor pins.
function V:CreateVendorSymbol(parent,size)
    local f=CreateFrame("Frame",nil,parent);f:SetSize(32,32);f:SetPoint("CENTER");f:SetScale(size/32)
    f:EnableMouse(false)
    f.icon=f:CreateTexture(nil,"ARTWORK")
    f.icon:SetAllPoints(f);f.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    return f
end
function V:Label(parent,text,x,y,w,h,font)
    local f=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
    f:SetPoint("TOPLEFT",x,y); f:SetSize(w,h or 18); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetText(text)
    return f
end
function V:Button(parent,text,x,y,w,action)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:EnableMouse(true); b:RegisterForClicks("LeftButtonUp")
    b:SetFrameLevel(parent:GetFrameLevel()+1)
    b:SetSize(w,26); b:SetPoint("TOPLEFT",x,y); b:SetBackdrop(BG)
    b.caption=self:Label(b,text,4,-6,w-8,16); b.caption:SetJustifyH("CENTER")
    function b:SetText(s) self.caption:SetText(s) end
    function b:Paint(hover)
        local on=self.selected or hover
        self:SetBackdropColor(on and .12 or .08,on and .23 or .13,on and .25 or .16,1)
        self:SetBackdropBorderColor(on and .38 or .23,on and .85 or .36,on and .69 or .39,1)
    end
    function b:SetSelected(on) self.selected=on; self:Paint(false) end
    b:SetScript("OnEnter",function(s) s:Paint(true) end); b:SetScript("OnLeave",function(s) s:Paint(false) end)
    b:SetScript("OnClick",action); b:Paint(false)
    return b
end
function V:SearchBox(parent,x,y,w,owner)
    owner=owner or self
    local box=CreateFrame("EditBox",nil,parent,"BackdropTemplate")
    box.searchOwner=owner
    box:EnableMouse(true); box:EnableKeyboard(true)
    box:SetFrameLevel(parent:GetFrameLevel()+2)
    box:SetSize(w,30); box:SetPoint("TOPLEFT",x,y); box:SetBackdrop(BG)
    box:SetBackdropColor(.015,.025,.035,1); box:SetBackdropBorderColor(.23,.36,.39,1)
    box:SetFontObject("GameFontHighlight"); box:SetTextInsets(10,10,0,0); box:SetAutoFocus(false); box:SetMaxLetters(240)
    box:SetScript("OnMouseDown",function(s) s:SetFocus() end)
    box:SetScript("OnTextChanged",function(s,user)
        if user then
            owner.pendingText=s:GetText(); owner.pendingAt=GetTime()+.18
        end
    end)
    box:SetScript("OnEnterPressed",function(s) owner.pendingText=nil; owner:SetQuery(s:GetText()); s:ClearFocus() end)
    box:SetScript("OnEscapePressed",function(s) s:ClearFocus() end)
    box:SetScript("OnEnter",function(s)
        GameTooltip:SetOwner(s,"ANCHOR_TOP"); GameTooltip:SetText(V:L("Search item, vendor, item ID or paste an item link")); GameTooltip:Show()
    end)
    box:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return box
end
function V:ZoneName(loc)
    if not loc then return self:L("Location unknown") end
    if loc.map and C_Map and C_Map.GetMapInfo then
        local ok,info=pcall(C_Map.GetMapInfo,loc.map)
        if ok and info and info.name then return info.name end
    end
    return self.Data.zones[loc.area] or self:L("Location unknown")
end
function V:Distance(result)
    if result.distance then
        return result.distance>=1000 and string.format("~%.1f k yd",result.distance/1000) or string.format("~%.0f yd",result.distance)
    end
    return self:L(result.location and result.location.x and "Distance unknown" or "No coordinates")
end
function V:LocationDistance(loc)
    local pc,px,py=self:World(self:PlayerLocation(),true)
    local c,x,y=self:World(loc)
    if pc and pc==c then return self:Distance({distance=math.sqrt((x-px)^2+(y-py)^2)}) end
    return self:Distance({location=loc})
end
function V:ResultTooltip(row)
    local r=row.result; if not r then return end
    GameTooltip:SetOwner(row,"ANCHOR_RIGHT"); GameTooltip:SetText(self:VendorName(r.id),.38,.85,.69)
    GameTooltip:AddLine(self:ZoneName(r.location).."  ·  "..self:Distance(r),1,1,1,true)
    for i=1,math.min(8,#r.offers) do GameTooltip:AddLine(self:ItemName(r.offers[i]),.85,.9,.92,true) end
    GameTooltip:AddLine(self:L("Click to select; double-click to open map."),.6,.7,.72,true); GameTooltip:Show()
end
function V:ResultRow(parent,x,y,w,compact)
    local b=self:Button(parent,"",x,y,w,function(s) if s.result then self:Select(s.result) end end)
    b.caption:Hide(); b:SetHeight(compact and 44 or 50)
    b.title=self:Label(b,"",10,-6,w-20,17,"GameFontHighlight")
    b.meta=self:Label(b,"",10,-25,w-20,17)
    b.title:SetWordWrap(false); b.meta:SetWordWrap(false)
    b:SetScript("OnDoubleClick",function(s) if s.result then self:Select(s.result); self:ShowOnMap() end end)
    b:SetScript("OnEnter",function(s) s:Paint(true); self:ResultTooltip(s) end)
    b:SetScript("OnLeave",function(s) s:Paint(false); GameTooltip:Hide() end)
    return b
end
function V:FillRows(rows,results,page,owner)
    owner=owner or self
    for i,row in ipairs(rows) do
        local r=results[(page-1)*#rows+i]; row.result=r; row:SetShown(r~=nil)
        if r then
            row.title:SetText(self:VendorName(r.id)); row.title:SetTextColor(.88,.96,.93)
            row.meta:SetText(self:ZoneName(r.location).."  ·  "..self:Distance(r).."  ·  "..#r.offers.." "..self:L("items"))
            row.meta:SetTextColor(.59,.7,.74)
            row:SetSelected(owner.selected and owner.selected.id==r.id)
        end
    end
end
function V:FitWindow()
    if not self.window then return end
    local scale=self:Number(self.db.ui.scale) and self.db.ui.scale or .9
    scale=math.max(.65,math.min(1.3,scale))
    self.window:SetScale(math.min(scale,(UIParent:GetWidth()-24)/820,(UIParent:GetHeight()-24)/620))
end
function V:BuildUI()
    if self.window then return end
    local w=self:Panel(UIParent,820,620,"VendorScoutWindow"); self.window=w
    w:SetPoint("CENTER"); w:SetFrameStrata("DIALOG"); w:EnableMouse(true); w:SetMovable(true); w:SetClampedToScreen(true)
    w:RegisterForDrag("LeftButton"); w:SetScript("OnDragStart",w.StartMoving)
    w:SetScript("OnDragStop",function(s)
        s:StopMovingOrSizing(); local point,_,relative,x,y=s:GetPoint()
        self.db.ui.position={point,relative,x,y}
    end)
    local pos=self.db.ui.position
    local anchors={CENTER=true,TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
    if type(pos)=="table" and anchors[pos[1]] and anchors[pos[2]] and self:Number(pos[3]) and self:Number(pos[4]) then
        w:ClearAllPoints(); w:SetPoint(pos[1],UIParent,pos[2],pos[3],pos[4])
    end
    self:FitWindow(); w:Hide(); table.insert(UISpecialFrames,"VendorScoutWindow")
    w:SetScript("OnHide",function() w.search:ClearFocus() end)
    w.title=self:Label(w,"VendorScout",18,-18,500,26,"GameFontNormalLarge"); w.title:SetTextColor(.38,.85,.69)
    w.subtitle=self:Label(w,"",18,-48,770,20)
    self:Button(w,"−",662,-16,28,function() self.db.ui.scale=math.max(.65,(self.db.ui.scale or .9)-.05); self:FitWindow() end)
    self:Button(w,"+",694,-16,28,function() self.db.ui.scale=math.min(1.3,(self.db.ui.scale or .9)+.05); self:FitWindow() end)
    self:Button(w,"EN/NO",726,-16,53,function() self.db.language=self.db.language=="no" and "en" or "no"; self:RefreshUI() end)
    self:Button(w,"×",782,-16,24,function() w:Hide() end)
    w.search=self:SearchBox(w,18,-78,692)
    w.clear=self:Button(w,"×",716,-80,30,function() self.pendingText=nil; self:SetQuery(""); w.search:SetFocus() end)
    w.map=self:Button(w,"M",752,-80,48,function() self:OpenMapSearch() end)
    w.map:SetScript("OnEnter",function(s) GameTooltip:SetOwner(s,"ANCHOR_RIGHT"); GameTooltip:SetText(self:L("Open world map")); GameTooltip:Show() end)
    w.map:SetScript("OnLeave",function() GameTooltip:Hide() end)
    w.categories={}
    local cats={{"all","All"},{"food","Consumables"},{"supplies","Supplies"},{"recipes","Recipes"},{"gear","Gear"}}
    for i,c in ipairs(cats) do
        local id,caption=c[1],c[2]
        local b=self:Button(w,caption,18+(i-1)*116,-118,110,function() self.category=id; self.page=1; self.mapPage=1; self:RefreshSearch() end)
        b.category,b.key=id,caption; w.categories[i]=b
    end
    w.faction=self:Button(w,"",610,-118,190,function() self.db.friendlyOnly=not self.db.friendlyOnly; self.page=1; self.mapPage=1; self:RefreshSearch() end)
    w.status=self:Label(w,"",18,-157,760,20)
    w.rows={}; for i=1,7 do w.rows[i]=self:ResultRow(w,18,-184-(i-1)*52,428) end
    w.empty=self:Label(w,"",32,-220,400,80,"GameFontHighlight")
    w.prev=self:Button(w,"<",18,-554,38,function() self.page=math.max(1,self.page-1); self:RefreshUI() end)
    w.pageLabel=self:Label(w,"",66,-560,230,20)
    w.next=self:Button(w,">",408,-554,38,function() self.page=math.min(math.max(1,math.ceil(#self.results/7)),self.page+1); self:RefreshUI() end)
    local d=self:Panel(w,338,396); d:SetPoint("TOPLEFT",462,-184); w.detail=d
    d.title=self:Label(d,"",14,-12,310,42,"GameFontNormalLarge"); d.title:SetTextColor(.38,.85,.69)
    d.meta=self:Label(d,"",14,-60,310,64)
    d.map=self:Button(d,"",14,-130,196,function() self:ShowOnMap() end)
    d.clear=self:Button(d,"",216,-130,108,function() self:ClearSelection() end)
    d.header=self:Label(d,"",14,-169,310,18)
    d.offers={}
    for i=1,5 do
        local b=CreateFrame("Button",nil,d); b:SetSize(308,30); b:SetPoint("TOPLEFT",14,-192-(i-1)*31)
        b.text=self:Label(b,"",0,0,308,30)
        b.text:SetWordWrap(false)
        b:SetScript("OnEnter",function(s)
            if s.itemID then
                GameTooltip:SetOwner(s,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:"..s.itemID)
                GameTooltip:AddLine(self:ItemName(s.itemID),.38,.85,.69,true)
                if s.notes then GameTooltip:AddLine(s.notes,.65,.75,.8,true) end
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        b:SetScript("OnClick",function(s)
            if s.itemID and IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then
                local _,link=C_Item.GetItemInfo(s.itemID); if link then ChatEdit_InsertLink(link) end
            end
        end)
        d.offers[i]=b
    end
    d.prev=self:Button(d,"<",14,-358,30,function() self.offerPage=math.max(1,(self.offerPage or 1)-1); self:RefreshDetail() end)
    d.pageLabel=self:Label(d,"",54,-364,220,18)
    d.next=self:Button(d,">",294,-358,30,function()
        if self.selected then self.offerPage=math.min(math.ceil(#self.selected.offers/5),(self.offerPage or 1)+1); self:RefreshDetail() end
    end)
    w.footer=self:Label(w,"",18,-594,780,18)
end
function V:RefreshDetail()
    if not self.window then return end
    local d=self.window.detail; local r=self.selected
    d.map:SetText(self:L("Show on map")); d.clear:SetText(self:L("Clear pin"))
    local target=self.targetLocation or (r and r.location)
    d.map:SetEnabled(r and target and target.map~=nil and target.x~=nil or false)
    d.clear:SetEnabled(r~=nil)
    for _,b in ipairs(d.offers) do b:Hide() end
    d.prev:Hide(); d.next:Hide(); d.pageLabel:SetText("")
    if not r then
        d.title:SetText(self:L("Choose a vendor")); d.meta:SetText(self:L("Select a result to see matching items and its map location."))
        d.header:SetText(""); return
    end
    local loc=self.targetLocation or r.location
    local coord=loc and loc.x and string.format("  %.1f, %.1f",loc.x*100,loc.y*100) or ""
    local side=({A="Alliance",H="Horde",AH="Both factions"})[r.vendor.reaction] or "Access unverified"
    d.title:SetText(self:VendorName(r.id))
    local note=loc and loc.x and (loc.observed and "Observed nearby" or "Known spawn; vendor may move.") or "No coordinates"
    d.meta:SetText(self:ZoneName(loc)..coord.."\n"..self:LocationDistance(loc).."  ·  "..self:L(side).."\n"..self:L(note))
    local count=#r.offers; local page=math.min(self.offerPage or 1,math.max(1,math.ceil(count/5))); self.offerPage=page
    d.header:SetText(self:L("Matching items").." ("..count..")")
    for i,b in ipairs(d.offers) do
        local id=r.offers[(page-1)*5+i]; b.itemID=id; b:SetShown(id~=nil)
        if id then
            local it=self.items[id]; local stock=r.vendor.offers[id]; local extra={}
            if stock and stock>0 then extra[#extra+1]=self:L("Limited stock")..": "..stock end
            if it.requiredLevel and it.requiredLevel>1 then extra[#extra+1]=self:L("Requires level").." "..it.requiredLevel end
            if it.repFaction then extra[#extra+1]=self:L("Requires reputation").." #"..it.repFaction.." / "..(it.repStanding or "?") end
            if it.pvpRank then extra[#extra+1]=self:L("Requires PvP rank").." "..it.pvpRank end
            local obs=self.db.observed[r.id]; obs=obs and obs.offers and obs.offers[id]
            if type(obs)=="table" and self:Number(obs.time) then
                extra[#extra+1]=self:L("Last seen").." "..date("%d.%m %H:%M",obs.time).." ("..(obs.stock==-1 and "∞" or tostring(obs.stock or "?"))..")"
            end
            if #extra==0 then extra[1]=self:L("Stock unknown") end
            b.notes=table.concat(extra," · ")
            b.text:SetText(self:ItemName(id).."\n|cff94adb8"..b.notes.."|r")
        end
    end
    d.prev:Show(); d.next:Show(); d.prev:SetEnabled(page>1); d.next:SetEnabled(page<math.ceil(count/5))
    d.pageLabel:SetText(page.." / "..math.max(1,math.ceil(count/5)))
end
function V:RefreshUI()
    local w=self.window
    if w then
        w.subtitle:SetText(self:L(self.selected and self.selectionMode=="auto" and "Nearest match selected. Choose another result or use Show on map." or "Find what you need. See who sells it."))
        if w.search:GetText()~=self.query and (not w.search:HasFocus() or not self.pendingText) then w.search:SetText(self.query) end
        for _,b in ipairs(w.categories) do b:SetText(self:L(b.key)); b:SetSelected(b.category==self.category) end
        w.faction:SetText(self:L(self.db.friendlyOnly and "My faction" or "All factions")); w.faction:SetSelected(self.db.friendlyOnly)
        local total=#self.results; self.page=math.min(self.page,math.max(1,math.ceil(total/7)))
        w.status:SetText((self.query=="" and self:L("Nearby vendors").."  ·  " or "")..total.." "..self:L("vendors").."  ·  "..self:L("Straight-line distance; travel routes and access may differ."))
        self:FillRows(w.rows,self.results,self.page); w.empty:SetShown(total==0)
        w.empty:SetText(self:L("No vendors found").."\n\n"..self:L("Try a shorter name, another category or all factions."))
        w.pageLabel:SetText(self.page.." / "..math.max(1,math.ceil(total/7)))
        w.prev:SetEnabled(self.page>1); w.next:SetEnabled(self.page<math.ceil(total/7))
        w.footer:SetText(self:L("Community snapshot").." "..self.Data.meta.generated.."  ·  "..self:L("New Forever content may be missing."))
        self:RefreshDetail()
    end
    if self.RefreshMapUI then self:RefreshMapUI() end
end
function V:Toggle()
    self:BuildUI()
    local opening=not self.window:IsShown()
    if opening and WorldMapFrame and WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame) end
    self.window:SetShown(opening)
    if self.window:IsShown() then self:RefreshSearch(); self.window.search:SetFocus() end
end
function V:BuildMinimap()
    if not Minimap or self.minimap then return end
    local b=CreateFrame("Button","VendorScoutMinimapButton",Minimap); self.minimap=b
    b:SetSize(30,30); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(10)
    local icon=b:CreateTexture(nil,"ARTWORK"); icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01"); icon:SetSize(20,20); icon:SetPoint("CENTER")
    local mask=b:CreateMaskTexture(); mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE"); mask:SetAllPoints(icon); icon:AddMaskTexture(mask)
    local rim=b:CreateTexture(nil,"OVERLAY"); rim:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); rim:SetSize(54,54); rim:SetPoint("TOPLEFT",0,0)
    local function position()
        local a=math.rad(tonumber(self.db.ui.angle) or 220); local x,y=math.cos(a),math.sin(a)
        if GetMinimapShape and GetMinimapShape()=="SQUARE" then local m=math.max(math.abs(x),math.abs(y)); x,y=x/m,y/m end
        b:ClearAllPoints(); b:SetPoint("CENTER",Minimap,"CENTER",x*(Minimap:GetWidth()/2+8),y*(Minimap:GetHeight()/2+8))
    end
    b:RegisterForClicks("LeftButtonUp","RightButtonUp"); b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick",function(_,button) if b.dragged then b.dragged=nil; return end; if button=="RightButton" then self:OpenMapSearch() else self:Toggle() end end)
    b:SetScript("OnDragStart",function()
        b.dragged=true; b:SetScript("OnUpdate",function()
            local mx,my=Minimap:GetCenter(); local x,y=GetCursorPosition(); local scale=Minimap:GetEffectiveScale()
            self.db.ui.angle=math.deg(math.atan2(y/scale-my,x/scale-mx)); position()
        end)
    end)
    b:SetScript("OnDragStop",function() b:SetScript("OnUpdate",nil) end)
    b:SetScript("OnEnter",function(s) GameTooltip:SetOwner(s,"ANCHOR_LEFT"); GameTooltip:SetText("VendorScout"); GameTooltip:AddLine(self:L("Left-click: search. Right-click: map search. Drag: move."),1,1,1,true); GameTooltip:Show() end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    b:SetShown(not self.db.ui.hideMinimap); position()
end
