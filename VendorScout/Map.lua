local _, V = ...
VendorScoutPinMixin = {}
local Pin={}
function Pin:OnLoad()
    self:SetScalingLimits(1,1,1); self:UseFrameLevelType("PIN_FRAME_LEVEL_VENDORSCOUT")
    self.VendorSymbol=V:CreateVendorSymbol(self,16)
end
function Pin:OnAcquired(result,loc,x,y,selected)
    self.result,self.location,self.selected=result,loc,selected
    self:SetPosition(x,y); self:SetSize(selected and 24 or 20,selected and 24 or 20)
    self.VendorSymbol:SetScale((selected and 20 or 16)/32)
    self.Ring:SetShown(selected)
    self:SetScript("OnUpdate",selected and function(s)
        s.Ring:SetAlpha(.35+.30*(.5+.5*math.sin(GetTime()*3)))
    end or nil)
end
function Pin:OnReleased()
    self:SetScript("OnUpdate",nil); self.result=nil; self.location=nil
    MapCanvasPinMixin.OnReleased(self)
end
function Pin:OnMouseEnter()
    if not self.result then return end
    V:ResultTooltip(self)
    if self.location and self.location.x then
        GameTooltip:AddLine(string.format("%.1f, %.1f",self.location.x*100,self.location.y*100),.38,.85,.69)
        GameTooltip:Show()
    end
end
function Pin:OnMouseLeave() GameTooltip:Hide() end
function Pin:OnClick(button)
    if button=="LeftButton" and self.result then V:GetMapSearch():Select(self.result,self.location) end
end

function V:AttachMap()
    if self.mapAttached then return true end
    if not WorldMapFrame or not WorldMapFrame.AddDataProvider or not MapCanvasPinMixin or not MapCanvasDataProviderMixin then return false end
    Mixin(VendorScoutPinMixin,MapCanvasPinMixin,Pin)
    WorldMapFrame:GetPinFrameLevelsManager():AddFrameLevel("PIN_FRAME_LEVEL_VENDORSCOUT")
    self.mapAttached=true
    local provider=CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:RemoveAllData() self:GetMap():RemoveAllPinsByTemplate("VendorScoutPinTemplate") end
    function provider:RefreshAllData() V:RefreshPins() end
    function provider:OnMapChanged()
        local state=V:GetMapSearch();state.mapPage=1;state:RefreshSearch()
    end
    self.provider=provider
    WorldMapFrame:AddDataProvider(provider)
    self:BuildMapUI()
    WorldMapFrame:HookScript("OnShow",function()
        self:UpdateMapInputLayer()
        self.mapPanel:Show()
        if self.db then self:GetMapSearch():RefreshSearch() end
    end)
    WorldMapFrame:HookScript("OnHide",function() self.mapPanel:Hide() end)
    WorldMapFrame:HookScript("OnSizeChanged",function() if self.mapPanel:IsShown() then self:PositionMapSearch() end end)
    if WorldMapFrame:IsShown() then self.mapPanel:Show(); self:GetMapSearch():RefreshSearch() end
    return true
