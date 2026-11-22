local _, V = ...
V.version = "0.1.7-beta"
V.query, V.category, V.page, V.mapPage = "", "all", 1, 1
V.results, V.worldCache = {}, {}

local function readable(value)
    return not (issecretvalue and issecretvalue(value))
end
function V:Number(value)
    return readable(value) and type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end
function V:Normalize(value)
    value = tostring(value or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (string.lower(value):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end
function V:ItemName(id)
    return self.Locale.items[id] or (self.items[id] and self.items[id].name) or ("Item #"..id)
end
function V:VendorName(id)
    return self.Locale.vendors[id] or (self.vendors[id] and self.vendors[id].name) or ("Vendor #"..id)
end
function V:InitData(saved)
    -- A fresh session starts with an empty map. Only an explicit search or
    -- vendor selection enables pins; data refreshes preserve that choice.
    self.selectionMode=self.selectionMode or "none"
    if self.pinsSuppressed==nil then self.pinsSuppressed=true end
    self.db = type(saved)=="table" and saved or {}
    self.db.observed = type(self.db.observed)=="table" and self.db.observed or {}
    self.db.items = type(self.db.items)=="table" and self.db.items or {}
    self.db.ui = type(self.db.ui)=="table" and self.db.ui or {}
    if self.db.friendlyOnly==nil then self.db.friendlyOnly=true end
    self.items, self.vendors = self.Data.items, {}
    local horde=UnitFactionGroup and UnitFactionGroup("player")=="Horde"
    for id,v in pairs(self.Data.vendors) do
        local source=horde and self.Data.horde and self.Data.horde[id] or v
        local copy={};for key,value in pairs(source) do copy[key]=value end
        copy.offers={}; for iid,stock in pairs(source.offers) do copy.offers[iid]=stock end
        self.vendors[id]=copy
    end
    if horde then
        for id,v in pairs(self.Data.horde or {}) do if not self.vendors[id] then self.vendors[id]=v end end
    end
    for id,it in pairs(self.db.items) do
        if type(id)=="number" and type(it)=="table" and type(it.name)=="string" and not self.items[id] then self.items[id]=it end
    end
    for id,obs in pairs(self.db.observed) do
        if type(id)=="number" and type(obs)=="table" and type(obs.offers)=="table" then
            local vendor=self.vendors[id]
            if not vendor then
                vendor={name=obs.name or ("Vendor #"..id),reaction=obs.reaction,offers={},locations={}}
                self.vendors[id]=vendor
            end
            for iid,offer in pairs(obs.offers) do
                if self.items[iid] and type(offer)=="table" then vendor.offers[iid]=vendor.offers[iid] or 0 end
            end
            if type(obs.location)=="table" and self:Number(obs.location.map) and self:Number(obs.location.x) and self:Number(obs.location.y) and #vendor.locations==0 then vendor.locations={obs.location} end
        end
    end
    self:Reindex()
end
function V:Reindex()
    self.itemIndex, self.vendorIndex = {}, {}
    for id,it in pairs(self.items) do self.itemIndex[id]=self:Normalize(it.name).." "..self:Normalize(self:ItemName(id)) end
    for id,v in pairs(self.vendors) do self.vendorIndex[id]=self:Normalize(v.name).." "..self:Normalize(self:VendorName(id)).." "..self:Normalize(v.subName) end
end
function V:World(loc,noCache)
    if not loc or not self:Number(loc.map) or not self:Number(loc.x) or not self:Number(loc.y) or loc.x<0 or loc.x>1 or loc.y<0 or loc.y>1 then return end
    if not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return end
    local key=loc.map..":"..loc.x..":"..loc.y
    local cached=not noCache and self.worldCache[key]
    if cached then return cached[1],cached[2],cached[3] end
    local ok,continent,point=pcall(C_Map.GetWorldPosFromMapPos,loc.map,CreateVector2D(loc.x,loc.y))
    if ok and self:Number(continent) and point then
        local worked,x,y=pcall(point.GetXY,point)
        if worked and self:Number(x) and self:Number(y) then
            if not noCache then self.worldCache[key]={continent,x,y} end
            return continent,x,y
        end
    end
    -- Failed transforms are not cached: map data may not be ready yet.
end
function V:PlayerLocation()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return end
    local ok,map=pcall(C_Map.GetBestMapForUnit,"player")
    if not ok or not self:Number(map) then return end
    local worked,pos=pcall(C_Map.GetPlayerMapPosition,map,"player")
    if not worked or not pos then return end
    local valid,x,y=pcall(pos.GetXY,pos)
    if not valid or not self:Number(x) or not self:Number(y) or (x==0 and y==0) then return end
    return {map=map,x=x,y=y}
end
function V:Project(loc,map)
    if not loc or not loc.map or not loc.x or not map then return end
    if loc.map==map then return loc.x,loc.y end
    local continent,x,y=self:World(loc)
    if not continent or not C_Map.GetMapPosFromWorldPos then return end
    local ok,resultMap,pos=pcall(C_Map.GetMapPosFromWorldPos,continent,CreateVector2D(x,y),map)
    if ok and readable(resultMap) and resultMap==map and pos then
        local valid,px,py=pcall(pos.GetXY,pos)
        if valid and self:Number(px) and self:Number(py) and px>=0 and px<=1 and py>=0 and py<=1 then return px,py end
    end
end
function V:BestLocation(vendor,player,scopeMap,playerWorld)
    local pc,px,py
    if playerWorld then pc,px,py=unpack(playerWorld) else pc,px,py=self:World(player,true) end
    local best,dist,rank,hasScope=nil,nil,9,false
    for _,loc in ipairs(vendor.locations) do
        local inScope=not scopeMap or self:Project(loc,scopeMap)~=nil
        if inScope then
            hasScope=true
            local c,x,y=self:World(loc)
            local d
            if pc and c==pc then d=math.sqrt((x-px)^2+(y-py)^2) end
            local r=d and 0 or (loc.map and loc.x and 1 or 2)
            if r<rank or (r==rank and d and (not dist or d<dist)) then best,dist,rank=loc,d,r end
        end
    end
    return best,dist,rank,hasScope
end
function V:CategoryMatches(it)
    if self.category=="all" then return true end
    -- The snapshot omits zero-valued class IDs (Consumable = 0).
    if self.category=="food" then return (it.class or 0)==0 end
    if self.category=="recipes" then return it.class==9 end
    if self.category=="supplies" then return it.class==7 or it.class==5 or it.class==6 end
    if self.category=="gear" then return it.class==2 or it.class==4 end
    return false
end
local function matches(text,tokens)
    for _,token in ipairs(tokens) do if not string.find(text,token,1,true) then return false end end
    return true
end
function V:Search(scopeMap)
    local query=self:Normalize(self.query)
    local exact=tonumber(query:match("item:(%d+)")) or tonumber(query:match("^#?(%d+)$"))
    local tokens={}; for token in query:gmatch("%S+") do tokens[#tokens+1]=token end
    local faction=UnitFactionGroup and UnitFactionGroup("player")
    local side=faction=="Alliance" and "A" or (faction=="Horde" and "H" or nil)
    local player=self:PlayerLocation()
    local playerWorld={self:World(player,true)}
    local itemMatches={}
    for id,it in pairs(self.items) do
        if self:CategoryMatches(it) and (not self.db.friendlyOnly or not side or not it.side or it.side==side) then
            if (exact and id==exact) or (not exact and matches(self.itemIndex[id],tokens)) then itemMatches[id]=true end
        end
    end
    local results={}
    for id,vendor in pairs(self.vendors) do
        local accessible=not side or vendor.reaction=="AH" or vendor.reaction==side
        if not self.db.friendlyOnly or accessible then
            local vendorMatch=not exact and matches(self.vendorIndex[id],tokens)
            local offers={}
            for iid in pairs(vendor.offers) do
                local it=self.items[iid]
                if itemMatches[iid] or (vendorMatch and it and self:CategoryMatches(it) and (not self.db.friendlyOnly or not side or not it.side or it.side==side)) then offers[#offers+1]=iid end
            end
            if #offers>0 then
                local loc,distance,rank,hasScope=self:BestLocation(vendor,player,scopeMap,playerWorld)
                if not scopeMap or hasScope then
                    table.sort(offers,function(a,b)
                        if self:ItemName(a)==self:ItemName(b) then return a<b end
                        return self:ItemName(a)<self:ItemName(b)
                    end)
                    results[#results+1]={id=id,vendor=vendor,offers=offers,location=loc,distance=distance,rank=rank,accessible=accessible}
                end
            end
        end
    end
    table.sort(results,function(a,b)
        if a.rank~=b.rank then return a.rank<b.rank end
        if a.distance~=b.distance then return (a.distance or math.huge)<(b.distance or math.huge) end
        local an,bn=self:VendorName(a.id),self:VendorName(b.id)
        if an~=bn then return an<bn end
        return a.id<b.id
    end)
    return results
end
function V:RefreshSearch()
    local map=WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    self.results=self:Search(self.isMapSearch and self.mapOnly and map or nil)
    self.mapResults=self.results
    if self.selectionMode=="auto" then
        self.selected=self.results[1]; self.targetLocation=self.selected and self.selected.location
    elseif self.selected and self.selectionMode~="external" then
        local found
        for _,r in ipairs(self.results) do if r.id==self.selected.id then found=r; break end end
        self.selected=found
        if not found then self.targetLocation=nil end
    end
    if self.RefreshUI then self:RefreshUI() end
    if self.mapSearch then self.mapSearch:RefreshSearch()
    elseif self.RefreshPins then self:RefreshPins() end
end
function V:SetQuery(query)
    self.query=query or ""; self.page=1; self.mapPage=1; self.offerPage=1
    self.pendingText=nil
    if self.mapSearch then self.mapSearch.pendingText=nil;self.mapSearch.mapPage=1 end
    self.pinsSuppressed=self:Normalize(self.query)==""
    self.selected=nil; self.targetLocation=nil; self.selectionMode=self.pinsSuppressed and "none" or "auto"
    self:RefreshSearch()
end
function V:Select(result,location)
    self.selected=result; self.targetLocation=location or result.location; self.offerPage=1; self.selectionMode="manual";self.pinsSuppressed=false
    if self.RefreshUI then self:RefreshUI() end
    if self.RefreshPins then self:RefreshPins() end
end
function V:ClearSelection()
    self.selected=nil; self.targetLocation=nil; self.selectionMode="none";self.pinsSuppressed=true
    if self.RefreshUI then self:RefreshUI() end
    if self.RefreshPins then self:RefreshPins() end
end
function V:GetMapSearch()
    if self.mapSearch then return self.mapSearch end
    local root=self
    -- Each surface owns its controls and pagination. Commands operate on one
    -- shared query/filter/selection model, so Clear has the same effect anywhere.
    local shared={Data=true,Locale=true,items=true,vendors=true,itemIndex=true,vendorIndex=true,worldCache=true,
        query=true,category=true,selected=true,targetLocation=true,selectionMode=true,db=true}
    local state=setmetatable({isMapSearch=true,page=1,mapPage=1,results={},mapOnly=false},
        {__index=function(_,key) if shared[key] then return root[key] end end})
    state.SetQuery=function(_,query) root:SetQuery(query) end
    state.Select=function(_,result,location) root:Select(result,location) end
    state.ClearSelection=function() root:ClearSelection() end
    state.RefreshSearch=function(s)
        local map=WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
        s.results=root:Search(s.mapOnly and map or nil)
        root:RefreshMapUI();root:RefreshPins()
    end
    state.RefreshUI=function() root:RefreshMapUI() end
    state.RefreshPins=function() root:RefreshPins() end
    self.mapSearch=state
    return state
end
