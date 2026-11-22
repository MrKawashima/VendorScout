local addonName, V = ...
local events=CreateFrame("Frame")
local active=false
local function initialize()
    if active then return end; active=true
    V:InitData(VendorScoutDB); VendorScoutDB=V.db
    V:BuildUI(); V:BuildMinimap(); V:AttachMap(); V:RefreshSearch()
    if hooksecurefunc and ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink",function(link)
            local box=V.window and V.window.search:HasFocus() and V.window.search or (V.mapPanel and V.mapPanel.search:HasFocus() and V.mapPanel.search)
            if box and type(link)=="string" and link:find("item:",1,true) then
                local owner=box.searchOwner or V;owner.pendingText=nil;owner:SetQuery(link)
            end
        end)
    end
end
events:RegisterEvent("ADDON_LOADED"); events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("MERCHANT_SHOW"); events:RegisterEvent("MERCHANT_UPDATE")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA"); events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UI_SCALE_CHANGED"); events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" then
        if name==addonName and IsLoggedIn and IsLoggedIn() then initialize()
        elseif active and name=="Blizzard_WorldMap" then V:AttachMap() end
    elseif event=="PLAYER_LOGIN" then initialize()
    elseif active then
        if event=="MERCHANT_SHOW" or event=="MERCHANT_UPDATE" then V:ObserveMerchant()
        elseif event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" then V:FitWindow()
        else V.searchDirty=true end
    end
end)
local elapsed=0
local function submitPending(owner)
    if owner and owner.pendingText and GetTime()>=owner.pendingAt then
        local text=owner.pendingText;owner.pendingText=nil;owner:SetQuery(text)
    end
end
events:SetScript("OnUpdate",function(_,delta)
    if not active then return end
    submitPending(V);submitPending(V.mapSearch)
    elapsed=elapsed+delta
    if elapsed>=2 then
        elapsed=0
        if (V.window and V.window:IsShown()) or (V.mapPanel and V.mapPanel:IsShown() and WorldMapFrame:IsShown()) then
            V.searchDirty=false;V:RefreshSearch()
        end
    end
end)
SLASH_VENDORSCOUT1="/vs"; SLASH_VENDORSCOUT2="/vendorscout"
SlashCmdList.VENDORSCOUT=function(text)
    if not active then initialize() end
    local cmd=V:Normalize(text)
    if cmd=="map" then V:OpenMapSearch()
    elseif cmd=="clear" then V:GetMapSearch():ClearSelection()
    elseif cmd=="reset" then V.db.ui.mapPosition=nil; if V.mapPanel then V:PositionMapSearch() end; V.db.ui.position=nil; V.window:ClearAllPoints(); V.window:SetPoint("CENTER"); V.db.ui.scale=.9; V:FitWindow(); V.window:Show()
    elseif cmd=="minimap" then V.db.ui.hideMinimap=not V.db.ui.hideMinimap; if V.minimap then V.minimap:SetShown(not V.db.ui.hideMinimap) end
    elseif cmd=="debug" then
        local version,build,_,interface=GetBuildInfo()
        V:Message(V.version.." · client "..version.."/"..build.." ("..interface..") · data "..V.Data.meta.generated.." · "..V.Data.meta.vendors.." vendors · map "..tostring(V.mapAttached or false))
    elseif cmd=="help" then V:Message("/vs [item or vendor] · /vs map · /vs clear · /vs minimap · /vs reset · /vs debug")
    elseif cmd=="" then V:Toggle()
    else V.pendingText=nil; V:SetQuery(text); V.window:Show() end
end