end
function V:UpdateMapInputLayer()
    if not self.mapPanel then return end
    local layers={"BACKGROUND","LOW","MEDIUM","HIGH","DIALOG","FULLSCREEN","FULLSCREEN_DIALOG","TOOLTIP"}
    local rank=5
    local map=WorldMapFrame
    for i,name in ipairs(layers) do
        if map:GetFrameStrata()==name or (map.BorderFrame and map.BorderFrame:GetFrameStrata()==name) then rank=math.max(rank,math.min(#layers,i+1)) end
    end
    self.mapPanel:SetFrameStrata(layers[rank]); self.mapButton:SetFrameStrata(layers[rank])
end
function V:EnsureMap()
    if InCombatLockdown and InCombatLockdown() then self:Message("Map unavailable in combat. Try again after combat."); return false end
    if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_WorldMap") end
    if not self:AttachMap() then self:Message("Map integration is unavailable in this client."); return false end
    return true
end
function V:OpenMapSearch()
    if not self:EnsureMap() then return end
    ShowUIPanel(WorldMapFrame); self.mapPanel:Show(); self:GetMapSearch():RefreshSearch(); self.mapPanel.search:SetFocus()
    if self.window then self.window:Hide() end
end
function V:ShowOnMap()
    local r=self.selected; local loc=self.targetLocation or (r and r.location)
    if not r or not loc or not loc.map or not loc.x then self:Message("This vendor has no known map coordinates."); return false end
    if not self:EnsureMap() then return false end
    return self:NavigateMapTarget(loc)
end
function V:NavigateMapTarget(loc)
    if not loc or not loc.map or not loc.x then self:Message("This vendor has no known map coordinates."); return false end
    if not self:EnsureMap() then return false end
    if OpenWorldMap then OpenWorldMap(loc.map) else ShowUIPanel(WorldMapFrame); WorldMapFrame:SetMapID(loc.map) end
    self.mapPanel:Show(); self:RefreshPins()
    if self.window then self.window:Hide() end
    return true
end
function V:RefreshPins()
    if not self.mapAttached or not self.db then return end
    local map=WorldMapFrame; map:RemoveAllPinsByTemplate("VendorScoutPinTemplate")
    if not map:IsShown() then return end
    if self.pinsSuppressed then self.pinCount=0;self.pinTotal=0;self:RefreshMapUI();return end
    local state=self:GetMapSearch()
    local mapID=map:GetMapID(); local seen={}; local count,total=0,0
    local function add(r,loc,selected)
        if not loc then return end
        local x,y=self:Project(loc,mapID); if not x then return end
        local key=r.id..":"..string.format("%.5f:%.5f",x,y)
        if seen[key] then return end; seen[key]=true; total=total+1
        if count>=150 then return end
        map:AcquirePin("VendorScoutPinTemplate",r,loc,x,y,selected); count=count+1
    end
    if state.selected then add(state.selected,state.targetLocation or state.selected.location,true) end
    if self.mapPanel and self.mapPanel:IsShown() then
        for _,r in ipairs(state.results) do
            for _,loc in ipairs(r.vendor.locations) do add(r,loc,false) end
        end
    end
    self.pinCount,self.pinTotal=count,total; self:RefreshMapUI()
end
-- Independent UIParent window: never resize or reanchor the map/canvas.
function V:PositionMapSearch()
    local p=self.mapPanel; if not p or p.dragging then return end
    local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
    local w,h=p:GetWidth(),p:GetHeight()
    local pos=self.db.ui.mapPosition
    local x,y
    if pos and self:Number(pos.x) and self:Number(pos.y) then x,y=pos.x,pos.y
    else
        local map=WorldMapFrame; local scale=map:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local left,right=(map:GetLeft() or 0)*scale,(map:GetRight() or map:GetWidth())*scale
        local top,bottom=sh-(map:GetTop() or sh)*scale,sh-(map:GetBottom() or 0)*scale
        x,y=right+12,top
        if x+w>sw-8 then
            if left-w-12>=8 then x=left-w-12
            elseif bottom+12+h<=sh-8 then x,y=left,bottom+12
            elseif top-h-12>=8 then x,y=left,top-h-12
            else x=sw-w-8 end -- Fullscreen: keep the movable window reachable.
        end
    end
    x=math.max(8,math.min(x,sw-w-8));y=math.max(8,math.min(y,sh-h-8))
    p:ClearAllPoints();p:SetPoint("TOPLEFT",UIParent,"TOPLEFT",x,-y)
end
function V:SaveMapSearchPosition()
    local p=self.mapPanel
    p:StopMovingOrSizing();p.dragging=nil
    local scale=p:GetEffectiveScale()/UIParent:GetEffectiveScale()
    self.db.ui.mapPosition={x=p:GetLeft()*scale,y=UIParent:GetHeight()-p:GetTop()*scale}
    self:PositionMapSearch()
end
function V:BuildMapUI()
    if self.mapPanel then return end
    local map=WorldMapFrame
    local state=self:GetMapSearch()
    self.mapButton=self:Button(map,"",0,0,30,function()
        if not self.mapPanel:IsShown() and not self:EnsureMap() then return end
        self.mapPanel:SetShown(not self.mapPanel:IsShown()); state:RefreshSearch()
    end)
    -- WorldMapFrame is MEDIUM, but its mouse-enabled BorderFrame is HIGH.
    -- A high frame LEVEL cannot outrank a higher frame STRATUM.
    self.mapButton:SetFrameStrata("DIALOG"); self.mapButton:SetFrameLevel(100)
    self.mapButton:SetSize(30,32);self.mapButton:SetClampedToScreen(true)
    self.mapButton:ClearAllPoints();self.mapButton:SetPoint("TOPRIGHT",map.ScrollContainer or map,"TOPRIGHT",-6,-6)
    self.mapButton.symbol=self:CreateVendorSymbol(self.mapButton,18)
    self.mapButton:HookScript("OnEnter",function(s)
        GameTooltip:SetOwner(s,"ANCHOR_LEFT");GameTooltip:SetText("VendorScout",.38,.85,.69)
        GameTooltip:AddLine(self:L(self.mapPanel:IsShown() and "Hide map search" or "Show map search"),1,1,1)
        GameTooltip:Show()
    end)
    self.mapButton:HookScript("OnLeave",function() GameTooltip:Hide() end)
    local p=self:Panel(UIParent,292,506,"VendorScoutMapSearch"); self.mapPanel=p
    p:SetFrameStrata("DIALOG"); p:SetFrameLevel(100); p:EnableMouse(true)
    p:SetMovable(true);p:SetClampedToScreen(true)
    p.dragHandle=CreateFrame("Frame",nil,p)
    p.dragHandle:SetPoint("TOPLEFT",p,"TOPLEFT",4,-4);p.dragHandle:SetSize(246,32)
    p.dragHandle:EnableMouse(true);p.dragHandle:RegisterForDrag("LeftButton")
    p.dragHandle:SetScript("OnDragStart",function() p.search:ClearFocus();p.dragging=true;p:StartMoving() end)
    p.dragHandle:SetScript("OnDragStop",function() self:SaveMapSearchPosition() end)
    table.insert(UISpecialFrames,"VendorScoutMapSearch")
    p.title=self:Label(p,self:L("Map search"),12,-12,220,20,"GameFontNormal"); p.title:SetTextColor(.38,.85,.69)
    p.dragHandle:SetScript("OnEnter",function(s) GameTooltip:SetOwner(s,"ANCHOR_TOP");GameTooltip:SetText(self:L("Drag to move"));GameTooltip:Show() end)
    p.dragHandle:SetScript("OnLeave",function() GameTooltip:Hide() end)
    p.close=self:Button(p,"×",256,-8,24,function() p:Hide() end)
    p.search=self:SearchBox(p,12,-40,232,state)
    p.clearQuery=self:Button(p,"×",250,-42,28,function() state.pendingText=nil; state:SetQuery(""); p.search:SetFocus() end)
    p.scope=self:Button(p,"",12,-78,128,function() state.mapOnly=not state.mapOnly; state.mapPage=1; state:RefreshSearch() end)
    p.faction=self:Button(p,"",146,-78,132,function() self.db.friendlyOnly=not self.db.friendlyOnly; self.page=1;state.mapPage=1; self:RefreshSearch() end)
    p.category=self:FilterButton(p,"category",12,-110,266)
    p.profession=self:FilterButton(p,"profession",12,-142,266)
    p.resetFilters=self:Button(p,"",12,-174,266,function() self:ResetFilters() end)
    p.status=self:Label(p,"",12,-206,268,18)
    p.target=self:Label(p,"",12,-226,268,18);p.target:SetWordWrap(false);p.target:SetTextColor(.38,.85,.69)
    p.rows={}
    for i=1,4 do
        local row=self:ResultRow(p,12,-248-(i-1)*46,266,true)
        row:SetScript("OnClick",function(s) if s.result then state:Select(s.result); self:NavigateMapTarget(state.targetLocation) end end)
        row:SetScript("OnDoubleClick",nil)
        p.rows[i]=row
    end
    p.empty=self:Label(p,"",18,-284,254,100)
    p.prev=self:Button(p,"<",12,-436,30,function() state.mapPage=math.max(1,state.mapPage-1); self:RefreshMapUI() end)
    p.pageLabel=self:Label(p,"",52,-442,180,18)
    p.next=self:Button(p,">",248,-436,30,function() state.mapPage=math.min(math.max(1,math.ceil(#state.results/4)),state.mapPage+1); self:RefreshMapUI() end)
    p.open=self:Button(p,"",12,-470,90,function()
        self:BuildUI(); HideUIPanel(WorldMapFrame); self.window:Show(); self:RefreshSearch()
    end)
    p.items=self:Button(p,"",108,-470,80,function() self:ToggleMapItems() end)
    p.clear=self:Button(p,"",194,-470,84,function() state:ClearSelection() end)
    p:Hide()
    p:SetScript("OnShow",function() self:PositionMapSearch();self:UpdateMapInputLayer() end)
    p:SetScript("OnHide",function()
        if p.dragging then self:SaveMapSearchPosition() end
        p.search:ClearFocus(); self:CloseFilterMenus();self:RefreshPins()
    end)
    self:UpdateMapInputLayer()
end
function V:RefreshMapUI()
    local p=self.mapPanel; if not p then return end
    local state=self:GetMapSearch()
    p.title:SetText(self:L("Map search"))
    self.mapButton:SetSelected(p:IsShown())
    if p.search:GetText()~=state.query and (not p.search:HasFocus() or not state.pendingText) then p.search:SetText(state.query) end
    p.scope:SetText(self:L(state.mapOnly and "This map" or "Everywhere")); p.scope:SetSelected(state.mapOnly)
    self:RefreshFilterButton(p.category);self:RefreshFilterButton(p.profession)
    p.resetFilters:SetText(self:L("Reset filters"));p.resetFilters:SetEnabled(self.category~="all" or self.profession~="all")
    p.faction:SetText(self:L(state.db.friendlyOnly and "My faction" or "All factions")); p.faction:SetSelected(state.db.friendlyOnly)
    local results=state.results; local total=#results
    state.mapPage=math.min(state.mapPage,math.max(1,math.ceil(total/4)))
    self:FillRows(p.rows,results,state.mapPage,state)
    p.target:SetText(state.selected and self:L("Marked")..": "..self:VendorName(state.selected.id) or self:L("No vendor selected"))
    p.status:SetText(total.." "..self:L("vendors").."  ·  "..(self.pinCount or 0)..((self.pinTotal or 0)>150 and "/"..self.pinTotal or "").." "..self:L("pins"))
    p.empty:SetShown(total==0); p.empty:SetText(self:L("No vendors found").."\n\n"..self:L("Try another keyword, reset filters or show all factions."))
    p.pageLabel:SetText(state.mapPage.." / "..math.max(1,math.ceil(total/4)))
    p.prev:SetEnabled(state.mapPage>1); p.next:SetEnabled(state.mapPage<math.ceil(total/4))
    p.open:SetText(self:L("Open window")); p.clear:SetText(self:L("Clear pin"))
    p.clear:SetEnabled(state.selected~=nil)
    p.items:SetText(self:L("Items"));p.items:SetEnabled(state.selected~=nil);self:RefreshMapItems()
end
